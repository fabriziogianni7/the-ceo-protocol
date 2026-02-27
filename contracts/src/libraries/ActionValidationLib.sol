// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ICEOVaultV2} from "../ICEOVaultV2.sol";
import {AllocationLib} from "./AllocationLib.sol";

/// @title ActionValidationLib
/// @notice Library for validating CEOVault execute actions.
///         Use: ActionValidationLib.validateAction(vaultAddr, assetAddr, ceoTokenAddr, ..., action)
library ActionValidationLib {
    /// @dev Validate a single action's target, selector, and critical parameters.
    ///      Rules:
    ///        1. Native MON transfers (value > 0) are forbidden.
    ///        2. Token contracts (USDC, $CEO, approvable tokens): only approve() to a whitelisted spender.
    ///        3. Yield vaults: only ERC4626 deposit/mint/withdraw/redeem with receiver/owner = vaultAddr.
    ///        4. Other whitelisted targets (adapters): only explicitly allowed selectors.
    ///        5. Self-calls: addApprovableToken, removeApprovableToken, executeRebalance only.
    function validateAction(
        address vaultAddr,
        address assetAddr,
        address ceoTokenAddr,
        bytes4 addApprovableTokenSelector,
        bytes4 removeApprovableTokenSelector,
        bytes4 executeRebalanceSelector,
        mapping(address => bool) storage isYieldVault,
        mapping(address => bool) storage isWhitelistedTarget,
        mapping(address => bool) storage isApprovableToken,
        mapping(address => mapping(bytes4 => bool)) storage allowedSelectors,
        ICEOVaultV2.Action calldata action
    ) internal view returns (bool) {
        address target = action.target;
        bytes calldata data = action.data;

        if (action.value > 0) return false;
        if (data.length < 4) return false;

        bytes4 sel = bytes4(data[:4]);

        if (target == vaultAddr) {
            if (sel == addApprovableTokenSelector) {
                if (data.length < 36) return false;
                address token = abi.decode(data[4:36], (address));
                return token != address(0);
            }
            if (sel == removeApprovableTokenSelector) {
                if (data.length < 36) return false;
                address token = abi.decode(data[4:36], (address));
                return isApprovableToken[token];
            }
            if (sel == executeRebalanceSelector) {
                if (data.length < 68) return false;
                // Data is selector (4 bytes) + abi.encode(allocations), not abi.encode(selector, allocations)
                ICEOVaultV2.AllocationTarget[] memory allocs = abi.decode(data[4:], (ICEOVaultV2.AllocationTarget[]));
                return AllocationLib.validateAllocations(allocs, isYieldVault);
            }
            return false;
        }

        if (target == assetAddr || target == ceoTokenAddr || isApprovableToken[target]) {
            if (data.length < 68) return false;
            if (sel != IERC20.approve.selector) return false;
            address spender = abi.decode(data[4:36], (address));
            return isWhitelistedTarget[spender];
        }

        if (isYieldVault[target]) {
            if (sel == IERC4626.deposit.selector || sel == IERC4626.mint.selector) {
                if (data.length < 68) return false;
                address receiver = abi.decode(data[36:68], (address));
                return receiver == vaultAddr;
            }

            if (sel == IERC4626.withdraw.selector || sel == IERC4626.redeem.selector) {
                if (data.length < 100) return false;
                address receiver = abi.decode(data[36:68], (address));
                address owner_ = abi.decode(data[68:100], (address));
                return receiver == vaultAddr && owner_ == vaultAddr;
            }

            return false;
        }

        if (!isWhitelistedTarget[target]) return false;
        return allowedSelectors[target][sel];
    }
}
