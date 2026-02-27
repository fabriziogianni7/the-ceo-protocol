// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICEOVaultV2} from "./ICEOVaultV2.sol";
import {IERC8004Identity} from "./erc8004/IERC8004Identity.sol";
import {IERC8004Reputation} from "./erc8004/IERC8004Reputation.sol";
import {IERC8004Validation} from "./erc8004/IERC8004Validation.sol";

/// @title CEOVaultConfig
/// @notice Mixin for CEOVault admin/configuration state and setters.
///         Inherit and ensure onlyOwner modifier is available in the final contract.
abstract contract CEOVaultConfig is ICEOVaultV2 {
    uint256 public constant MAX_FEE_BPS = 2000;
    uint256 public constant MAX_ALLOCATION_TARGETS = 10;

    // ── Ownership ──
    address public s_owner;
    address public s_pendingOwner;

    // ── Configuration ──
    address public s_treasury;
    uint256 public s_entryFeeBps;
    address public s_entryFeeRecipient;
    uint256 public s_ceoStakeVotingMultiplier;
    uint256 public s_minCeoStake;
    uint256 public s_vaultCap;
    uint256 public s_maxDepositPerAddress;
    uint256 public s_minDeposit;
    uint256 public s_minWithdraw;
    uint256 public s_epochDuration;
    uint256 public s_maxAgents;
    uint256 public s_maxActions;
    uint256 public s_maxDrawdownBps;

    // ── Default Allocation (deposit hook) ──
    address[MAX_ALLOCATION_TARGETS] public s_defaultVaults;
    uint256[MAX_ALLOCATION_TARGETS] public s_defaultBps;
    uint8 public s_defaultCount;

    // ── ERC-8004 ──
    IERC8004Identity public s_erc8004Identity;
    IERC8004Reputation public s_erc8004Reputation;
    IERC8004Validation public s_erc8004Validation;

    modifier onlyConfigOwner() {
        if (msg.sender != s_owner) revert NotOwner();
        _;
    }

    /// @notice Transfer ownership — step 1: propose new owner
    function transferOwnership(address newOwner) external virtual onlyConfigOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        s_pendingOwner = newOwner;
    }

    /// @notice Transfer ownership — step 2: new owner accepts
    function acceptOwnership() external virtual {
        if (msg.sender != s_pendingOwner) revert NotPendingOwner();
        s_owner = msg.sender;
        s_pendingOwner = address(0);
    }

    /// @notice Set treasury address (entry fee recipient)
    function setTreasury(address newTreasury) external virtual onlyConfigOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        s_treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /// @notice Set entry fee (basis points)
    function setEntryFeeBps(uint256 bps) external virtual onlyConfigOwner {
        if (bps > MAX_FEE_BPS) revert InvalidFeePercentage();
        s_entryFeeBps = bps;
    }

    /// @notice Set entry fee recipient. address(0) = treasury, address(this) = distribute to top 10 agents
    function setEntryFeeRecipient(address recipient) external virtual onlyConfigOwner {
        s_entryFeeRecipient = recipient;
        emit EntryFeeRecipientSet(recipient);
    }

    /// @notice Set voting weight multiplier for staked $CEO
    function setCeoStakeVotingMultiplier(uint256 multiplier) external virtual onlyConfigOwner {
        s_ceoStakeVotingMultiplier = multiplier;
    }

    /// @notice Set minimum $CEO stake for agent registration
    function setMinCeoStake(uint256 amount) external virtual onlyConfigOwner {
        s_minCeoStake = amount;
    }

    /// @notice Set total vault cap (0 = no cap)
    function setVaultCap(uint256 cap) external virtual onlyConfigOwner {
        if (cap > 0 && _configTotalAssets() > cap) revert VaultCapBelowCurrent();
        s_vaultCap = cap;
    }

    /// @notice Set max deposit per address (0 = no cap)
    function setMaxDepositPerAddress(uint256 cap) external virtual onlyConfigOwner {
        s_maxDepositPerAddress = cap;
    }

    /// @notice Set minimum deposit/mint amount in asset decimals (0 = no minimum)
    function setMinDeposit(uint256 amount) external virtual onlyConfigOwner {
        s_minDeposit = amount;
        emit MinDepositSet(amount);
    }

    /// @notice Set minimum withdraw/redeem amount in asset decimals (0 = no minimum)
    function setMinWithdraw(uint256 amount) external virtual onlyConfigOwner {
        s_minWithdraw = amount;
        emit MinWithdrawSet(amount);
    }

    /// @notice Set epoch duration (seconds)
    function setEpochDuration(uint256 duration) external virtual onlyConfigOwner {
        s_epochDuration = duration;
    }

    /// @notice Set maximum number of agents
    function setMaxAgents(uint256 max) external virtual onlyConfigOwner {
        if (max < _configAgentListLength()) revert BelowCurrentCount();
        s_maxAgents = max;
    }

    /// @notice Set maximum actions per execute call
    function setMaxActions(uint256 max) external virtual onlyConfigOwner {
        s_maxActions = max;
    }

    /// @notice Set maximum drawdown in basis points per execute call (0 = no limit)
    function setMaxDrawdownBps(uint256 bps) external virtual onlyConfigOwner {
        if (bps > 10_000) revert InvalidFeePercentage();
        s_maxDrawdownBps = bps;
        emit MaxDrawdownBpsSet(bps);
    }

    /// @notice Set the default allocation for the deposit hook
    function setDefaultAllocation(address[] calldata vaults, uint256[] calldata bps) external virtual onlyConfigOwner {
        if (vaults.length != bps.length) revert InvalidAllocationCount();
        if (vaults.length > MAX_ALLOCATION_TARGETS) revert InvalidAllocationCount();

        uint256 totalBps;
        for (uint256 i = 0; i < vaults.length; i++) {
            if (!_configIsYieldVault(vaults[i])) revert InvalidAllocationVault();
            totalBps += bps[i];
            s_defaultVaults[i] = vaults[i];
            s_defaultBps[i] = bps[i];
        }
        if (totalBps > 10_000) revert AllocationBpsExceedMax();

        s_defaultCount = uint8(vaults.length);
        emit DefaultAllocationSet(vaults.length);
    }

    /// @notice Clear the default allocation (disables deposit hook)
    function clearDefaultAllocation() external virtual onlyConfigOwner {
        s_defaultCount = 0;
        emit DefaultAllocationCleared();
    }

    /// @notice Configure ERC-8004 registries
    function setERC8004Registries(address identity, address reputation, address validation) external virtual onlyConfigOwner {
        s_erc8004Identity = IERC8004Identity(identity);
        s_erc8004Reputation = IERC8004Reputation(reputation);
        s_erc8004Validation = IERC8004Validation(validation);
        emit ERC8004RegistriesUpdated(identity, reputation, validation);
    }

    /// @dev Override in derived contract to provide totalAssets()
    function _configTotalAssets() internal view virtual returns (uint256);

    /// @dev Override in derived contract to provide agent list length
    function _configAgentListLength() internal view virtual returns (uint256);

    /// @dev Override in derived contract to provide isYieldVault check
    function _configIsYieldVault(address vault) internal view virtual returns (bool);
}
