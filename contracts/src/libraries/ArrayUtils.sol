// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ArrayUtils
/// @notice Swap-and-pop utilities for address and bytes4 arrays
library ArrayUtils {
    /// @dev Remove an address from an array (swap with last, pop). O(1) deletion.
    /// @param arr Storage array
    /// @param elem Element to remove
    /// @return found True if element was found and removed
    function removeAddress(address[] storage arr, address elem) internal returns (bool found) {
        uint256 len = arr.length;
        for (uint256 i = 0; i < len; i++) {
            if (arr[i] == elem) {
                arr[i] = arr[len - 1];
                arr.pop();
                return true;
            }
        }
        return false;
    }

    /// @dev Remove a bytes4 from an array (swap with last, pop). O(1) deletion.
    /// @param arr Storage array
    /// @param elem Element to remove
    /// @return found True if element was found and removed
    function removeBytes4(bytes4[] storage arr, bytes4 elem) internal returns (bool found) {
        uint256 len = arr.length;
        for (uint256 i = 0; i < len; i++) {
            if (arr[i] == elem) {
                arr[i] = arr[len - 1];
                arr.pop();
                return true;
            }
        }
        return false;
    }
}
