// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library CurveParams {
    // Default Curve Params
    uint256 public constant ALPHA = 800000000000000000;
    uint256 public constant BETA = 420000000000000000;
    uint256 public constant MAX = 230000000000000000;
    uint256 public constant EPSILON = 1500000000000000;
    uint256 public constant LAMBDA = 300000000000000000;

    // Weights
    uint256 public constant BASE_WEIGHT = 5e17;
    uint256 public constant QUOTE_WEIGHT = 5e17;
}
