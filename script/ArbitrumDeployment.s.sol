// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./CurveParams.sol";

// Libraries
import "../src/Curve.sol";
import "../src/Config.sol";

// Factories
import "../src/CurveFactoryV2.sol";

// Zap
import "../src/Zap.sol";
import "../src/Router.sol";
import "./Addresses.sol";
import "../src/interfaces/IERC20Detailed.sol";

// POLYGON DEPLOYMENT
contract ContractScript is Script {
    function run() external {
        address OWNER = 0x1246E96b7BC94107aa10a08C3CE3aEcc8E19217B;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // first deploy the config
        int128 protocolFee = 50_000;
        Config config = new Config(protocolFee, OWNER);

        // Deploy Assimilator
        AssimilatorFactory deployedAssimFactory = new AssimilatorFactory(
            address(config)
        );

        // Deploy CurveFactoryV2
        address wETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        CurveFactoryV2 deployedCurveFactory = new CurveFactoryV2(
            address(deployedAssimFactory),
            address(config),
            wETH
        );

        // Attach CurveFactoryV2 to Assimilator
        deployedAssimFactory.setCurveFactory(address(deployedCurveFactory));

        // deploy usdc-cadc, cadc-crv, crv-dodo

        IOracle usdOracle = IOracle(Arbitrum.CHAINLINK_USDC_USD);
        IOracle cadOracle = IOracle(Arbitrum.CHAINLINK_CADC_USD);
        IOracle crvOracle = IOracle(Arbitrum.CHAINLINK_CRV_USD);
        IOracle dodoOracle = IOracle(Arbitrum.CHAINLINK_DODO_USD);

        // usdc-cadc curve info
        CurveInfo memory cadcUsdcCurveInfo = CurveInfo(
            "dfx-cadc-usdc-v2.5",
            "dfx-cadc-usdc-v2.5",
            Arbitrum.CADC,
            Arbitrum.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            cadOracle,
            usdOracle,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Arbitrum.EPSILON,
            CurveParams.LAMBDA
        );

        // cadc-crv curve info
        CurveInfo memory cadcCrvCurveInfo = CurveInfo(
            "dfx-cadc-crv-v2.5",
            "dfx-cadc-crv-v2.5",
            Arbitrum.CADC,
            Arbitrum.CRV,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            cadOracle,
            crvOracle,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Arbitrum.EPSILON,
            CurveParams.LAMBDA
        );

        // crv-dodo curve info
        CurveInfo memory crvDodoCurveInfo = CurveInfo(
            "dfx-dodo-crv-v2.5",
            "dfx-dodo-crv-v2.5",
            Arbitrum.DODO,
            Arbitrum.CRV,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            dodoOracle,
            crvOracle,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Arbitrum.EPSILON,
            CurveParams.LAMBDA
        );

        // Deploy all new Curves
        deployedCurveFactory.newCurve(cadcUsdcCurveInfo);
        deployedCurveFactory.newCurve(cadcCrvCurveInfo);
        deployedCurveFactory.newCurve(crvDodoCurveInfo);
        Zap zap = new Zap(address(deployedCurveFactory));
        Router router = new Router(address(deployedCurveFactory));
        vm.stopBroadcast();
    }
}
