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

contract ContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address POLYGON_MULTISIG = 0x207e02cf6f85210A08Cb8943495Be67249C1981A;

        AssimilatorFactory deployedAssimFactory = new AssimilatorFactory();

        CurveFactoryV2 deployedCurveFactory = new CurveFactoryV2(
            50_000,
            POLYGON_MULTISIG, // TODO MOVE THIS TO ADDRESSES
            address(deployedAssimFactory)    
        );

        deployedAssimFactory.setCurveFactory(address(deployedCurveFactory));

        // Tokens
        IERC20Detailed usdc = IERC20Detailed(Polygon.USDC);
        IERC20Detailed cadc = IERC20Detailed(Polygon.CADC);

        // Oracles
        IOracle usdcOracle = IOracle(Polygon.CHAINLINK_USDC_USD);
        IOracle cadcOracle = IOracle(Polygon.CHAINLINK_CAD_USD);

        CurveInfo memory cadcCurveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            address(cadc),
            address(usdc),
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            cadcOracle,
            cadc.decimals(),
            usdcOracle,
            usdc.decimals(),
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            CurveParams.EPSILON,
            CurveParams.LAMBDA
        );

        Curve cadcCurve = deployedCurveFactory.newCurve(cadcCurveInfo);

        cadc.approve(
            address(cadcCurve),
            type(uint256).max
        );
        usdc.approve(
            address(cadcCurve),
            type(uint256).max
        );

        cadcCurve.deposit(
            1e17,
            block.timestamp + 60
        );

        vm.stopBroadcast();
    }
}
