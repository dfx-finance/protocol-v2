// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.10;

// import "forge-std/Test.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// import "../src/interfaces/IAssimilator.sol";
// import "../src/interfaces/IOracle.sol";
// import "../src/interfaces/IERC20Detailed.sol";
// import "../src/AssimilatorFactory.sol";
// import "../src/CurveFactoryV2.sol";
// import "../src/Curve.sol";
// import "../src/Config.sol";
// import "../src/Structs.sol";
// import "../src/Zap.sol";
// import "../src/lib/ABDKMath64x64.sol";

// import "./lib/MockUser.sol";
// import "./lib/CheatCodes.sol";
// import "./lib/Address.sol";
// import "./lib/CurveParams.sol";
// import "./lib/MockChainlinkOracle.sol";
// import "./lib/MockOracleFactory.sol";
// import "./lib/MockToken.sol";

// import "./utils/Utils.sol";

// contract MultipleQuotesTest is Test {
//     using SafeMath for uint256;
//     using SafeERC20 for IERC20Detailed;
//     CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
//     Utils utils;

//     // account order is lp provider, trader, treasury
//     MockUser[] public accounts;

//     // tokens
//     IERC20Detailed euroc;
//     IERC20Detailed cadc;
//     IERC20Detailed usdc;
//     IERC20Detailed usdt;
//     IERC20Detailed dai;

//     // oracles
//     IOracle eurocOracle;
//     IOracle cadcOracle;
//     IOracle usdcOracle;
//     IOracle usdtOracle;
//     IOracle daiOracle;

//     // decimals
//     mapping (address => uint256) decimals;

//     // curves
//     Curve public eurocUsdtCurve;
//     Curve public eurocUsdcCurve;
//     Curve public usdcUsdtCurve;

//     Config config;
//     CurveFactoryV2 curveFactory;
//     AssimilatorFactory assimFactory;

//     function setUp() public {

//         utils = new Utils();
//         // create temp accounts
//         for(uint256 i = 0; i < 4; ++i){
//             accounts.push(new MockUser());
//         }
//         // init tokens
//         euroc = IERC20Detailed(Mainnet.EUROC);
//         cadc = IERC20Detailed(Mainnet.CADC);
//         usdc = IERC20Detailed(Mainnet.USDC);
//         usdt = IERC20Detailed(Mainnet.USDT);
//         dai = IERC20Detailed(Mainnet.DAI);

//         // deploy mock oracle factory for deployed token (named gold)
//         eurocOracle = IOracle(Mainnet.CHAINLINK_EUR_USD);
//         cadcOracle = IOracle(Mainnet.CHAINLINK_CAD_USD);
//         usdcOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
//         usdtOracle = IOracle(Mainnet.CHAINLINK_USDT_USD);
//         daiOracle = IOracle(Mainnet.CHAINLINK_DAI_USD);

//         config = new Config(50000,address(accounts[2]));
//         // now add quotes
//         config.addNewQuoteCurrency(address(usdt),usdt.decimals(),address(usdtOracle), usdtOracle.decimals());
//         config.addNewQuoteCurrency(address(usdc),usdc.decimals(),address(usdcOracle), usdcOracle.decimals());
//         // deploy new assimilator factory & curveFactory v2
//         assimFactory = new AssimilatorFactory();
//         curveFactory = new CurveFactoryV2(
//              address(assimFactory),
//              address(config)
//         );
//         assimFactory.setCurveFactory(address(curveFactory));
//         // now deploy curves
//         eurocUsdtCurve = createCurve("euroc-usdt",address(euroc),address(usdt),address(eurocOracle),address(usdtOracle));
//         eurocUsdcCurve = createCurve("euroc-usdc",address(euroc),address(usdc),address(eurocOracle),address(usdcOracle));
//         usdcUsdtCurve = createCurve("usdt-usdc",address(usdc),address(usdt),address(usdcOracle),address(usdtOracle));
//     }

//     function createCurve(string memory name, address base, address quote,address baseOracle, address quoteOracle) public returns (Curve) {
//         cheats.startPrank(address(accounts[2]));
//         CurveInfo memory curveInfo = CurveInfo(
//             string(abi.encode("dfx-curve-",name)),
//             string(abi.encode("lp-",name)),
//             base,
//             quote,
//             DefaultCurve.BASE_WEIGHT,
//             DefaultCurve.QUOTE_WEIGHT,
//             IOracle(baseOracle),
//             IOracle(quoteOracle),
//             DefaultCurve.ALPHA,
//             DefaultCurve.BETA,
//             DefaultCurve.MAX,
//             DefaultCurve.EPSILON,
//             DefaultCurve.LAMBDA
//         );
//         Curve _curve = curveFactory.newCurve(curveInfo);
//         cheats.stopPrank();
//         // now mint base token, update decimals map
//         uint256 mintAmt = 300_000_000_000;
//         uint256 baseDecimals = utils.tenToPowerOf(IERC20Detailed(base).decimals());
//         decimals[base] = baseDecimals;
//         deal(base,address(accounts[0]), mintAmt.mul(baseDecimals));
//         // now mint quote token, update decimals map
//         uint256 quoteDecimals = utils.tenToPowerOf(IERC20Detailed(quote).decimals());
//         decimals[quote] = quoteDecimals;
//         deal(quote,address(accounts[0]), mintAmt.mul(quoteDecimals));
//         // now approve the deployed curve
//         cheats.startPrank(address(accounts[0]));
//         // IERC20Detailed(base).approve(address(_curve), 0);
//         IERC20Detailed(base).approve(address(_curve), type(uint256).max);
//         // IERC20Detailed(quote).approve(address(_curve), 0);
//         IERC20Detailed(quote).safeApprove(address(_curve), type(uint256).max);
//         cheats.stopPrank();
//         return _curve;
//     }

//     // test euroc-usdt curve, usdt is a quote
//     function testEurocUsdtCurve() public {
//         uint256 amt = 1000000;
//         // mint tokens to trader
//         deal(address(euroc),address(accounts[1]), amt * decimals[address(euroc)]);
//         cheats.startPrank(address(accounts[1]));
//         euroc.approve(address(eurocUsdtCurve),type(uint256).max);
//         usdt.safeApprove(address(eurocUsdtCurve), type(uint256).max);
//         cheats.stopPrank();
//         // deposit from lp
//         cheats.startPrank(address(accounts[0]));
//         eurocUsdtCurve.deposit(1000000000 * 1e18,0,0,type(uint256).max, type(uint256).max, block.timestamp + 60);
//         cheats.stopPrank();
//         // now trade
//         cheats.startPrank(address(accounts[1]));
//         uint256 e_bal_0 = euroc.balanceOf(address(accounts[1]));
//         uint256 u_bal_0 = usdt.balanceOf(address(accounts[1]));
//         eurocUsdtCurve.originSwap(
//             address(euroc),
//             address(usdt),
//             e_bal_0,
//             0,
//             block.timestamp + 60
//         );
//         uint256 e_bal_1 = euroc.balanceOf(address(accounts[1]));
//         uint256 u_bal_1 = usdt.balanceOf(address(accounts[1]));
//         cheats.stopPrank();
//         console.logString("before swap, euroc & usdt");
//         console.log(e_bal_0);
//         console.log(u_bal_0);
//         console.logString("after swap, euroc & usdt");
//         console.log(e_bal_1);
//         console.log(u_bal_1);
//         console.logString("swap diff, euroc & usdt");
//         console.log(e_bal_0 - e_bal_1);
//         console.log(u_bal_1 - u_bal_0);
//     }

//     // test euroc-usdt curve, usdt is a quote
//     function testEurocUsdcCurve() public {
//         uint256 amt = 10000;
//         // mint tokens to trader
//         deal(address(euroc),address(accounts[1]), amt * decimals[address(euroc)]);
//         deal(address(usdc),address(accounts[1]), amt * decimals[address(usdc)]);
//         cheats.startPrank(address(accounts[1]));
//         euroc.approve(address(eurocUsdcCurve),type(uint256).max);
//         usdc.safeApprove(address(eurocUsdcCurve), type(uint256).max);
//         cheats.stopPrank();
//         // deposit from lp
//         cheats.startPrank(address(accounts[0]));
//         eurocUsdcCurve.deposit(100000 * 1e18,0,0,type(uint256).max, type(uint256).max, block.timestamp + 60);
//         uint256 crvEurocBal_1 = euroc.balanceOf(address(eurocUsdcCurve));
//         uint256 crvUsdcBal_1 = usdc.balanceOf(address(eurocUsdcCurve));
//         console.logString("after providing lp, euroc & usdc bals respectively");
//         console.log(crvEurocBal_1);
//         console.log(crvUsdcBal_1);
//         cheats.stopPrank();
//         // now trade
//         cheats.startPrank(address(accounts[1]));
//         uint256 e_bal_0 = euroc.balanceOf(address(accounts[1]));
//         uint256 u_bal_0 = usdc.balanceOf(address(accounts[1]));
//         console.logString("before swap, user 1 euroc & usdc bals");
//         console.log(e_bal_0);
//         console.log(u_bal_0);
//         eurocUsdcCurve.originSwap(
//             address(euroc),
//             address(usdc),
//             e_bal_0,
//             0,
//             block.timestamp + 60
//         );
//         uint256 crvEurocBal_2 = euroc.balanceOf(address(eurocUsdcCurve));
//         uint256 crvUsdcBal_2 = usdc.balanceOf(address(eurocUsdcCurve));
//         console.logString("after swap, euroc & usdc bals respectively");
//         console.log(crvEurocBal_2);
//         console.log(crvUsdcBal_2);

//         uint256 e_bal_1 = euroc.balanceOf(address(accounts[1]));
//         uint256 u_bal_1 = usdc.balanceOf(address(accounts[1]));
//         cheats.stopPrank();
//         console.logString("after swap, euroc & usdc");
//         console.log(e_bal_1);
//         console.log(u_bal_1);
//         console.logString("swap diff, euroc & usdc");
//         console.log(e_bal_0 - e_bal_1);
//         console.log(u_bal_1 - u_bal_0);
//     }

//     // test euroc-usdt curve, usdt is a quote
//     function testUsdcUsdtCurve() public {
//         uint256 amt = 10000;
//         // mint tokens to trader
//         deal(address(usdt),address(accounts[1]), amt * decimals[address(euroc)]);
//         deal(address(usdc),address(accounts[1]), amt * decimals[address(usdc)]);
//         cheats.startPrank(address(accounts[1]));
//         usdc.approve(address(usdcUsdtCurve),type(uint256).max);
//         usdt.safeApprove(address(usdcUsdtCurve), type(uint256).max);
//         cheats.stopPrank();
//         // deposit from lp
//         cheats.startPrank(address(accounts[0]));
//         usdcUsdtCurve.deposit(100000 * 1e18,0,0,type(uint256).max, type(uint256).max, block.timestamp + 60);
//         uint256 crvUsdtBal_1 = usdt.balanceOf(address(usdcUsdtCurve));
//         uint256 crvUsdcBal_1 = usdc.balanceOf(address(usdcUsdtCurve));
//         console.logString("after providing lp, usdt & usdc bals respectively");
//         console.log(crvUsdtBal_1);
//         console.log(crvUsdcBal_1);
//         cheats.stopPrank();
//         // now trade
//         cheats.startPrank(address(accounts[1]));
//         uint256 t_bal_0 = usdt.balanceOf(address(accounts[1]));
//         uint256 c_bal_0 = usdc.balanceOf(address(accounts[1]));
//         console.logString("before swap, user 1 usdt & usdc bals");
//         console.log(t_bal_0);
//         console.log(c_bal_0);
//         usdcUsdtCurve.originSwap(
//             address(usdt),
//             address(usdc),
//             t_bal_0,
//             0,
//             block.timestamp + 60
//         );
//         uint256 crvUsdtBal_2 = usdt.balanceOf(address(usdcUsdtCurve));
//         uint256 crvUsdcBal_2 = usdc.balanceOf(address(usdcUsdtCurve));
//         console.logString("after swap, usdt & usdc bals respectively");
//         console.log(crvUsdtBal_2);
//         console.log(crvUsdcBal_2);

//         uint256 t_bal_1 = usdt.balanceOf(address(accounts[1]));
//         uint256 c_bal_1 = usdc.balanceOf(address(accounts[1]));
//         cheats.stopPrank();
//         console.logString("after swap, usdt & usdc");
//         console.log(t_bal_1);
//         console.log(c_bal_1);
//         console.logString("swap diff, usdt & usdc");
//         console.log(t_bal_0 - t_bal_1);
//         console.log(c_bal_1 - c_bal_0);
//     }
// }