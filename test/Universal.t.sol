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
import "../src/Router.sol";
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
import "forge-std/StdAssertions.sol";

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

    Zap zap;

    Router router;

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
        // deploy Zap
        zap = new Zap();
        // now deploy router
        router = new Router(address(curveFactory));
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
        cheats.stopPrank();
        // account 1 is an attacker

        // Loop 10 000  gas = 695594585   so if gas price is 231 wei =  0.000000231651787155 => Gas =  161 matic
        uint256 e_u_bal_0 = euroc.balanceOf(address(accounts[1]));
        uint256 u_u_bal_0 = usdc.balanceOf(address(accounts[1]));
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
        uint256 crvEurocBal_2 = euroc.balanceOf(address(eurocUsdcCurve));
        uint256 crvUsdcBal_2 = usdc.balanceOf(address(eurocUsdcCurve));
        eurocUsdcCurve.withdraw(
            eurocUsdcCurve.balanceOf(address(accounts[1])),
            block.timestamp + 60
        );
        cheats.stopPrank();
        uint256 e_u_bal_1 = euroc.balanceOf(address(accounts[1]));
        uint256 u_u_bal_1 = usdc.balanceOf(address(accounts[1]));
        // we cut 0.1 lpt per deposit, since looped 10000 times, token diff should be no less than 1000
        assertApproxEqAbs(e_u_bal_0, e_u_bal_1, 1000 * 1e2);
        assertApproxEqAbs(u_u_bal_0, u_u_bal_1, 1000 * 1e6);
        assert(e_u_bal_0 > e_u_bal_1);
        assert(u_u_bal_0 > u_u_bal_1);
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
        cheats.stopPrank();
        // now trade
        cheats.startPrank(address(accounts[1]));
        uint256 e_bal_0 = euroc.balanceOf(address(accounts[1]));
        uint256 u_bal_0 = usdc.balanceOf(address(accounts[1]));
        eurocUsdcCurve.originSwap(
            address(euroc),
            address(usdc),
            e_bal_0,
            0,
            block.timestamp + 60
        );
        uint256 crvEurocBal_2 = euroc.balanceOf(address(eurocUsdcCurve));
        uint256 crvUsdcBal_2 = usdc.balanceOf(address(eurocUsdcCurve));

        uint256 e_bal_1 = euroc.balanceOf(address(accounts[1]));
        uint256 u_bal_1 = usdc.balanceOf(address(accounts[1]));
        cheats.stopPrank();
        // assume 1.05 USD <= 1 EUR <= 1.1 USD
        assertApproxEqAbs(
            (u_bal_1 - u_bal_0) / (e_bal_0 - e_bal_1) / 100,
            105,
            5
        );
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
        cheats.stopPrank();
        // now trade
        cheats.startPrank(address(accounts[1]));
        uint256 e_bal_0 = weth.balanceOf(address(accounts[1]));
        uint256 u_bal_0 = usdc.balanceOf(address(accounts[1]));
        wethUsdcCurve.originSwap(
            address(weth),
            address(usdc),
            e_bal_0,
            0,
            block.timestamp + 60
        );
        uint256 crvWethBal_2 = weth.balanceOf(address(wethUsdcCurve));
        uint256 crvUsdcBal_2 = usdc.balanceOf(address(wethUsdcCurve));
        uint256 e_bal_1 = weth.balanceOf(address(accounts[1]));
        uint256 u_bal_1 = usdc.balanceOf(address(accounts[1]));
        cheats.stopPrank();
        // assume $0.6 <= 1 matic <= $0.7
        assertApproxEqAbs(
            (u_bal_1 - u_bal_0) / ((e_bal_0 - e_bal_1) / (10 ** (18 - 6 + 2))),
            65,
            5
        );
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
        wethUsdcCurve.originSwapFromETH{value: 10 ether}(
            address(usdc),
            0,
            block.timestamp + 60
        );
        uint256 crvWethBal_2 = (address(wethUsdcCurve)).balance;
        uint256 crvUsdcBal_2 = usdc.balanceOf(address(wethUsdcCurve));
        uint256 e_bal_1 = (address(accounts[1])).balance;
        uint256 u_bal_1 = usdc.balanceOf(address(accounts[1]));
        cheats.stopPrank();
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
        // assume $0.6 <= 1 matic <= $0.7
        assertApproxEqAbs(
            (u_bal_1 - u_bal_2) / ((e_bal_2 - e_bal_1) / (10 ** (18 - 6 + 2))),
            65,
            5
        );
    }

    // test weth-link curve
    function testETHLinkCurve() public {
        // send ETH to lp provider and a trader
        cheats.startPrank(FAUCET);
        payable(address(accounts[0])).call{value: 500 ether}("");
        payable(address(accounts[1])).call{value: 10 ether}("");
        cheats.stopPrank();
        // approve from the provider side
        cheats.startPrank(address(accounts[1]));
        weth.safeApprove(address(wethLinkCurve), type(uint256).max);
        link.safeApprove(address(wethLinkCurve), type(uint256).max);
        cheats.stopPrank();
        // deposit from lp
        cheats.startPrank(address(accounts[0]));
        wethLinkCurve.depositETH{value: 500 ether}(
            500 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        uint256 crvEthBal_1 = weth.balanceOf(address(wethLinkCurve));
        uint256 crvUsdcBal_1 = link.balanceOf(address(wethLinkCurve));
        cheats.stopPrank();
        // now trade
        cheats.startPrank(address(accounts[1]));
        uint256 e_bal_0 = (address(accounts[1])).balance;
        uint256 u_bal_0 = link.balanceOf(address(accounts[1]));
        wethLinkCurve.originSwapFromETH{value: 10 ether}(
            address(link),
            0,
            block.timestamp + 60
        );
        uint256 crvWethBal_2 = weth.balanceOf(address(wethLinkCurve));
        uint256 crvUsdcBal_2 = link.balanceOf(address(wethLinkCurve));

        uint256 e_bal_1 = weth.balanceOf(address(accounts[1]));
        uint256 u_bal_1 = link.balanceOf(address(accounts[1]));
        cheats.stopPrank();
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
        // assume 5 Matic <= 1 Link <= 7 Matic
        assertApproxEqAbs((e_bal_2 - e_bal_1) / (u_bal_1 - u_bal_2), 6, 1);
    }

    // test weth-link curve withdraw in ETH
    function testWithdrawETHLinkCurve() public {
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
        uint256 u_link_0 = link.balanceOf((address(accounts[0])));
        uint256 u_eth_0 = address(accounts[0]).balance;
        uint256 u_weth_0 = weth.balanceOf((address(accounts[0])));
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
        wethLinkCurve.withdrawETH(
            IERC20Detailed(address(wethLinkCurve)).balanceOf(
                address(accounts[0])
            ) / 2,
            block.timestamp + 60
        );
        wethLinkCurve.withdraw(
            IERC20Detailed(address(wethLinkCurve)).balanceOf(
                address(accounts[0])
            ),
            block.timestamp + 60
        );
        uint256 u_link_1 = link.balanceOf((address(accounts[0])));
        uint256 u_eth_1 = address(accounts[0]).balance;
        uint256 u_weth_1 = weth.balanceOf((address(accounts[0])));
        cheats.stopPrank();
        // link diff before deposit & after withdraw shoud be less than 1/1e8 LINK
        assertApproxEqAbs(u_link_1, u_link_0, 1e10);
        // sum of weth + eth diff before deposit & after withdraw shoud be less than 1e10 WEI
        assertApproxEqAbs(u_eth_0 + u_weth_0, u_eth_1 + u_weth_1, 1e10);
        // half of lp withdrawn as ETH, rest is withdrawn as WETH, diff of both withdrawn amounts should be less than 1e10 WEI
        assertApproxEqAbs(u_weth_1 - u_weth_0, u_eth_0 - u_eth_1, 1e10);
    }

    // test weth-link curve withdraw in ETH
    function testLpActionETHLinkCurve() public {
        // send ETH to lp provider and a trader
        cheats.startPrank(FAUCET);
        payable(address(accounts[0])).call{value: 1000 ether}("");
        payable(address(accounts[1])).call{value: 100 ether}("");
        cheats.stopPrank();
        // mint some link tokens to account 1
        deal(
            address(link),
            address(accounts[1]),
            1000000 * decimals[address(link)]
        );
        // approve from the provider side
        cheats.startPrank(address(accounts[1]));
        weth.safeApprove(address(wethLinkCurve), type(uint256).max);
        link.safeApprove(address(wethLinkCurve), type(uint256).max);
        cheats.stopPrank();
        // deposit from lp
        cheats.startPrank(address(accounts[0]));
        wethLinkCurve.depositETH{value: 1000 ether}(
            300 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        cheats.stopPrank();
        cheats.startPrank(address(accounts[1]));
        uint256 u_link_0 = link.balanceOf((address(accounts[1])));
        uint256 u_eth_0 = address(accounts[1]).balance;
        uint256 u_weth_0 = weth.balanceOf((address(accounts[1])));
        wethLinkCurve.depositETH{value: 100 ether}(
            30 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        uint256 u_link_1 = link.balanceOf((address(accounts[1])));
        uint256 u_eth_1 = address(accounts[1]).balance;
        uint256 u_weth_1 = weth.balanceOf((address(accounts[1])));
        wethLinkCurve.withdrawETH(
            IERC20Detailed(address(wethLinkCurve)).balanceOf(
                address(accounts[1])
            ),
            block.timestamp + 60
        );
        uint256 u_link_2 = link.balanceOf((address(accounts[1])));
        uint256 u_eth_2 = address(accounts[1]).balance;
        uint256 u_weth_2 = weth.balanceOf((address(accounts[1])));
        assertApproxEqAbs(u_link_2, u_link_0, u_link_0 / 1000);
        assertApproxEqAbs(u_eth_2, u_eth_0, u_eth_0 / 1000);
        cheats.stopPrank();
    }

    // test zap on weth/usdc pool
    function testZapFromQuote() public {
        uint256 amt = 1000;
        // mint tokens to trader
        deal(
            address(usdc),
            address(accounts[1]),
            amt * decimals[address(usdc)]
        );
        cheats.startPrank(address(accounts[0]));
        wethUsdcCurve.deposit(
            1000000 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        // pool token balances after lp deposit
        uint256 crvWethBal_0 = weth.balanceOf(address(wethUsdcCurve));
        uint256 crvUsdcBal_0 = usdc.balanceOf(address(wethUsdcCurve));
        cheats.stopPrank();
        // now zap
        cheats.startPrank(address(accounts[1]));
        weth.approve(address(wethUsdcCurve), type(uint256).max);
        usdc.safeApprove(address(wethUsdcCurve), type(uint256).max);
        weth.approve(address(zap), type(uint256).max);
        usdc.safeApprove(address(zap), type(uint256).max);
        uint256 u_u_bal_0 = usdc.balanceOf(address(accounts[1]));
        uint256 u_w_bal_0 = weth.balanceOf(address(accounts[1]));
        zap.zap(
            address(wethUsdcCurve),
            u_u_bal_0,
            block.timestamp + 60,
            0,
            address(usdc)
        );
        uint256 userLPBalance = IERC20Detailed(address(wethUsdcCurve))
            .balanceOf(address(accounts[1]));
        // pool token balances after zap
        uint256 crvWethBal_1 = weth.balanceOf(address(wethUsdcCurve));
        uint256 crvUsdcBal_1 = usdc.balanceOf(address(wethUsdcCurve));
        // user balances after zap
        uint256 u_u_bal_1 = usdc.balanceOf(address(accounts[1]));
        uint256 u_w_bal_1 = weth.balanceOf(address(accounts[1]));
        // balance should be approx same in usd balance, assume wmatic ranges from $0.5 ~ $0.7
        assertApproxEqAbs(
            (u_u_bal_1) / (u_w_bal_1 / (10 ** (18 - 6 + 1))),
            6,
            1
        );
        wethUsdcCurve.withdraw(
            IERC20Detailed(address(wethUsdcCurve)).balanceOf(
                address(accounts[1])
            ),
            block.timestamp + 60
        );
        //user balances after lp withdraw
        uint256 u_u_bal_2 = usdc.balanceOf(address(accounts[1]));
        uint256 u_w_bal_2 = weth.balanceOf(address(accounts[1]));
        cheats.stopPrank();
        // assume $0.5 usdc <= 1 matic <= $0.7 usdc
        assert(
            u_u_bal_0 - u_u_bal_2 >= (u_w_bal_2 / 10 ** (18 - 6 + 2)) * 50 &&
                u_u_bal_0 - u_u_bal_2 <= (u_w_bal_2 / 10 ** (18 - 6 + 2)) * 70
        );
    }

    // test routing EURS -> Link (eurs -> usdc -> weth -> link)
    function testRouting() public {
        // mint all tokens to depositor
        cheats.startPrank(FAUCET);
        payable(address(accounts[0])).call{value: 5000 ether}("");
        cheats.stopPrank();
        // mint eurs to the trader
        deal(
            address(euroc),
            address(accounts[1]),
            10000 * decimals[address(euroc)]
        );
        uint256 u_e_bal_0 = euroc.balanceOf(address(accounts[1]));
        uint256 u_l_bal_0 = link.balanceOf(address(accounts[1]));
        // now approve router to spend euroc
        cheats.startPrank(address(accounts[1]));
        euroc.safeApprove(address(router), type(uint256).max);
        cheats.stopPrank();
        // lp depositor provide lps to pools
        cheats.startPrank(address(accounts[0]));
        eurocUsdcCurve.deposit(
            100000 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        wethUsdcCurve.deposit(
            100000 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        wethLinkCurve.deposit(
            100000 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        cheats.stopPrank();
        // init a path
        address[] memory _path = new address[](4);
        _path[0] = address(euroc);
        _path[1] = address(usdc);
        _path[2] = address(weth);
        _path[3] = address(link);
        // now swap using router
        cheats.startPrank(address(accounts[1]));
        router.originSwap(u_e_bal_0, 0, _path, block.timestamp + 60);
        cheats.stopPrank();
        uint256 u_e_bal_1 = euroc.balanceOf(address(accounts[1]));
        uint256 u_l_bal_1 = link.balanceOf(address(accounts[1]));
        // assume euroc is $1~$1.1, link is $5 ~ $5.5
        uint256 eurocInUsdMin = (u_e_bal_0 / (10 ** (2 + 1))) * 10;
        uint256 eurocInUsdMax = (u_e_bal_0 / (10 ** (2 + 1))) * 11;
        uint256 linkInUsdMin = (u_l_bal_1 / 1e18) * 5;
        uint256 linkInUsdMax = (u_l_bal_1 / 1e19) * 55;
        assertApproxEqAbs(eurocInUsdMin, linkInUsdMin, linkInUsdMin / 20);
        assertApproxEqAbs(eurocInUsdMax, linkInUsdMax, linkInUsdMax / 20);
    }

    // test routing EURS -> WETH (eurs -> usdc -> weth -> eth)
    function testRoutingToETH() public {
        // mint all tokens to depositor
        cheats.startPrank(FAUCET);
        payable(address(accounts[0])).call{value: 5000 ether}("");
        payable(address(accounts[1])).call{value: 1000 ether}("");
        cheats.stopPrank();
        // mint token to the trader
        deal(
            address(euroc),
            address(accounts[1]),
            100 * decimals[address(euroc)]
        );
        uint256 u_e_bal_0 = euroc.balanceOf(address(accounts[1]));
        uint256 u_eth_bal_0 = address(accounts[1]).balance;
        // now approve router to spend euroc
        cheats.startPrank(address(accounts[1]));
        euroc.safeApprove(address(router), type(uint256).max);
        cheats.stopPrank();
        // lp depositor provide lps to pools
        cheats.startPrank(address(accounts[0]));
        eurocUsdcCurve.deposit(
            100000 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        wethUsdcCurve.deposit(
            100000 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        wethLinkCurve.deposit(
            100000 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        cheats.stopPrank();
        // init a path
        address[] memory _path = new address[](3);
        _path[0] = address(euroc);
        _path[1] = address(usdc);
        _path[2] = address(weth);
        // now swap using router
        cheats.startPrank(address(accounts[1]));
        router.originSwapToETH(u_e_bal_0, 0, _path, block.timestamp + 60);
        cheats.stopPrank();
        uint256 u_e_bal_1 = euroc.balanceOf(address(accounts[1]));
        uint256 u_eth_bal_1 = address(accounts[1]).balance;
        console.log(u_e_bal_0, u_eth_bal_0);
        console.log(u_e_bal_1, u_eth_bal_1);
        // // assume euroc is $1~$1.1, matic is $0.6 ~ $0.7
        // uint256 eurocInUsdMin = (u_e_bal_0 / (10 ** (2 + 1))) * 10;
        // uint256 eurocInUsdMax = (u_e_bal_0 / (10 ** (2 + 1))) * 11;
        // uint256 maticInUsdMin = (u_eth_bal_1 / 1e19) * 6;
        // uint256 maticInUsdMax = (u_eth_bal_1 / 1e19) * 7;
        // assertApproxEqAbs(eurocInUsdMin, maticInUsdMin, maticInUsdMin / 20);
        // assertApproxEqAbs(eurocInUsdMax, maticInUsdMax, maticInUsdMax / 20);
    }

    // test routing ETH -> EURS (eth -> weth -> usdc -> eurs)
    function testRoutingFromETH() public {
        // mint all tokens to depositor
        cheats.startPrank(FAUCET);
        payable(address(accounts[0])).call{value: 5000 ether}("");
        payable(address(accounts[1])).call{value: 1000 ether}("");
        cheats.stopPrank();
        // mint token to the trader
        uint256 u_e_bal_0 = euroc.balanceOf(address(accounts[1]));
        uint256 u_eth_bal_0 = address(accounts[1]).balance;
        // now approve router to spend euroc
        cheats.startPrank(address(accounts[1]));
        euroc.safeApprove(address(router), type(uint256).max);
        cheats.stopPrank();
        // lp depositor provide lps to pools
        cheats.startPrank(address(accounts[0]));
        eurocUsdcCurve.deposit(
            100000 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        wethUsdcCurve.deposit(
            100000 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        wethLinkCurve.deposit(
            100000 * 1e18,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        cheats.stopPrank();
        // init a path
        address[] memory _path = new address[](3);
        _path[0] = address(weth);
        _path[1] = address(usdc);
        _path[2] = address(euroc);
        cheats.startPrank(address(accounts[1]));
        router.originSwapFromETH{value: 1000 ether}(
            0,
            _path,
            block.timestamp + 60
        );
        cheats.stopPrank();
        uint256 u_e_bal_1 = euroc.balanceOf(address(accounts[1]));
        uint256 u_eth_bal_1 = address(accounts[1]).balance;
        console.log(u_e_bal_0, u_eth_bal_0);
        console.log(u_e_bal_1, u_eth_bal_1);
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

// polygon
// block number 44073000
// 0xE111178A87A3BFf0c8d18DECBa5798827539Ae99 - 109361000
// 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 - 100011825
// 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270 - 59850000
// 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39 - 515578303
