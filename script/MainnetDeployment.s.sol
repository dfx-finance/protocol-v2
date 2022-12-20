// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./CurveParams.sol";

// Libraries
import "../src/Curve.sol";
import "../src/Curve.sol";
import "../src/Curve.sol";
import "../src/Curve.sol";

// Factories
import "../src/CurveFactoryV2.sol";

import "./Addresses.sol";
import '../src/interfaces/IERC20Detailed.sol';

// MAINNET DEPLOYMENT
// CHANGE assimilators/AssimilatorV2.sol's hardcoded USDC address
contract ContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Assimilator
        AssimilatorFactory deployedAssimFactory = new AssimilatorFactory();

        // Deploy CurveFactoryV2
        CurveFactoryV2 deployedCurveFactory = new CurveFactoryV2(
            50_000,
            Mainnet.MULTISIG,
            address(deployedAssimFactory)    
        );

        // Attach CurveFactoryV2 to Assimilator
        deployedAssimFactory.setCurveFactory(address(deployedCurveFactory));

        IOracle usdOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
        IOracle cadOracle = IOracle(Mainnet.CHAINLINK_CAD_USD);
        IOracle eurOracle = IOracle(Mainnet.CHAINLINK_EUR_USD);
        IOracle sgdOracle = IOracle(Mainnet.CHAINLINK_SGD_USD);
        IOracle nzdOracle = IOracle(Mainnet.CHAINLINK_NZD_USD);
        IOracle tryOracle = IOracle(Mainnet.CHAINLINK_TRY_USD);
        IOracle yenOracle = IOracle(Mainnet.CHAINLINK_YEN_USD);
        IOracle idrOracle = IOracle(Mainnet.CHAINLINK_IDR_USD);

        CurveInfo memory cadcCurveInfo = CurveInfo(
            "dfx-cadc-usdc-v2",
            "dfx-cadc-v2",
            Mainnet.CADC,
            Mainnet.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            cadOracle,
            Mainnet.CADC_DECIMALS,
            usdOracle,
            Mainnet.USDC_DECIMALS,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Mainnet.CADC_EPSILON,
            CurveParams.LAMBDA
        );

        CurveInfo memory eurocCurveInfo = CurveInfo(
            "dfx-euroc-usdc-v2",
            "dfx-euroc-v2",
            Mainnet.EUROC,
            Mainnet.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            eurOracle,
            Mainnet.EUROC_DECIMALS,
            usdOracle,
            Mainnet.USDC_DECIMALS,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Mainnet.EUROC_EPSILON,
            CurveParams.LAMBDA
        );

        CurveInfo memory xsgdCurveInfo = CurveInfo(
            "dfx-xsgd-usdc-v2",
            "dfx-xsgd-v2",
            Mainnet.XSGD,
            Mainnet.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            sgdOracle,
            Mainnet.XSGD_DECIMALS,
            usdOracle,
            Mainnet.USDC_DECIMALS,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Mainnet.XSGD_EPSILON,
            CurveParams.LAMBDA
        );

        CurveInfo memory nzdsCurveInfo = CurveInfo(
            "dfx-nzds-usdc-v2",
            "dfx-nzds-v2",
            Mainnet.NZDS,
            Mainnet.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            nzdOracle,
            Mainnet.NZDS_DECIMALS,
            usdOracle,
            Mainnet.USDC_DECIMALS,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Mainnet.NZDS_EPSILON,
            CurveParams.LAMBDA
        );

        CurveInfo memory trybCurveInfo = CurveInfo(
            "dfx-tryb-usdc-v2",
            "dfx-tryb-v2",
            Mainnet.TRYB,
            Mainnet.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            tryOracle,
            Mainnet.TRYB_DECIMALS,
            usdOracle,
            Mainnet.USDC_DECIMALS,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Mainnet.TRYB_EPSILON,
            CurveParams.LAMBDA
        );

        CurveInfo memory gyenCurveInfo = CurveInfo(
            "dfx-gyen-usdc-v2",
            "dfx-gyen-v2",
            Mainnet.GYEN,
            Mainnet.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            yenOracle,
            Mainnet.GYEN_DECIMALS,
            usdOracle,
            Mainnet.USDC_DECIMALS,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Mainnet.GYEN_EPSILON,
            CurveParams.LAMBDA
        );

        CurveInfo memory xidrCurveInfo = CurveInfo(
            "dfx-xidr-usdc-v2",
            "dfx-xidr-v2",
            Mainnet.XIDR,
            Mainnet.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            idrOracle,
            Mainnet.XIDR_DECIMALS,
            usdOracle,
            Mainnet.USDC_DECIMALS,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Mainnet.XIDR_EPSILON,
            CurveParams.LAMBDA
        );

        // Deploy all new Curves
        deployedCurveFactory.newCurve(cadcCurveInfo);
        deployedCurveFactory.newCurve(eurocCurveInfo);
        deployedCurveFactory.newCurve(xsgdCurveInfo);
        deployedCurveFactory.newCurve(nzdsCurveInfo);
        deployedCurveFactory.newCurve(trybCurveInfo);
        deployedCurveFactory.newCurve(gyenCurveInfo);
        deployedCurveFactory.newCurve(xidrCurveInfo);

        vm.stopBroadcast();
    }
}