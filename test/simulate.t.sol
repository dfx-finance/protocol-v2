// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../src/interfaces/IAssimilator.sol";
import "../src/interfaces/IOracle.sol";
import "../src/interfaces/IERC20Detailed.sol";
import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/Structs.sol";
import "../src/Router.sol";
import "../src/lib/ABDKMath64x64.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";
import "./lib/MockChainlinkOracle.sol";
import "./lib/MockOracleFactory.sol";
import "./lib/MockToken.sol";

import "./utils/Utils.sol";

contract SimulationTest is Test {
    using SafeMath for uint256;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Utils utils;

    // account order is lp provider, trader, treasury
    MockUser[] public accounts;
    IERC20Detailed public TRYB;
    IERC20Detailed public USDC;

    // mainnet forked contracts set 
    CurveFactoryV2 m_curveFactory;
    Curve m_trybCurve;
    Router m_router;
    address public DFX_GOV_ADDR = 0x27E843260c71443b4CC8cB6bF226C3f77b9695AF;
    address public TRYB_CURVE_ADDR = 0xcF3c8f51DE189C8d5382713B716B133e485b99b7;
    address public ROUTER_ADDR = 0xA06943F16e0bcd73025807428C0aB1088575f1B7;
    address public CURVE_FACTORY_ADDR = 0xDE5bb69892D663f1facBE351363509BcB65573AA;
    address public ASSIM_FACTORY_ADDR = 0x46Fa2e883cc7DdFfEd39C55300Ee4e6d31a8268c;
    address public SIMULATING_USER_ADDR = 0x29770812d00E6C24dE42D7F51274A05e6A3C04F0;

    // newly deployed contract sets
    CurveFactoryV2 curveFactory;
    Curve trybCurve;
    Router router;
    AssimilatorFactory assimFactory;
    IOracle usdcOracle;
    IOracle trybOracle;
    function setUp() public {

        utils = new Utils();
        // create temp accounts
        for(uint256 i = 0; i < 4; ++i){
            accounts.push(new MockUser());
        }
        TRYB = IERC20Detailed(Mainnet.TRYB);
        USDC = IERC20Detailed(Mainnet.USDC);
        // mainnet fork contracts
        m_curveFactory = CurveFactoryV2(CURVE_FACTORY_ADDR);
        m_router = Router(ROUTER_ADDR);

        // deploy new contracts
        usdcOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
        trybOracle = IOracle(Mainnet.CHAINLINK_TRYB_USD);
        assimFactory = new AssimilatorFactory();
        curveFactory = new CurveFactoryV2(
            50000,address(accounts[2]),address(assimFactory)
        );
        assimFactory.setCurveFactory(address(curveFactory));
        router = new Router(address(curveFactory));
        
        cheats.startPrank(address(accounts[2]));
        CurveInfo memory curveInfo = CurveInfo(
            string(abi.encode("dfx-curve-tryb")),
            string(abi.encode("lp-tryb")),
            Mainnet.TRYB,
            Mainnet.USDC,
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            trybOracle,
            TRYB.decimals(),
            usdcOracle,
            USDC.decimals(),
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        trybCurve = curveFactory.newCurve(curveInfo);
        trybCurve.turnOffWhitelisting();
        cheats.stopPrank();
        // now mint tryb & usdc to accounts[0]
        deal(Mainnet.TRYB, address(accounts[0]),2154906512665500);
        deal (Mainnet.USDC, address (accounts[0]),45018157598100);
        cheats.startPrank(address(accounts[0]));
        TRYB.approve(address(trybCurve), type(uint).max);
        USDC.approve(address(trybCurve), type(uint).max);
        cheats.stopPrank();
        
    }

    function testNewSwap () public {
        // now mint try to user 1 - trader
        deal(Mainnet.TRYB, address(accounts[1]), 400045771040);


        cheats.startPrank(address(accounts[0]));
        trybCurve.deposit(600000 * 1e18, block.timestamp+60);
        cheats.stopPrank();
        uint256 curveTrybBal = TRYB.balanceOf(address(trybCurve));
        uint256 curveUsdcBal = USDC.balanceOf(address(trybCurve));
        uint256 treasuryUsdcBal = USDC.balanceOf(address(accounts[2]));
        uint256 treasuryTrybBal = TRYB.balanceOf(address(accounts[2]));
        uint256 traderUsdcBal = USDC.balanceOf(address(accounts[1]));
        uint256 traderTrybBal = TRYB.balanceOf(address(accounts[1]));
        console.logString("before swap");
        console.log(parseAmount(curveTrybBal));
        console.log(parseAmount(curveUsdcBal));
        console.log(parseAmount(treasuryUsdcBal));
        console.log(parseAmount(treasuryTrybBal));
        console.log(parseAmount(traderUsdcBal));
        console.log(parseAmount(traderTrybBal));
        // mint usdc to user 3
        deal(Mainnet.USDC, address(accounts[3]), 119999000000);
        // now first swap from user 3, whole usdc to tryb
        cheats.startPrank(address(accounts[3]));
        // USDC.approve(address(router), 119999000000);
        // router.originSwap(Mainnet.USDC, Mainnet.USDC, Mainnet.TRYB, 119999000000, 0, block.timestamp + 60);
        USDC.approve(address(router), 11999900000);
        router.originSwap(Mainnet.USDC, Mainnet.USDC, Mainnet.TRYB, 11999900000, 0, block.timestamp + 60);
        cheats.stopPrank();
        uint256 treasuryTrybBal_user3 = TRYB.balanceOf(address(accounts[2]));
        uint256 treasuryUsdcBal_user3 = USDC.balanceOf(address(accounts[2]));
        uint256 user3TrybBal = TRYB.balanceOf(address(accounts[3]));
        uint256 user3UsdcBal = USDC.balanceOf(address(accounts[3]));
        uint256 user3CurveTrybBal = TRYB.balanceOf(address(trybCurve));
        uint256 user3CurveUsdcBal = USDC.balanceOf(address(trybCurve));
        console.logString("after user3 swaps");
        console.log(parseAmount(treasuryUsdcBal_user3));
        console.log(parseAmount(user3TrybBal));
        console.log(parseAmount(user3UsdcBal));
        console.log(parseAmount(user3CurveTrybBal));
        console.log(parseAmount(user3CurveUsdcBal));

        console.logString("new treasury diff tryb from user3 swap is ");
        console.log(parseAmount(treasuryTrybBal_user3));
        

        cheats.startPrank(address(accounts[1]));
        TRYB.approve(address(router), type(uint).max);
        router.originSwap(Mainnet.USDC, Mainnet.TRYB, Mainnet.USDC, 400045771040, 0, block.timestamp+60);
        cheats.stopPrank();
        console.logString("new treasury balances");
        uint256 treasuryUsdcBal_1 = USDC.balanceOf(address(accounts[2]));
        uint256 treasuryTrybBal_1 = TRYB.balanceOf(address(accounts[2]));
        uint256 traderUsdcBal_1 = USDC.balanceOf(address(accounts[1]));
        uint256 traderTrybBal_1 = TRYB.balanceOf(address(accounts[1]));
        // console.log(curveTrybBal);
        // console.log(curveUsdcBal);
        console.log(parseAmount(treasuryUsdcBal_1));
        console.log(parseAmount(treasuryTrybBal_1));
        console.log(parseAmount(traderUsdcBal_1));
        console.log(parseAmount(traderTrybBal_1));
        console.log("treasury usdc diff");
        console.log(parseAmount(treasuryUsdcBal_1 - treasuryUsdcBal));
    }
    //  first read the balance
    function testMainnetForkSwap() public {
        uint256 userTrybBal = TRYB.balanceOf(SIMULATING_USER_ADDR);
        uint256 curveTrybBal = TRYB.balanceOf(TRYB_CURVE_ADDR );
        uint256 curveUsdcBal = USDC.balanceOf(TRYB_CURVE_ADDR);
        uint256 govUsdcBal = USDC.balanceOf(DFX_GOV_ADDR);

        console.logString("before swap");
        console.log(parseAmount(userTrybBal));
        console.log(parseAmount(curveTrybBal));
        console.log(parseAmount(curveUsdcBal));
        console.log(parseAmount(govUsdcBal));

        // now try swap tryb to usdc
        cheats.startPrank(SIMULATING_USER_ADDR);
        // USDC.approve(address(m_router), type(uint256).max);
        m_router.originSwap(
            Mainnet.USDC,
            Mainnet.TRYB,
            Mainnet.USDC,
            400045771040,
            0,
            block.timestamp + 60
        );
        uint256 userTrybBal_1 = TRYB.balanceOf(SIMULATING_USER_ADDR);
        uint256 userUsdcBal_1 = USDC.balanceOf(SIMULATING_USER_ADDR);
        uint256 curveTrybBal_1 = TRYB.balanceOf(TRYB_CURVE_ADDR );
        uint256 curveUsdcBal_1 = USDC.balanceOf(TRYB_CURVE_ADDR);
        uint256 govUsdcBal_1 = USDC.balanceOf(DFX_GOV_ADDR);

        console.logString("after swap");
        console.log(parseAmount(userTrybBal_1));
        console.log(parseAmount(userUsdcBal_1));
        console.log(parseAmount(curveTrybBal_1));
        console.log(parseAmount(curveUsdcBal_1));
        console.log(parseAmount(govUsdcBal_1));

        console.logString("fee earned in usdc is ");
        console.log(parseAmount(govUsdcBal_1 - govUsdcBal));


    }

    function parseAmount (uint256 original) public view returns (uint256 amount) {
        amount = original.div(1000000);
    }
}
