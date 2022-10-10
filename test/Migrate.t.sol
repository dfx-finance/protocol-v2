
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../src/interfaces/IAssimilator.sol";
import "../src/interfaces/IOracle.sol";
import "../src/interfaces/IERC20Detailed.sol";
import "../src/interfaces/ICurve.sol";
import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/Structs.sol";
import "../src/Router.sol";
import "../src/Migrate.sol";
import "../src/lib/ABDKMath64x64.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";

contract MigrationTest is Test {
    using SafeMath for uint256;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    MockUser multisig;
    MockUser whale;
    MockUser[2] public users;

    IERC20Detailed usdc = IERC20Detailed(Mainnet.USDC);
    IERC20Detailed cadc = IERC20Detailed(Mainnet.CADC);
    IERC20Detailed xsgd = IERC20Detailed(Mainnet.XSGD);
    IERC20Detailed euroc = IERC20Detailed(Mainnet.EUROC);

    uint8 constant fxTokenCount = 3;

    IERC20Detailed[] public foreignStables = [
        cadc,
        xsgd, 
        euroc, 
        usdc
    ];

    ICurve cadcV1Curve = ICurve(0xa6C0CbCaebd93AD3C6c94412EC06aaA37870216d);

    IOracle usdcOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
    IOracle cadcOracle = IOracle(Mainnet.CHAINLINK_CAD_USD);
    IOracle xsgdOracle = IOracle(Mainnet.CHAINLINK_SGD_USD);
    IOracle eurocOracle = IOracle(Mainnet.CHAINLINK_EUR_USD);

    IOracle[] public foreignOracles = [
        cadcOracle,
        xsgdOracle,
        eurocOracle,
        usdcOracle
    ];

    int128 public protocolFee = 50;

    AssimilatorFactory assimilatorFactory;
    CurveFactoryV2 curveFactory;
    Router router;
    Curve[fxTokenCount] dfxCurves;
    DFXRelayer relayer;

    function setUp() public {
        multisig = new MockUser();
        whale = new MockUser();
        relayer = new DFXRelayer();

        for (uint8 i = 0; i < users.length; i++) {
            users[i] = new MockUser();
        }

        assimilatorFactory = new AssimilatorFactory();
        
        curveFactory = new CurveFactoryV2(
            protocolFee,
            address(multisig),
            address(assimilatorFactory)
        );

        router = new Router(address(curveFactory));
        
        assimilatorFactory.setCurveFactory(address(curveFactory));
        
        cheats.startPrank(address(multisig));
        for (uint8 i = 0; i < fxTokenCount; i++) {
            CurveInfo memory curveInfo = CurveInfo(
                string.concat("dfx-", foreignStables[i].symbol()),
                string.concat("dfx-", foreignStables[i].symbol()),
                address(foreignStables[i]),
                address(usdc),
                DefaultCurve.BASE_WEIGHT,
                DefaultCurve.QUOTE_WEIGHT,
                foreignOracles[i],
                foreignStables[i].decimals(),
                usdcOracle,
                usdc.decimals(),
                DefaultCurve.ALPHA,
                DefaultCurve.BETA,
                DefaultCurve.MAX,
                DefaultCurve.EPSILON,
                DefaultCurve.LAMBDA
            );

            dfxCurves[i] = curveFactory.newCurve(curveInfo);
            dfxCurves[i].turnOffWhitelisting();
        }
        cheats.stopPrank();
        
        uint256 user1TknAmnt = 300_000_000;

        // Mint Foreign Stables
        for (uint8 i = 0; i <= fxTokenCount; i++) {
            uint256 decimals = 10 ** foreignStables[i].decimals();
            deal(address(foreignStables[i]), address(users[0]), user1TknAmnt.mul(decimals));
        }
        
        cheats.startPrank(address(users[0]));
        for (uint8 i = 0; i < fxTokenCount; i++) {            
            foreignStables[i].approve(address(dfxCurves[i]), type(uint).max);
            foreignStables[i].approve(address(router), type(uint).max);
            usdc.approve(address(dfxCurves[i]), type(uint).max);
        }
        usdc.approve(address(router), type(uint).max);
        cheats.stopPrank();

        cheats.startPrank(address(users[0]));
        for (uint8 i = 0; i < fxTokenCount; i++) {           
            dfxCurves[i].deposit(100_000_000e18, block.timestamp + 60);
        }
        cheats.stopPrank();
    }

    function testMigration() public {
        // DFX Whale 
        // Setup
        cheats.startPrank(address(msg.sender));
        deal(address(cadc), address(msg.sender), 100_000e18);
        deal(address(usdc), address(msg.sender), 100_000e6);
        cadc.approve(address(cadcV1Curve), type(uint).max);
        usdc.approve(address(cadcV1Curve), type(uint).max);
        cadcV1Curve.deposit(10_000e18, block.timestamp + 60);
        emit log_uint(cadcV1Curve.balanceOf((address(msg.sender))));

        // 1. Approval
        cadcV1Curve.approve(address(relayer), type(uint).max);
        emit log_uint(cadcV1Curve.balanceOf(address(relayer)));
        relayer.migrate(address(cadcV1Curve), address(dfxCurves[0]));
        emit log_uint(cadcV1Curve.balanceOf(address(relayer)));
        cheats.stopPrank();

        emit log_uint(cadc.balanceOf(address(relayer)));
        emit log_uint(usdc.balanceOf(address(relayer)));

        emit log_uint(dfxCurves[0].balanceOf(address(msg.sender)));
        cheats.stopPrank();
    }    
}
