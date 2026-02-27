// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICEOVault — Interface for The CEO Protocol v2 Vault
/// @notice ERC4626-based USDC vault on Monad governed by AI agents.
///         Integrates ERC-8004 (Trustless Agents) for identity, reputation, and validation.
interface ICEOVault {
    // ══════════════════════════════════════════════════════════════
    //                         ERRORS
    // ══════════════════════════════════════════════════════════════

    /// @notice Thrown when caller is not the contract owner
    error NotOwner();
    error NotAuthorized();

    /// @notice Thrown when caller is not an active registered agent
    error NotActiveAgent();

    /// @notice Thrown when attempting to vote after the voting period has ended
    error VotingPeriodEnded();

    /// @notice Thrown when attempting an action that requires voting to be complete
    error VotingStillOpen();

    /// @notice Thrown when attempting to register as an agent while already registered
    error AlreadyRegistered();

    /// @notice Thrown when attempting to register with insufficient $CEO stake
    error InsufficientCeoStake();

    /// @notice Thrown when claiming an ERC-8004 identity not owned by the caller
    error NotOwnerOfERC8004Identity();

    /// @notice Thrown when agent has not linked an ERC-8004 identity
    error NoERC8004IdentityLinked();

    /// @notice Thrown when ERC-8004 identity registry is not configured
    error IdentityRegistryNotConfigured();

    /// @notice Thrown when submitting a proposal with an empty hash
    error EmptyHash();

    /// @notice Thrown when referencing a non-existent proposal
    error InvalidProposal();

    /// @notice Thrown when attempting to vote twice on the same proposal
    error AlreadyVoted();

    /// @notice Thrown when an agent attempts to submit more than one proposal per epoch
    error AlreadyProposed();

    /// @notice Thrown when the maximum number of proposals per epoch (10) is reached
    error MaxProposalsReached();

    /// @notice Thrown when attempting to execute a proposal that was already executed
    error AlreadyExecuted();

    /// @notice Thrown when a non-CEO tries to execute during the CEO's grace period
    error GracePeriodOnlyCeo();

    /// @notice Thrown when neither the CEO nor second-place agent tries to execute
    error OnlyCeoOrSecond();

    /// @notice Thrown when attempting to execute a proposal that didn't win
    error NotWinningProposal();

    /// @notice Thrown when actions passed to execute do not match the proposal's committed hash
    error ActionsMismatch();

    /// @notice Thrown when attempting to settle an already-settled epoch
    error AlreadySettled();

    /// @notice Thrown when attempting to settle an epoch before the grace period ends
    error TooEarlyToSettle();

    /// @notice Thrown when attempting to get winning proposal from an epoch with no proposals
    error NoProposals();

    /// @notice Thrown when attempting to withdraw fees with zero balance
    error NoFeesToWithdraw();

    /// @notice Thrown when setting max agents below current count
    error BelowCurrentCount();

    /// @notice Thrown when trying to register above max agent count
    error MaxAgentsReached();

    /// @notice Thrown when providing a zero address where it's not allowed
    error ZeroAddress();

    /// @notice Thrown when proposed owner is invalid
    error NotPendingOwner();

    /// @notice Thrown when setting an invalid fee percentage (> 100%)
    error InvalidFeePercentage();

    /// @notice Thrown when an action fails validation (bad selector, bad params, or disallowed target)
    error ActionNotAllowed();

    /// @notice Thrown when an execute action call fails
    error ActionFailed();

    /// @notice Thrown when actions array exceeds the max allowed
    error TooManyActions();

    /// @notice Thrown when an action tries to send native MON (value > 0)
    error NativeTransferNotAllowed();

    /// @notice Thrown when convertPerformanceFee spends more USDC than the pending fee
    error ExcessiveSpending();

    /// @notice Thrown when execute() causes vault value to drop beyond the max drawdown limit
    error ExcessiveDrawdown();

    /// @notice Thrown when the vault cannot pull enough liquidity from yield vaults
    error InsufficientLiquidity();

    /// @notice Thrown when deposit would exceed total vault cap
    error VaultCapReached();

    /// @notice Thrown when deposit would exceed per-address cap
    error MaxDepositPerAddressExceeded();

    /// @notice Thrown when deposit amount is below configured minimum
    error BelowMinDeposit();

    /// @notice Thrown when withdraw/redeem amount is below configured minimum
    error BelowMinWithdraw();

    /// @notice Thrown when setting vault cap below current total assets
    error VaultCapBelowCurrent();

    /// @notice Thrown when there is no pending performance fee to convert
    error NoPerformanceFeeToConvert();

    /// @notice Thrown when slippage check fails during fee conversion
    error SlippageExceeded();

    /// @notice Thrown when adding a yield vault that already exists
    error YieldVaultAlreadyAdded();

    /// @notice Thrown when removing a yield vault that doesn't exist
    error YieldVaultNotFound();

    /// @notice Thrown when ERC-8004 validation registry is not configured
    error ValidationRegistryNotConfigured();

    /// @notice Thrown when requesting validation for an epoch with no execution
    error NoExecutionForEpoch();

    /// @notice Thrown when native MON recovery transfer fails
    error NativeTransferFailed();

    // ══════════════════════════════════════════════════════════════
    //                         STRUCTS
    // ══════════════════════════════════════════════════════════════

    /// @notice Represents a registered agent in the protocol
    struct Agent {
        bool active;
        uint256 ceoStaked;
        int256 score;
        uint256 erc8004Id;
        string metadataURI;
        uint256 registeredAt;
    }

    /// @notice Represents a governance proposal for a strategy allocation
    struct Proposal {
        bytes32 proposalHash;
        string proposalURI;
        address proposer;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 epoch;
        bool executed;
        bool settled;
    }

    /// @notice Represents a single action for the CEO to execute
    struct Action {
        address target;
        uint256 value;
        bytes data;
    }

    // ══════════════════════════════════════════════════════════════
    //                         EVENTS
    // ══════════════════════════════════════════════════════════════

    /// @notice Emitted when an agent successfully registers
    event AgentRegistered(address indexed agent, uint256 ceoStaked, string metadataURI);

    /// @notice Emitted when an agent deregisters and unstakes
    event AgentDeregistered(address indexed agent, uint256 ceoReturned);

    /// @notice Emitted when a new proposal is submitted for an epoch
    event ProposalRegistered(
        uint256 indexed epoch, uint256 indexed proposalId, bytes32 proposalHash, address proposer
    );

    /// @notice Emitted when an agent votes on a proposal
    event Voted(
        uint256 indexed epoch, uint256 indexed proposalId, address indexed voter, bool support, uint256 weight
    );

    /// @notice Emitted when the CEO executes the winning proposal
    event Executed(uint256 indexed epoch, uint256 proposalId, address ceo);

    /// @notice Emitted when an epoch is settled
    event EpochSettled(uint256 indexed epoch, bool profitable, int256 revenue);

    /// @notice Emitted when the CEO changes
    event CEOChanged(address indexed oldCEO, address indexed newCEO);

    /// @notice Emitted when fees are accrued to an agent
    event FeesAccrued(address indexed agent, uint256 amount);

    /// @notice Emitted when an agent withdraws their accumulated fees
    event FeesWithdrawn(address indexed agent, uint256 amount);

    /// @notice Emitted when a yield vault is added
    event YieldVaultAdded(address indexed vault);

    /// @notice Emitted when a yield vault is removed
    event YieldVaultRemoved(address indexed vault);

    /// @notice Emitted when a whitelisted target is set or unset
    event WhitelistedTargetSet(address indexed target, bool allowed);

    /// @notice Emitted when performance fee is accrued at epoch settlement
    event PerformanceFeeAccrued(uint256 indexed epoch, uint256 usdcAmount);

    /// @notice Emitted when performance fee USDC is converted to $CEO
    event PerformanceFeeConverted(uint256 ceoAmount, address indexed executor);

    /// @notice Emitted when treasury address is updated
    event TreasuryUpdated(address indexed newTreasury);

    /// @notice Emitted when an agent links an ERC-8004 identity NFT
    event ERC8004IdentityLinked(address indexed agent, uint256 indexed erc8004Id);

    /// @notice Emitted when agent reputation is posted to ERC-8004
    event ERC8004ReputationPosted(uint256 indexed epoch, address indexed agent, int128 scoreDelta);

    /// @notice Emitted when ERC-8004 registry addresses are updated
    event ERC8004RegistriesUpdated(address identity, address reputation, address validation);

    /// @notice Emitted when max drawdown basis points is updated
    event MaxDrawdownBpsSet(uint256 bps);

    /// @notice Emitted when minimum deposit threshold (asset decimals) is updated
    event MinDepositSet(uint256 amount);

    /// @notice Emitted when minimum withdraw threshold (asset decimals) is updated
    event MinWithdrawSet(uint256 amount);

    /// @notice Emitted when owner recovers accidentally sent native MON
    event NativeRecovered(address indexed to, uint256 amount);
}
