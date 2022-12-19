// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

library Polygon {
    // Tokens
    address public constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant CADC = 0x9de41aFF9f55219D5bf4359F167d1D0c772A396D;

    // Oracles
    // 8-decimals
    address public constant CHAINLINK_USDC_USD = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;
    address public constant CHAINLINK_CAD_USD = 0xACA44ABb8B04D07D883202F99FA5E3c53ed57Fb5;
}
