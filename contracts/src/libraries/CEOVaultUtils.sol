// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICEOVaultV2} from "../ICEOVaultV2.sol";

/// @title CEOVaultUtils
/// @notice Pure utility functions for CEOVault
library CEOVaultUtils {
    /// @dev Rank weights: rank 1=10, rank 2=9, ..., rank 10=1. CEO staked is not used for reward share.
    /// @param count Number of agents to distribute to
    /// @param amount Total amount to distribute
    /// @return shares Array of shares per rank
    function computeRankedShares(uint256 count, uint256 amount)
        internal
        pure
        returns (uint256[] memory shares)
    {
        if (count == 0 || amount == 0) return new uint256[](0);

        shares = new uint256[](count);
        uint256 totalWeight;
        for (uint256 i = 0; i < count; i++) {
            totalWeight += (10 - i);
        }

        if (totalWeight == 0) return shares;

        for (uint256 i = 0; i < count; i++) {
            uint256 weight = 10 - i;
            shares[i] = amount * weight / totalWeight;
        }
    }

    /// @dev Get target amount for a vault from allocation (0 if not in allocation)
    /// @param vault Yield vault address
    /// @param allocations Allocation targets
    /// @param totalValue Total assets value
    /// @return Target amount in asset decimals
    function getTargetForVault(
        address vault,
        ICEOVaultV2.AllocationTarget[] calldata allocations,
        uint256 totalValue
    ) internal pure returns (uint256) {
        for (uint256 i = 0; i < allocations.length; i++) {
            if (allocations[i].vault == vault) {
                return totalValue * allocations[i].bps / 10_000;
            }
        }
        return 0;
    }

    /// @dev Convert uint to string for ERC-8004 tags
    /// @param value Unsigned integer to convert
    /// @return String representation
    function uint2str(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
