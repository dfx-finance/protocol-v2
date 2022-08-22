// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/CurveFactory.sol";
import "../src/AssimilatorFactory.sol";

contract ContractScript is Script {
    int128 protocolFee_ = 50_000; // 50%
    address dfxTreasury_ =  0x26f539A0fE189A7f228D7982BF10Bc294FA9070c;
    
    function setUp() public {}

    function run() public {
        vm.broadcast();

        AssimilatorFactory assimilatorFactory = new AssimilatorFactory();
        CurveFactory curvefactoryv2 = new CurveFactory(
            // protocolFee_,
            // dfxTreasury_,
            // address(assimilatorFactory)
        );
        
        vm.stopBroadcast();
    }
}
