// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Curve.sol";
interface ICurve {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function derivatives(uint256) external view returns (address);
    function balanceOf(address account) external view returns (uint256); 
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool success);
    function withdraw(uint256 curvesToBurn, uint256 deadline) external returns (uint256[] memory);
    function deposit(uint256 deposit, uint256 deadline) external returns (uint256, uint256[] memory);
}
