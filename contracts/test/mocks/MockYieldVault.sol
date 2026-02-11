// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MockYieldVault — Minimal ERC4626 vault for testing yield vault integration
/// @dev Supports simulating yield by calling `simulateYield(amount)` which mints extra
///      USDC directly into the vault, increasing the share price.
contract MockYieldVault is ERC4626 {
    IERC20 private _usdc;

    constructor(IERC20 usdc_) ERC20("Mock Yield Vault", "myUSDC") ERC4626(usdc_) {
        _usdc = usdc_;
    }

    function decimals() public pure override(ERC4626) returns (uint8) {
        return 6;
    }

    /// @notice Simulate yield accrual by externally adding USDC to the vault
    /// @dev Call MockUSDC.mint(address(this), amount) before or use this helper
    ///      This function is just a no-op marker; the actual yield comes from
    ///      extra USDC balance in the vault.
    function simulateYield() external view {
        // Yield is simulated by minting USDC directly to address(this)
        // via MockUSDC.mint(address(vault), amount)
        // This increases totalAssets() and thus share price
        this; // silence state mutability warning
    }
}
