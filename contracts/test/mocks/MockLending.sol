// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MockLending — Minimal lending-style contract for testing non-yield-vault targets
/// @dev supply(uint256) pulls USDC from msg.sender; redeem(uint256) returns USDC.
///      Used to test whitelisted target + allowed selector flows.
contract MockLending {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;

    mapping(address => uint256) public balanceOf;

    constructor(IERC20 asset_) {
        asset = asset_;
    }

    function supply(uint256 amount) external {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender] += amount;
    }

    function redeem(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "MockLending: insufficient balance");
        balanceOf[msg.sender] -= amount;
        asset.safeTransfer(msg.sender, amount);
    }
}
