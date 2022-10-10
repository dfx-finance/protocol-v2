// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../test/lib/Address.sol";
import "./interfaces/ICurve.sol";

// Add is NoDelegateCall
contract DFXRelayer {
    using SafeERC20 for IERC20;

    IERC20 usdc = IERC20(Mainnet.USDC);
    IERC20 cadc = IERC20(Mainnet.CADC);
    
    // Should do some sort of mapping here
    // function migrate(address v1Curve) public {
    function migrate(address v1Curve, address v2Curve) public {
        // V1
        // Check the balance
        uint256 v1Bal = ICurve(v1Curve).balanceOf(msg.sender);
        require(v1Bal > 0, "Relayer/no-lpt");
        ICurve(v1Curve).transferFrom(msg.sender, address(this), v1Bal);
        ICurve(v1Curve).withdraw(v1Bal, block.timestamp + 60);

        // V2
        // Deposit Full amount
        cadc.approve(address(v2Curve), type(uint).max);
        usdc.approve(address(v2Curve), type(uint).max);
        ICurve(v2Curve).deposit(v1Bal, block.timestamp + 60);
        
        // Send new LPT tokens back to the user
        ICurve(v2Curve).transfer(msg.sender, ICurve(v2Curve).balanceOf(address(this)));
        
        // Hard because the curve is not always going to be the same
        // Send remaining tokens to users
        cadc.transfer(msg.sender, cadc.balanceOf(address(this)));
        usdc.transfer(msg.sender, usdc.balanceOf(address(this)));
    }
}