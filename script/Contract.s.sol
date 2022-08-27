// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/CurveFactoryV2.sol";
import "../src/AssimilatorFactory.sol";
import "../src/Ablah.sol";

contract ContractScript is Script {
    // int128 protocolFee_ = 50_000; // 50%
    // address dfxTreasury_ =  0x80D27bfb638F4Fea1e862f1bd07DEa577CB77D38;
    
    function setUp() public {}

    function run() public {
        vm.broadcast();

        Ablah blah = new Ablah();
        // AssimilatorFactory assimilatorFactory = new AssimilatorFactory();
        // CurveFactoryV2 curvefactoryv2 = new CurveFactoryV2(
            // protocolFee_,
            // dfxTreasury_,
            // address(assimilatorFactory)
        // );
        
        vm.stopBroadcast();
    }
}
