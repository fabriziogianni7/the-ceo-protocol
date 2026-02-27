// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ICEOVaultV2} from "../ICEOVaultV2.sol";
import {CEOVaultUtils} from "./CEOVaultUtils.sol";

/// @title AllocationLib
/// @notice Library for computing and validating yield vault allocation plans
library AllocationLib {
    uint256 internal constant MAX_ALLOCATION_TARGETS = 10;

    /// @dev Validate allocations: length, vaults must be yield vaults, no duplicates, total bps <= 10_000.
    /// @param allocations Allocation targets to validate
    /// @param isYieldVault Mapping of vault address to whether it's a yield vault
    /// @return valid True if valid
    function validateAllocations(
        ICEOVaultV2.AllocationTarget[] memory allocations,
        mapping(address => bool) storage isYieldVault
    ) internal view returns (bool valid) {
        if (allocations.length == 0 || allocations.length > MAX_ALLOCATION_TARGETS) return false;
        uint256 totalBps;
        for (uint256 i = 0; i < allocations.length; i++) {
            if (!isYieldVault[allocations[i].vault]) return false;
            totalBps += allocations[i].bps;
            for (uint256 j = 0; j < i; j++) {
                if (allocations[j].vault == allocations[i].vault) return false;
            }
        }
        return totalBps <= 10_000;
    }

    /// @dev Get the asset value currently deployed in a specific yield vault
    /// @param vaultAddr Address holding the shares (typically the CEOVault)
    /// @param yieldVault Yield vault (ERC4626) address
    /// @return assets Asset value of shares held
    function getValueInVault(address vaultAddr, address yieldVault) internal view returns (uint256 assets) {
        uint256 shares = IERC20(yieldVault).balanceOf(vaultAddr);
        if (shares == 0) return 0;
        try IERC4626(yieldVault).convertToAssets(shares) returns (uint256 a) {
            return a;
        } catch {
            return 0;
        }
    }

    /// @dev Compute allocation plan (withdraws and deposits) from allocations and total value
    /// @param yieldVaults List of yield vault addresses
    /// @param allocations Target allocation per vault
    /// @param totalValue Total assets under management
    /// @param vaultAddr Address holding the shares (typically the CEOVault)
    /// @return plan Allocation plan with withdraw/deposit arrays
    function computeAllocationPlan(
        address[] storage yieldVaults,
        ICEOVaultV2.AllocationTarget[] calldata allocations,
        uint256 totalValue,
        address vaultAddr
    ) internal view returns (ICEOVaultV2.AllocationPlan memory plan) {
        uint256 withdrawCount;
        uint256 depositCount;
        for (uint256 i = 0; i < yieldVaults.length; i++) {
            address vault = yieldVaults[i];
            uint256 current = getValueInVault(vaultAddr, vault);
            uint256 target = CEOVaultUtils.getTargetForVault(vault, allocations, totalValue);
            if (current > target && (current - target) > 0) withdrawCount++;
        }
        for (uint256 i = 0; i < allocations.length; i++) {
            address vault = allocations[i].vault;
            uint256 target = totalValue * allocations[i].bps / 10_000;
            uint256 current = getValueInVault(vaultAddr, vault);
            if (target > current && (target - current) > 0) depositCount++;
        }

        plan.withdrawVaults = new address[](withdrawCount);
        plan.withdrawAmounts = new uint256[](withdrawCount);
        plan.depositVaults = new address[](depositCount);
        plan.depositAmounts = new uint256[](depositCount);

        uint256 wi;
        uint256 di;
        for (uint256 i = 0; i < yieldVaults.length; i++) {
            address vault = yieldVaults[i];
            uint256 current = getValueInVault(vaultAddr, vault);
            uint256 target = CEOVaultUtils.getTargetForVault(vault, allocations, totalValue);
            if (current > target) {
                uint256 amt = current - target;
                if (amt > 0) {
                    plan.withdrawVaults[wi] = vault;
                    plan.withdrawAmounts[wi] = amt;
                    wi++;
                }
            }
        }
        for (uint256 i = 0; i < allocations.length; i++) {
            address vault = allocations[i].vault;
            uint256 target = totalValue * allocations[i].bps / 10_000;
            uint256 current = getValueInVault(vaultAddr, vault);
            if (target > current) {
                uint256 amt = target - current;
                if (amt > 0) {
                    plan.depositVaults[di] = vault;
                    plan.depositAmounts[di] = amt;
                    di++;
                }
            }
        }
    }
}
