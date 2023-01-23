// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/interfaces/IERC20Detailed.sol";
import "../src/interfaces/IAssimilator.sol";
import "../src/interfaces/IOracle.sol";

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
        
        cheats.startPrank(address(treasury));
        assimilatorFactory = new AssimilatorFactory();
        curveFactory = new CurveFactoryV2(
            protocolFee,
            address(treasury),
            address(assimilatorFactory)
        );

        assimilatorFactory.setCurveFactory(address(curveFactory));
        cheats.stopPrank();
    }

    function testFrontRunningDoS() public { // wrong/malicious info
        cheats.startPrank(address(treasury));
        CurveInfo memory cadcCurveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            address(cadc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            eurocOracle,
            0,
            eurocOracle,
            0,
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        dfxCadcCurve = curveFactory.newCurve(cadcCurveInfo);
        AssimilatorV2 assimilator = assimilatorFactory.getAssimilator(address(cadc));
        cadc.approve(address(assimilator), 100);
        assimilator.intakeRaw(0);

        console.log(dfxCadcCurve.assimilator(address(cadc)));
        console.log(dfxCadcCurve.assimilator(address(usdc)));


        IAssimilator cadcAssim = IAssimilator(dfxCadcCurve.assimilator(address(cadc)));
        IAssimilator usdcAssim = IAssimilator(dfxCadcCurve.assimilator(address(usdc)));

        console.log(cadcAssim.getRate());
        console.log(usdcAssim.getRate());

        // revoke
        assimilatorFactory.revokeAssimilator(address(cadc));
        assimilatorFactory.revokeAssimilator(address(usdc));

        // slide in new assimilators
        assimilatorFactory.newAssimilator(
            cadcOracle,
            address(cadc),
            18
        );

        assimilatorFactory.newAssimilator(
            usdcOracle,
            address(usdc),
            6
        );


        IAssimilator cadcAssimNew = assimilatorFactory.getAssimilator(address(cadc));
        IAssimilator usdcAssimNew = assimilatorFactory.getAssimilator(address(usdc));

        dfxCadcCurve.setAssimilator(
            address(cadc),
            address(cadcAssimNew), 
            address(usdc), 
            address(usdcAssimNew)
        );

        console.log(dfxCadcCurve.assimilator(address(cadc)));
        console.log(dfxCadcCurve.assimilator(address(usdc)));

        console.log(cadcAssimNew.getRate());
        console.log(usdcAssimNew.getRate());

        // make new pair, this time with right parameters?
        // cadcCurveInfo = CurveInfo(
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
        // no, due to pair exist check
        // cheats.expectRevert("CurveFactory/pair-exists");
        // dfxCadcCurve = curveFactory.newCurve(cadcCurveInfo);

        
        cheats.stopPrank();
    }
}