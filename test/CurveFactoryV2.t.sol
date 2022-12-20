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

        // assimilatorFactory = new AssimilatorFactory();
        // curveFactory = new CurveFactoryV2(
        //     protocolFee,
        //     address(treasury),
        //     address(assimilatorFactory)
        // );

        // assimilatorFactory.setCurveFactory(address(curveFactory));

        // cheats.startPrank(address(treasury));
        // // Cadc Curve
        // CurveInfo memory cadcCurveInfo = CurveInfo(
        //     string.concat("dfx-", cadc.name()),
        //     string.concat("dfx-", cadc.symbol()),
        //     address(cadc),
        //     address(usdc),
        //     DefaultCurve.BASE_WEIGHT,
        //     DefaultCurve.QUOTE_WEIGHT,
        //     cadcOracle,
        //     cadc.decimals(),
        //     usdcOracle,
        //     usdc.decimals(),
        //     DefaultCurve.ALPHA,
        //     DefaultCurve.BETA,
        //     DefaultCurve.MAX,
        //     DefaultCurve.EPSILON,
        //     DefaultCurve.LAMBDA
        // );

        // dfxCadcCurve = curveFactory.newCurve(cadcCurveInfo);
        // dfxCadcCurve.turnOffWhitelisting();
        // // Euroc Curve
        // CurveInfo memory eurocCurveInfo = CurveInfo(
        //     string.concat("dfx-", euroc.name()),
        //     string.concat("dfx-", euroc.symbol()),
        //     address(euroc),
        //     address(usdc),
        //     DefaultCurve.BASE_WEIGHT,
        //     DefaultCurve.QUOTE_WEIGHT,
        //     eurocOracle,
        //     euroc.decimals(),
        //     usdcOracle,
        //     usdc.decimals(),
        //     DefaultCurve.ALPHA,
        //     DefaultCurve.BETA,
        //     DefaultCurve.MAX,
        //     DefaultCurve.EPSILON,
        //     DefaultCurve.LAMBDA
        // );

        // dfxEurocCurve = curveFactory.newCurve(eurocCurveInfo);
        // dfxEurocCurve.turnOffWhitelisting();
        // cheats.stopPrank();
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

    function test_depositWithdrawals() public {
        Curve xsgdCurve = Curve(0xdAD7b1656b935959df359464c7f0795c12C5d261);
       
        ERC20 xsgdToken = ERC20(0xDC3326e71D45186F113a2F448984CA0e8D201995);
        ERC20 usdcToken = ERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

        deal(address(xsgdToken), address(this), 100_000e18);
        deal(address(usdcToken), address(this), 100_000e18);

        xsgdToken.approve(address(xsgdCurve), type(uint).max);
        usdcToken.approve(address(xsgdCurve), type(uint).max);

        // 3 people 
        xsgdCurve.deposit(
            1e17,
            block.timestamp + 60
        );
        console.log(xsgdToken.balanceOf(address(xsgdCurve)));
        console.log(usdcToken.balanceOf(address(xsgdCurve)));

        xsgdCurve.deposit(
            1e18,
            block.timestamp + 60
        );
        console.log(xsgdToken.balanceOf(address(xsgdCurve)));
        console.log(usdcToken.balanceOf(address(xsgdCurve)));

        xsgdCurve.withdraw(
            xsgdCurve.balanceOf(address(this)) - 1000,
            block.timestamp + 60
        );
        console.log(xsgdToken.balanceOf(address(xsgdCurve)));
        console.log(usdcToken.balanceOf(address(xsgdCurve)));

        xsgdCurve.deposit(
            1e18,
            block.timestamp + 60
        );
        console.log(xsgdToken.balanceOf(address(xsgdCurve)));
        console.log(usdcToken.balanceOf(address(xsgdCurve)));
    }

    function test_depositWithdrawalsCADC() public {
        Curve cadcCurve = Curve(0xa4FD8BA9BfFF8D0c364EDAD5fDE6E44626097ecF);
       
        ERC20 cadcToken = ERC20(0x9de41aFF9f55219D5bf4359F167d1D0c772A396D);
        ERC20 usdcToken = ERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

        deal(address(cadcToken), address(this), 100_000e18);
        deal(address(usdcToken), address(this), 100_000e18);

        cadcToken.approve(address(cadcCurve), type(uint).max);
        usdcToken.approve(address(cadcCurve), type(uint).max);

        // 3 people 
        // cadcCurve.deposit(
        //     1e17,
        //     block.timestamp + 60
        // );
        // console.log(cadcToken.balanceOf(address(cadcCurve)));
        // console.log(usdcToken.balanceOf(address(cadcCurve)));

        // cadcCurve.deposit(
        //     1e18,
        //     block.timestamp + 60
        // );
        // console.log(cadcToken.balanceOf(address(cadcCurve)));
        // console.log(usdcToken.balanceOf(address(cadcCurve)));
        cheats.prank(0x207e02cf6f85210A08Cb8943495Be67249C1981A);
        cadcCurve.withdraw(
            1099900084188844694,
            block.timestamp + 60
        );
        console.log(cadcToken.balanceOf(address(cadcCurve)));
        console.log(usdcToken.balanceOf(address(cadcCurve)));

        cadcCurve.deposit(
            69e18,
            block.timestamp + 60
        );
        console.log(cadcToken.balanceOf(address(cadcCurve)));
        console.log(usdcToken.balanceOf(address(cadcCurve)));
    }
}
