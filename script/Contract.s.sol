// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

// Libraries
import "../src/Curve.sol";
import "../src/Curve.sol";
import "../src/Curve.sol";
import "../src/Curve.sol";

// Factories
import "../src/CurveFactoryV2.sol";

contract ContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address POLYGON_MULTISIG = 0x80D27bfb638F4Fea1e862f1bd07DEa577CB77D38;

        AssimilatorFactory deployedAssimFactory = new AssimilatorFactory();

        // CurveFactoryV2 deployedCurveFactory = new CurveFactoryV2(
        //     50_000,
        //     POLYGON_MULTISIG
            
        // );

        vm.stopBroadcast();
    }
}
