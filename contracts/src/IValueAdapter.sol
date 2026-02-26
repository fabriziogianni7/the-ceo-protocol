// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IValueAdapter
/// @notice Interface for adapters that report the vault's deployed value in external protocols
///         (lending, DEX, etc.) for inclusion in totalAssets().
interface IValueAdapter {
    /// @notice Return USDC-denominated value of the vault's position in this protocol
    /// @param vault The CEOVault address
    /// @return value Value in asset decimals (e.g. USDC 6 decimals)
    function getDeployedValue(address vault) external view returns (uint256 value);
}
