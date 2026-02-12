// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ERC4626Fees} from "./ERC4626Fees.sol";
import {ICEOVault} from "./ICEOVault.sol";
import {AgentRankingLib} from "./libraries/AgentRankingLib.sol";
import {IERC8004Identity} from "./erc8004/IERC8004Identity.sol";
import {IERC8004Reputation} from "./erc8004/IERC8004Reputation.sol";
import {IERC8004Validation} from "./erc8004/IERC8004Validation.sol";

/// @title CEOVault — The CEO Protocol v2
/// @notice ERC4626-based USDC vault on Monad governed by AI agents.
///         Agents stake $CEO to participate in governance, propose strategies,
///         and vote. The top agent (CEO) executes the winning strategy via
///         yield vault deployments. Revenue is shared between depositors (via
///         share price appreciation) and agents (via performance fees converted
///         to $CEO). Entry fees go to a configurable treasury.
contract CEOVault is ICEOVault, ERC4626Fees, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ══════════════════════════════════════════════════════════════
    //                        CONSTANTS
    // ══════════════════════════════════════════════════════════════

    int256 public constant SCORE_PROPOSAL_SUBMITTED = 3;
    int256 public constant SCORE_PROPOSAL_WON = 5;
    int256 public constant SCORE_PROPOSAL_PROFITABLE = 10;
    int256 public constant SCORE_VOTED = 1;
    int256 public constant SCORE_VOTED_WINNING_SIDE = 2;
    int256 public constant SCORE_PROPOSAL_UNPROFITABLE = -5;
    int256 public constant SCORE_CEO_MISSED = -10;

    uint256 public constant MAX_FEE_BPS = 2000; // 20% hard cap for any fee

    // ══════════════════════════════════════════════════════════════
    //                     STATE VARIABLES
    // ══════════════════════════════════════════════════════════════

    // ── Immutables ──
    IERC20 public immutable i_ceoToken;

    // ── Ownership ──
    address public s_owner;
    address public s_pendingOwner;

    // ── Configuration ──
    address public s_treasury;
    uint256 public s_entryFeeBps;
    uint256 public s_performanceFeeBps;
    uint256 public s_minCeoStake;
    uint256 public s_vaultCap;
    uint256 public s_maxDepositPerAddress;
    uint256 public s_minDeposit; // min assets per deposit/mint (0 = no minimum)
    uint256 public s_minWithdraw; // min assets per withdraw/redeem (0 = no minimum)
    uint256 public s_epochDuration;
    uint256 public s_ceoGracePeriod;
    uint256 public s_maxAgents;
    uint256 public s_maxActions;
    uint256 public s_maxDrawdownBps; // max vault value drop per execute (e.g. 3000 = 30%)

    // ── Yield Vaults ──
    address[] public s_yieldVaults;
    mapping(address => bool) public s_isYieldVault;
    mapping(address => bool) public s_isWhitelistedTarget;

    // ── Epoch State ──
    uint256 public s_currentEpoch;
    uint256 public s_epochStartTime;
    bool public s_epochExecuted;
    mapping(uint256 => uint256) public s_epochStartAssets;
    mapping(uint256 => uint256) public s_epochDeposits;
    mapping(uint256 => uint256) public s_epochWithdrawals;

    // ── Performance Fee ──
    uint256 public s_pendingPerformanceFeeUsdc;

    // ── Agent Registry ──
    address[] public s_agentList;
    mapping(address => Agent) public s_agents;
    mapping(address => uint256) private _s_agentIndex; // 1-based

    // ── Proposals ──
    uint256 public constant MAX_PROPOSALS_PER_EPOCH = 10;
    mapping(uint256 => Proposal[]) public s_epochProposals;
    mapping(uint256 => mapping(address => bool)) public s_hasProposed;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public s_hasVoted;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public s_voteSupport;

    // ── Agent Fees ──
    mapping(address => uint256) public s_claimableFees;

    // ── ERC-8004 ──
    IERC8004Identity public s_erc8004Identity;
    IERC8004Reputation public s_erc8004Reputation;
    IERC8004Validation public s_erc8004Validation;

    // ══════════════════════════════════════════════════════════════
    //                       CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════

    /// @notice Deploy the CEO Vault
    /// @param asset_ USDC token address on Monad
    /// @param ceoToken_ $CEO governance token
    /// @param treasury_ Recipient of entry fees (buys $CEO from nad.fun)
    /// @param entryFeeBps_ Entry fee in basis points (e.g. 100 = 1%)
    /// @param performanceFeeBps_ Performance fee in basis points (e.g. 100 = 1%)
    /// @param minCeoStake_ Minimum $CEO an agent must stake to register
    /// @param vaultCap_ Maximum total USDC the vault can hold (0 = no cap)
    /// @param maxDepositPerAddress_ Maximum USDC any single address can deposit (0 = no cap)
    /// @param epochDuration_ Duration of each epoch in seconds
    /// @param ceoGracePeriod_ Grace period after voting for CEO to execute
    /// @param maxAgents_ Maximum number of agents allowed
    /// @param maxActions_ Maximum number of actions per execute call
    constructor(
        IERC20 asset_,
        IERC20 ceoToken_,
        address treasury_,
        uint256 entryFeeBps_,
        uint256 performanceFeeBps_,
        uint256 minCeoStake_,
        uint256 vaultCap_,
        uint256 maxDepositPerAddress_,
        uint256 epochDuration_,
        uint256 ceoGracePeriod_,
        uint256 maxAgents_,
        uint256 maxActions_
    ) ERC20("CEO Vault USDC", "ceoUSDC") ERC4626(asset_) {
        if (treasury_ == address(0)) revert ZeroAddress();
        if (entryFeeBps_ > MAX_FEE_BPS) revert InvalidFeePercentage();
        if (performanceFeeBps_ > MAX_FEE_BPS) revert InvalidFeePercentage();

        i_ceoToken = ceoToken_;

        s_owner = msg.sender;
        s_treasury = treasury_;
        s_entryFeeBps = entryFeeBps_;
        s_performanceFeeBps = performanceFeeBps_;
        s_minCeoStake = minCeoStake_;
        s_vaultCap = vaultCap_;
        s_maxDepositPerAddress = maxDepositPerAddress_;
        s_epochDuration = epochDuration_;
        s_ceoGracePeriod = ceoGracePeriod_;
        s_maxAgents = maxAgents_;
        s_maxActions = maxActions_;

        // Start epoch 1
        s_currentEpoch = 1;
        s_epochStartTime = block.timestamp;
        s_epochStartAssets[1] = 0;
    }

    /// @dev Accept native token (MON) for execute actions (e.g., nad.fun buy)
    receive() external payable {}

    // ══════════════════════════════════════════════════════════════
    //                        MODIFIERS
    // ══════════════════════════════════════════════════════════════

    modifier onlyOwner() {
        if (msg.sender != s_owner) revert NotOwner();
        _;
    }

    modifier onlyActiveAgent() {
        if (!s_agents[msg.sender].active) revert NotActiveAgent();
        _;
    }

    modifier duringVoting() {
        if (block.timestamp >= s_epochStartTime + s_epochDuration) revert VotingPeriodEnded();
        _;
    }

    modifier afterVoting() {
        if (block.timestamp < s_epochStartTime + s_epochDuration) revert VotingStillOpen();
        _;
    }

    // ══════════════════════════════════════════════════════════════
    //                    ERC4626 OVERRIDES
    // ══════════════════════════════════════════════════════════════

    /// @notice Maximum assets that can be deposited for receiver (enforces vault cap and per-address cap)
    function maxDeposit(address receiver) public view virtual override returns (uint256) {
        uint256 capped = type(uint256).max;
        if (s_vaultCap > 0) {
            uint256 current = totalAssets();
            if (current >= s_vaultCap) return 0;
            capped = s_vaultCap - current;
        }
        if (s_maxDepositPerAddress > 0) {
            uint256 receiverAssets = convertToAssets(balanceOf(receiver));
            if (receiverAssets >= s_maxDepositPerAddress) return 0;
            uint256 perAddressRemaining = s_maxDepositPerAddress - receiverAssets;
            if (perAddressRemaining < capped) capped = perAddressRemaining;
        }
        return capped;
    }

    /// @notice Maximum shares that can be minted for receiver (enforces vault cap and per-address cap)
    function maxMint(address receiver) public view virtual override returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (maxAssets == 0) return 0;
        return previewDeposit(maxAssets);
    }

    /// @notice Total assets under management: idle USDC + deployed in yield vaults - pending performance fees
    function totalAssets() public view virtual override returns (uint256) {
        uint256 idle = IERC20(asset()).balanceOf(address(this)); 
        uint256 deployed = _deployedValue();
        uint256 total = idle + deployed;
        return total > s_pendingPerformanceFeeUsdc ? total - s_pendingPerformanceFeeUsdc : 0;
    }

    /// @dev Track net deposits per epoch (assets minus entry fee), then call ERC4626Fees._deposit
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        if (s_minDeposit > 0 && assets < s_minDeposit) revert BelowMinDeposit();

        // Compute fee the same way ERC4626Fees does
        uint256 feeBps = _entryFeeBasisPoints();
        uint256 fee = feeBps > 0 ? _feeOnTotal(assets, feeBps) : 0;
        s_epochDeposits[s_currentEpoch] += (assets - fee);

        super._deposit(caller, receiver, assets, shares);
    }

    /// @dev Track withdrawals per epoch, then call ERC4626Fees._withdraw
    function _withdraw(
        address caller,
        address receiver,
        address owner_,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (s_minWithdraw > 0 && assets < s_minWithdraw) revert BelowMinWithdraw();

        s_epochWithdrawals[s_currentEpoch] += assets;

        super._withdraw(caller, receiver, owner_, assets, shares);
    }

    /// @dev Pull from yield vaults if idle USDC is insufficient for the transfer
    function _transferOut(address to, uint256 assets) internal virtual override {
        _ensureLiquidity(assets);
        super._transferOut(to, assets);
    }

    /// @dev Use a small decimal offset to mitigate the ERC4626 inflation attack
    function _decimalsOffset() internal pure override returns (uint8) {
        return 6; // USDC has 6 decimals; offset of 6 gives 12 virtual decimals
    }

    // ══════════════════════════════════════════════════════════════
    //                   FEE CONFIGURATION
    // ══════════════════════════════════════════════════════════════

    /// @dev Entry fee in basis points (sent to treasury on each deposit)
    function _entryFeeBasisPoints() internal view virtual override returns (uint256) {
        return s_entryFeeBps;
    }

    /// @dev No exit fee
    function _exitFeeBasisPoints() internal view virtual override returns (uint256) {
        return 0;
    }

    /// @dev Entry fee goes to treasury (which buys $CEO from nad.fun)
    function _entryFeeRecipient() internal view virtual override returns (address) {
        return s_treasury;
    }

    /// @dev No exit fee recipient
    function _exitFeeRecipient() internal view virtual override returns (address) {
        return address(0);
    }

    // ══════════════════════════════════════════════════════════════
    //                     YIELD VAULTS
    // ══════════════════════════════════════════════════════════════

    /// @notice Add a yield vault to the whitelist (owner only)
    /// @dev Yield vaults must implement IERC4626 for totalAssets queries and on-demand pull.
    ///      Owner-only to prevent CEO from injecting a malicious contract.
    /// @param vault Address of the ERC4626-compatible yield vault
    function addYieldVault(address vault) external onlyOwner {
        if (vault == address(0)) revert ZeroAddress();
        if (s_isYieldVault[vault]) revert YieldVaultAlreadyAdded();

        s_yieldVaults.push(vault);
        s_isYieldVault[vault] = true;
        s_isWhitelistedTarget[vault] = true;

        emit YieldVaultAdded(vault);
    }

    /// @notice Remove a yield vault from the whitelist (owner only)
    /// @param vault Address of the yield vault to remove
    function removeYieldVault(address vault) external onlyOwner {
        if (!s_isYieldVault[vault]) revert YieldVaultNotFound();

        s_isYieldVault[vault] = false;
        s_isWhitelistedTarget[vault] = false;

        // Swap-and-pop from array
        uint256 len = s_yieldVaults.length;
        for (uint256 i = 0; i < len; i++) {
            if (s_yieldVaults[i] == vault) {
                s_yieldVaults[i] = s_yieldVaults[len - 1];
                s_yieldVaults.pop();
                break;
            }
        }

        emit YieldVaultRemoved(vault);
    }

    /// @notice Set or unset a whitelisted target for execute actions (owner only)
    /// @param target Target contract address
    /// @param allowed Whether the target is allowed
    function setWhitelistedTarget(address target, bool allowed) external onlyOwner {
        if (target == address(0)) revert ZeroAddress();
        s_isWhitelistedTarget[target] = allowed;
        emit WhitelistedTargetSet(target, allowed);
    }


    // ══════════════════════════════════════════════════════════════
    //                        PAUSABLE
    // ══════════════════════════════════════════════════════════════

    /// @notice Pause critical autonomous protocol actions for incident containment
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause critical autonomous protocol actions after incident resolution
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Recover accidentally sent native MON to a specified address
    /// @dev Owner-only. Use for stranded native funds (e.g. misdirected swaps).
    /// @param to Recipient address
    /// @param amount Amount to recover (wei)
    function recoverNative(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) return;
        if (address(this).balance < amount) revert NativeTransferFailed();

        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert NativeTransferFailed();

        emit NativeRecovered(to, amount);
    }

    // ══════════════════════════════════════════════════════════════
    //                       EXECUTION
    // ══════════════════════════════════════════════════════════════

    /// @notice Execute the winning proposal's strategy via a sequence of actions
    /// @dev CEO (rank #1) can execute immediately after voting. Rank #2 can execute
    ///      after the grace period. If no rank #2 exists, execution becomes
    ///      permissionless after the CEO grace period. Two-phase: all actions
    ///      validated before any execution.
    ///      Post-execution drawdown invariant prevents catastrophic vault drain.
    /// @param proposalId The index of the winning proposal for the current epoch
    /// @param actions Array of Action structs to execute
    function execute(uint256 proposalId, Action[] calldata actions) external whenNotPaused afterVoting nonReentrant {
        if (s_epochExecuted) revert AlreadyExecuted();
        if (actions.length == 0 || actions.length > s_maxActions) revert TooManyActions();

        // Access control: CEO or #2 after grace; permissionless if no #2
        address ceo = getTopAgent();
        if (msg.sender != ceo) {
            if (block.timestamp < s_epochStartTime + s_epochDuration + s_ceoGracePeriod) {
                revert GracePeriodOnlyCeo();
            }
            address second = getSecondAgent();
            if (second != address(0) && msg.sender != second) revert OnlyCeoOrSecond();
            // Penalize CEO for missing execution window
            if (ceo != address(0)) {
                s_agents[ceo].score += SCORE_CEO_MISSED;
            }
        }

        // Validate winning proposal
        uint256 numProposals = s_epochProposals[s_currentEpoch].length;
        if (numProposals == 0) revert NoProposals();
        if (proposalId >= numProposals) revert InvalidProposal();

        (uint256 bestId,) = getWinningProposal(s_currentEpoch);
        if (proposalId != bestId) revert NotWinningProposal();

        Proposal storage p = s_epochProposals[s_currentEpoch][proposalId];
        if (p.executed) revert AlreadyExecuted();
        if (keccak256(abi.encode(actions)) != p.proposalHash) revert ActionsMismatch();

        // PHASE 1: Validate ALL actions before executing ANY
        for (uint256 i = 0; i < actions.length; i++) {
            if (!_validateAction(actions[i])) revert ActionNotAllowed();
        }

        // Snapshot vault value before execution (for drawdown check)
        uint256 totalBefore = totalAssets();

        // Effects
        p.executed = true;
        s_epochExecuted = true;
        s_agents[p.proposer].score += SCORE_PROPOSAL_WON;

        // PHASE 2: Execute all validated actions
        for (uint256 i = 0; i < actions.length; i++) {
            (bool ok,) = actions[i].target.call(actions[i].data);
            if (!ok) revert ActionFailed();
        }

        // Revoke token approvals set during execution to avoid persistent allowances
        _revokeTokenApprovals(actions);

        // POST-EXECUTION: Drawdown invariant — vault value must not drop beyond limit
        if (s_maxDrawdownBps > 0 && totalBefore > 0) {
            uint256 totalAfter = totalAssets();
            uint256 minAllowed = totalBefore * (10_000 - s_maxDrawdownBps) / 10_000;
            if (totalAfter < minAllowed) revert ExcessiveDrawdown();
        }

        emit Executed(s_currentEpoch, proposalId, msg.sender);
    }

    /// @notice Convert accumulated performance fee USDC to $CEO and distribute to top agents
    /// @dev CEO provides swap actions (e.g., USDC → MON via DEX, then MON → $CEO via nad.fun).
    ///      All actions are validated before execution. A spending cap ensures no more
    ///      idle USDC is consumed than the pending performance fee amount.
    /// @param actions Swap actions to convert USDC → $CEO
    /// @param minCeoOut Minimum $CEO expected (slippage protection)
    function convertPerformanceFee(Action[] calldata actions, uint256 minCeoOut) external whenNotPaused nonReentrant {
        if (s_pendingPerformanceFeeUsdc == 0) revert NoPerformanceFeeToConvert();
        if (actions.length == 0 || actions.length > s_maxActions) revert TooManyActions();

        // Access control: CEO or #2 after grace
        address ceo = getTopAgent();
        if (msg.sender != ceo) {
            address second = getSecondAgent();
            if (msg.sender != second) revert OnlyCeoOrSecond();
        }

        uint256 feeAmount = s_pendingPerformanceFeeUsdc;

        // Ensure vault has idle USDC (pull from yield vaults if needed)
        _ensureLiquidity(feeAmount);

        // PHASE 1: Validate ALL actions before executing ANY
        for (uint256 i = 0; i < actions.length; i++) {
            if (!_validateAction(actions[i])) revert ActionNotAllowed();
        }

        // Snapshot balances before execution
        uint256 usdcBefore = IERC20(asset()).balanceOf(address(this));
        uint256 ceoBefore = i_ceoToken.balanceOf(address(this));

        // PHASE 2: Execute all validated actions
        for (uint256 i = 0; i < actions.length; i++) {
            (bool ok,) = actions[i].target.call(actions[i].data);
            if (!ok) revert ActionFailed();
        }

        // Revoke token approvals set during execution to avoid persistent allowances
        _revokeTokenApprovals(actions);

        // SPENDING CAP: vault must not have lost more idle USDC than the fee
        uint256 usdcAfter = IERC20(asset()).balanceOf(address(this));
        if (usdcBefore > usdcAfter && (usdcBefore - usdcAfter) > feeAmount) {
            revert ExcessiveSpending();
        }

        uint256 ceoAcquired = i_ceoToken.balanceOf(address(this)) - ceoBefore;
        if (ceoAcquired < minCeoOut) revert SlippageExceeded();

        // Distribute $CEO to top 10 agents
        _distributeFees(ceoAcquired);

        // Clear pending fee
        s_pendingPerformanceFeeUsdc = 0;

        emit PerformanceFeeConverted(ceoAcquired, msg.sender);
    }

    // ══════════════════════════════════════════════════════════════
    //                    AGENT REGISTRY
    // ══════════════════════════════════════════════════════════════

    /// @notice Register as an agent by staking $CEO and linking an ERC-8004 identity
    /// @param metadataURI Agent's metadata URI (capabilities, endpoints)
    /// @param ceoAmount Amount of $CEO to stake (must be >= minCeoStake)
    /// @param erc8004Id ERC-8004 identity NFT ID (required, must be owned by caller)
    function registerAgent(string calldata metadataURI, uint256 ceoAmount, uint256 erc8004Id) external nonReentrant {
        if (s_agents[msg.sender].active) revert AlreadyRegistered();
        if (ceoAmount < s_minCeoStake) revert InsufficientCeoStake();
        if (s_agentList.length >= s_maxAgents) revert MaxAgentsReached();

        // ERC-8004 identity is required
        if (address(s_erc8004Identity) == address(0)) revert IdentityRegistryNotConfigured();
        if (erc8004Id == 0) revert NoERC8004IdentityLinked();
        if (s_erc8004Identity.ownerOf(erc8004Id) != msg.sender) revert NotOwnerOfERC8004Identity();

        // Transfer $CEO stake
        i_ceoToken.safeTransferFrom(msg.sender, address(this), ceoAmount);

        // Register
        s_agents[msg.sender] = Agent({
            active: true,
            ceoStaked: ceoAmount,
            score: 0,
            erc8004Id: erc8004Id,
            metadataURI: metadataURI,
            registeredAt: block.timestamp
        });

        s_agentList.push(msg.sender);
        _s_agentIndex[msg.sender] = s_agentList.length; // 1-based

        emit AgentRegistered(msg.sender, ceoAmount, metadataURI);
        emit ERC8004IdentityLinked(msg.sender, erc8004Id);
    }

    /// @notice Deregister as an agent and reclaim staked $CEO
    /// @dev Agent must not have unclaimed fees (withdraw first)
    function deregisterAgent() external nonReentrant {
        Agent storage agent = s_agents[msg.sender];
        if (!agent.active) revert NotActiveAgent();

        uint256 staked = agent.ceoStaked;
        agent.active = false;
        agent.ceoStaked = 0;

        // Swap-and-pop from agentList
        uint256 idx = _s_agentIndex[msg.sender] - 1; // convert to 0-based
        uint256 lastIdx = s_agentList.length - 1;
        if (idx != lastIdx) {
            address lastAgent = s_agentList[lastIdx];
            s_agentList[idx] = lastAgent;
            _s_agentIndex[lastAgent] = idx + 1;
        }
        s_agentList.pop();
        _s_agentIndex[msg.sender] = 0;

        // Return staked $CEO
        if (staked > 0) {
            i_ceoToken.safeTransfer(msg.sender, staked);
        }

        emit AgentDeregistered(msg.sender, staked);
    }

    // ══════════════════════════════════════════════════════════════
    //                      GOVERNANCE
    // ══════════════════════════════════════════════════════════════

    /// @notice Submit a strategy proposal for the current epoch
    /// @dev Each agent may propose at most once per epoch. Max 10 proposals per epoch.
    ///      All actions are validated at proposal time (fail fast). Actions are also
    ///      re-validated at execute() time to handle whitelist changes between proposal and execution.
    /// @param actions Array of actions to execute when proposal wins (committed on-chain)
    /// @param proposalURI Off-chain URI with proposal details
    function registerProposal(Action[] calldata actions, string calldata proposalURI)
        external
        whenNotPaused
        onlyActiveAgent
        duringVoting
        nonReentrant
    {
        if (actions.length == 0 || actions.length > s_maxActions) revert TooManyActions();
        if (s_hasProposed[s_currentEpoch][msg.sender]) revert AlreadyProposed();
        if (s_epochProposals[s_currentEpoch].length >= MAX_PROPOSALS_PER_EPOCH) revert MaxProposalsReached();

        // Validate all actions at proposal time (fail fast)
        for (uint256 i = 0; i < actions.length; i++) {
            if (!_validateAction(actions[i])) revert ActionNotAllowed();
        }

        bytes32 proposalHash = keccak256(abi.encode(actions));

        s_hasProposed[s_currentEpoch][msg.sender] = true;

        uint256 proposalId = s_epochProposals[s_currentEpoch].length;
        s_epochProposals[s_currentEpoch].push(
            Proposal({
                proposalHash: proposalHash,
                proposalURI: proposalURI,
                proposer: msg.sender,
                votesFor: 0,
                votesAgainst: 0,
                epoch: s_currentEpoch,
                executed: false,
                settled: false
            })
        );

        s_agents[msg.sender].score += SCORE_PROPOSAL_SUBMITTED;

        emit ProposalRegistered(s_currentEpoch, proposalId, proposalHash, msg.sender);
    }

    /// @notice Vote on a proposal during the voting period
    /// @dev Weight is based on agent's absolute score (min 1)
    /// @param proposalId Index of the proposal in the current epoch
    /// @param support True = for, false = against
    function vote(uint256 proposalId, bool support) external whenNotPaused onlyActiveAgent duringVoting {
        uint256 epoch = s_currentEpoch;
        if (proposalId >= s_epochProposals[epoch].length) revert InvalidProposal();
        if (s_hasVoted[epoch][proposalId][msg.sender]) revert AlreadyVoted();

        Proposal storage p = s_epochProposals[epoch][proposalId];
        int256 rawScore = s_agents[msg.sender].score;
        uint256 weight = rawScore > 0 ? uint256(rawScore) : 1;

        s_hasVoted[epoch][proposalId][msg.sender] = true;
        s_voteSupport[epoch][proposalId][msg.sender] = support;

        if (support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }

        s_agents[msg.sender].score += SCORE_VOTED;

        emit Voted(epoch, proposalId, msg.sender, support, weight);
    }

    // ══════════════════════════════════════════════════════════════
    //                   EPOCH SETTLEMENT
    // ══════════════════════════════════════════════════════════════

    /// @notice Settle the current epoch: measure performance, distribute fees, advance epoch
    /// @dev Can be called by anyone after the grace period. Measures vault profit,
    ///      accrues performance fee, updates agent scores, and starts the next epoch.
    function settleEpoch() external whenNotPaused afterVoting nonReentrant {
        uint256 epoch = s_currentEpoch;
        uint256 graceEnd = s_epochStartTime + s_epochDuration + s_ceoGracePeriod;
        if (block.timestamp < graceEnd) revert TooEarlyToSettle();

        // ── Measure profitability ──
        // adjustedCurrent = totalAssets() + withdrawals (USDC that left)
        // adjustedStart   = startAssets  + deposits (USDC that entered)
        // revenue         = adjustedCurrent - adjustedStart
        uint256 currentTotal = totalAssets() + s_pendingPerformanceFeeUsdc; // gross total (re-add pending fees for accurate calc)
        uint256 adjustedCurrent = currentTotal + s_epochWithdrawals[epoch];
        uint256 adjustedStart = s_epochStartAssets[epoch] + s_epochDeposits[epoch];

        bool profitable;
        int256 revenue;
        uint256 absRevenue;

        if (adjustedCurrent >= adjustedStart) {
            absRevenue = adjustedCurrent - adjustedStart;
            revenue = int256(absRevenue);
            profitable = absRevenue > 0;
        } else {
            absRevenue = adjustedStart - adjustedCurrent;
            revenue = -int256(absRevenue);
            profitable = false;
        }

        // ── Accrue performance fee ──
        if (profitable && absRevenue > 0 && s_performanceFeeBps > 0) {
            uint256 perfFee = absRevenue.mulDiv(s_performanceFeeBps, 10_000, Math.Rounding.Floor);
            s_pendingPerformanceFeeUsdc += perfFee;
            emit PerformanceFeeAccrued(epoch, perfFee);
        }

        // ── Update scores ──
        uint256 numProposals = s_epochProposals[epoch].length;
        if (numProposals > 0 && s_epochExecuted) {
            (uint256 winnerId,) = getWinningProposal(epoch);
            Proposal storage winner = s_epochProposals[epoch][winnerId];
            winner.settled = true;

            // Score proposer
            if (profitable) {
                s_agents[winner.proposer].score += SCORE_PROPOSAL_PROFITABLE;
            } else {
                s_agents[winner.proposer].score += SCORE_PROPOSAL_UNPROFITABLE;
            }

            // Reward voters who voted on the winning side
            _rewardVoters(epoch, winnerId);

            // Post ERC-8004 reputation if configured
            _postEpochReputation(epoch, winner.proposer, profitable);
        }

        // ── Advance epoch ──
        uint256 nextEpoch = epoch + 1;
        s_currentEpoch = nextEpoch;
        s_epochStartTime = block.timestamp;
        s_epochExecuted = false;
        s_epochStartAssets[nextEpoch] = totalAssets();

        emit EpochSettled(epoch, profitable, revenue);
    }

    // ══════════════════════════════════════════════════════════════
    //                  AGENT FEE MANAGEMENT
    // ══════════════════════════════════════════════════════════════

    /// @notice Get the amount of $CEO an agent can claim
    /// @param agent Address of the agent
    /// @return Amount of $CEO claimable
    function getClaimableFees(address agent) external view returns (uint256) {
        return s_claimableFees[agent];
    }

    /// @notice Withdraw accumulated $CEO fees
    function withdrawFees() external nonReentrant {
        uint256 amount = s_claimableFees[msg.sender];
        if (amount == 0) revert NoFeesToWithdraw();

        s_claimableFees[msg.sender] = 0;
        i_ceoToken.safeTransfer(msg.sender, amount);

        emit FeesWithdrawn(msg.sender, amount);
    }

    // ══════════════════════════════════════════════════════════════
    //                     ADMIN / CONFIG
    // ══════════════════════════════════════════════════════════════

    /// @notice Transfer ownership — step 1: propose new owner
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        s_pendingOwner = newOwner;
    }

    /// @notice Transfer ownership — step 2: new owner accepts
    function acceptOwnership() external {
        if (msg.sender != s_pendingOwner) revert NotPendingOwner();
        s_owner = msg.sender;
        s_pendingOwner = address(0);
    }

    /// @notice Set treasury address (entry fee recipient)
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        s_treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /// @notice Set entry fee (basis points)
    function setEntryFeeBps(uint256 bps) external onlyOwner {
        if (bps > MAX_FEE_BPS) revert InvalidFeePercentage();
        s_entryFeeBps = bps;
    }

    /// @notice Set performance fee (basis points)
    function setPerformanceFeeBps(uint256 bps) external onlyOwner {
        if (bps > MAX_FEE_BPS) revert InvalidFeePercentage();
        s_performanceFeeBps = bps;
    }

    /// @notice Set minimum $CEO stake for agent registration
    function setMinCeoStake(uint256 amount) external onlyOwner {
        s_minCeoStake = amount;
    }

    /// @notice Set total vault cap (0 = no cap)
    function setVaultCap(uint256 cap) external onlyOwner {
        if (cap > 0 && totalAssets() > cap) revert VaultCapBelowCurrent();
        s_vaultCap = cap;
    }

    /// @notice Set max deposit per address (0 = no cap)
    function setMaxDepositPerAddress(uint256 cap) external onlyOwner {
        s_maxDepositPerAddress = cap;
    }

    /// @notice Set minimum deposit/mint amount in asset decimals (0 = no minimum)
    function setMinDeposit(uint256 amount) external onlyOwner {
        s_minDeposit = amount;
        emit MinDepositSet(amount);
    }

    /// @notice Set minimum withdraw/redeem amount in asset decimals (0 = no minimum)
    function setMinWithdraw(uint256 amount) external onlyOwner {
        s_minWithdraw = amount;
        emit MinWithdrawSet(amount);
    }

    /// @notice Set epoch duration (seconds)
    function setEpochDuration(uint256 duration) external onlyOwner {
        s_epochDuration = duration;
    }

    /// @notice Set CEO grace period (seconds)
    function setCeoGracePeriod(uint256 period) external onlyOwner {
        s_ceoGracePeriod = period;
    }

    /// @notice Set maximum number of agents
    function setMaxAgents(uint256 max) external onlyOwner {
        if (max < s_agentList.length) revert BelowCurrentCount();
        s_maxAgents = max;
    }

    /// @notice Set maximum actions per execute call
    function setMaxActions(uint256 max) external onlyOwner {
        s_maxActions = max;
    }

    /// @notice Set maximum drawdown in basis points per execute call (0 = no limit)
    /// @dev Backstop: execute() reverts if vault value drops more than this percentage.
    ///      E.g. 3000 = 30% max drop allowed. Set to 0 to disable.
    function setMaxDrawdownBps(uint256 bps) external onlyOwner {
        if (bps > 10_000) revert InvalidFeePercentage();
        s_maxDrawdownBps = bps;
        emit MaxDrawdownBpsSet(bps);
    }

    /// @notice Configure ERC-8004 registries for agent identity, reputation, and validation
    function setERC8004Registries(
        address identity,
        address reputation,
        address validation
    ) external onlyOwner {
        s_erc8004Identity = IERC8004Identity(identity);
        s_erc8004Reputation = IERC8004Reputation(reputation);
        s_erc8004Validation = IERC8004Validation(validation);
        emit ERC8004RegistriesUpdated(identity, reputation, validation);
    }

    // ══════════════════════════════════════════════════════════════
    //                     VIEW HELPERS
    // ══════════════════════════════════════════════════════════════

    /// @notice Get the current CEO (top-scoring active agent)
    /// @return Top agent address (address(0) if none)
    function getTopAgent() public view returns (address) {
        (address topAddr,) = AgentRankingLib.getTopTwoAgents(s_agentList, s_agents);
        return topAddr;
    }

    /// @notice Get the second-place agent (fallback executor)
    /// @return Second agent address (address(0) if none)
    function getSecondAgent() public view returns (address) {
        (, address secondAddr) = AgentRankingLib.getTopTwoAgents(s_agentList, s_agents);
        return secondAddr;
    }

    /// @notice Get the winning proposal for an epoch
    /// @param epoch Epoch number
    /// @return bestId Index of the winning proposal
    /// @return bestNet Net votes (votesFor - votesAgainst) of the winner
    function getWinningProposal(uint256 epoch) public view returns (uint256 bestId, int256 bestNet) {
        uint256 numProposals = s_epochProposals[epoch].length;
        if (numProposals == 0) revert NoProposals();

        bestNet = type(int256).min;
        for (uint256 i = 0; i < numProposals; i++) {
            Proposal storage p = s_epochProposals[epoch][i];
            int256 net = int256(p.votesFor) - int256(p.votesAgainst);
            if (net > bestNet) {
                bestNet = net;
                bestId = i;
            }
        }
    }

    /// @notice Get the sorted leaderboard of active agents
    /// @return agents Sorted array of agent addresses (descending by score)
    /// @return scores Corresponding scores
    function getLeaderboard() external view returns (address[] memory agents, int256[] memory scores) {
        return AgentRankingLib.getLeaderboard(s_agentList, s_agents);
    }

    /// @notice Get the number of proposals in an epoch
    function getProposalCount(uint256 epoch) external view returns (uint256) {
        return s_epochProposals[epoch].length;
    }

    /// @notice Get a specific proposal
    function getProposal(uint256 epoch, uint256 proposalId) external view returns (Proposal memory) {
        return s_epochProposals[epoch][proposalId];
    }

    /// @notice Get the list of yield vaults
    function getYieldVaults() external view returns (address[] memory) {
        return s_yieldVaults;
    }

    /// @notice Get the list of registered agents
    function getAgentList() external view returns (address[] memory) {
        return s_agentList;
    }

    /// @notice Get agent info including ERC-8004 data
    function getAgentInfo(address agent)
        external
        view
        returns (
            bool active,
            uint256 ceoStaked,
            int256 score,
            uint256 erc8004Id,
            string memory metadataURI,
            uint256 registeredAt
        )
    {
        Agent storage a = s_agents[agent];
        return (a.active, a.ceoStaked, a.score, a.erc8004Id, a.metadataURI, a.registeredAt);
    }

    /// @notice Check if voting is currently open
    function isVotingOpen() external view returns (bool) {
        return block.timestamp < s_epochStartTime + s_epochDuration;
    }

    /// @notice Get the deployed value across all yield vaults
    function getDeployedValue() external view returns (uint256) {
        return _deployedValue();
    }

    // ══════════════════════════════════════════════════════════════
    //                  ERC-8004 INTEGRATION
    // ══════════════════════════════════════════════════════════════

    /// @notice Request validation of a rebalance from an ERC-8004 validator
    /// @param validatorAddress The validator contract
    /// @param epoch The epoch to validate
    /// @param requestURI Off-chain data for validation
    /// @param requestHash Commitment hash
    function requestRebalanceValidation(
        address validatorAddress,
        uint256 epoch,
        string calldata requestURI,
        bytes32 requestHash
    ) external onlyActiveAgent {
        if (address(s_erc8004Validation) == address(0)) revert ValidationRegistryNotConfigured();
        if (s_epochProposals[epoch].length == 0) revert NoProposals();
        if (!s_epochProposals[epoch][0].executed) {
            // Check that at least one proposal was executed
            bool anyExecuted;
            uint256 len = s_epochProposals[epoch].length;
            for (uint256 i = 0; i < len; i++) {
                if (s_epochProposals[epoch][i].executed) {
                    anyExecuted = true;
                    break;
                }
            }
            if (!anyExecuted) revert NoExecutionForEpoch();
        }

        uint256 agentId = s_agents[msg.sender].erc8004Id;
        if (agentId == 0) revert NoERC8004IdentityLinked();

        s_erc8004Validation.validationRequest(validatorAddress, agentId, requestURI, requestHash);
    }

    // ══════════════════════════════════════════════════════════════
    //                   INTERNAL HELPERS
    // ══════════════════════════════════════════════════════════════

    /// @dev Calculate the total value deployed in yield vaults by querying each vault
    function _deployedValue() internal view returns (uint256 value) {
        uint256 len = s_yieldVaults.length;
        for (uint256 i = 0; i < len; i++) {
            address vault = s_yieldVaults[i];
            uint256 shares = IERC20(vault).balanceOf(address(this));
            if (shares > 0) {
                try IERC4626(vault).convertToAssets(shares) returns (uint256 assets) {
                    value += assets;
                } catch {
                    // If vault reverts, skip (conservative: value treated as 0)
                }
            }
        }
    }

    /// @dev Pull USDC from yield vaults if idle balance is insufficient
    function _ensureLiquidity(uint256 amount) internal {
        IERC20 usdc = IERC20(asset());
        uint256 idle = usdc.balanceOf(address(this));
        if (idle >= amount) return;

        uint256 deficit = amount - idle;
        uint256 len = s_yieldVaults.length;

        for (uint256 i = 0; i < len && deficit > 0; i++) {
            address vault = s_yieldVaults[i];
            uint256 shares = IERC20(vault).balanceOf(address(this));
            if (shares == 0) continue;

            // Use try/catch so a reverting yield vault doesn't block all withdrawals
            try IERC4626(vault).previewRedeem(shares) returns (uint256 maxAssets) {
                uint256 toWithdraw = deficit > maxAssets ? maxAssets : deficit;
                if (toWithdraw > 0) {
                    try IERC4626(vault).withdraw(toWithdraw, address(this), address(this)) {
                        uint256 newIdle = usdc.balanceOf(address(this));
                        uint256 pulled = newIdle - idle;
                        deficit = pulled >= deficit ? 0 : deficit - pulled;
                        idle = newIdle;
                    } catch {
                        // Vault withdrawal failed — skip and try next vault
                    }
                }
            } catch {
                // Vault preview failed — skip and try next vault
            }
        }

        if (usdc.balanceOf(address(this)) < amount) revert InsufficientLiquidity();
    }

    /// @dev Validate a single action's target, selector, and critical parameters.
    ///      Rules:
    ///        1. Native MON transfers (value > 0) are forbidden.
    ///        2. Token contracts (USDC, $CEO): only approve() to a whitelisted spender.
    ///        3. Yield vaults: only ERC4626 deposit/mint/withdraw/redeem with receiver/owner = this.
    ///        4. Other whitelisted targets (adapters): any calldata allowed.
    function _validateAction(Action calldata action) internal view returns (bool) {
        address target = action.target;
        bytes calldata data = action.data;

        // ── Rule 1: No native MON transfers ──
        if (action.value > 0) return false;

        // ── Rule 2: Token contracts — approve only, spender must be whitelisted ──
        if (target == asset() || target == address(i_ceoToken)) {
            if (data.length < 68) return false; // approve(address,uint256) = 4 + 32 + 32
            bytes4 selector = bytes4(data[:4]);
            if (selector != IERC20.approve.selector) return false;
            address spender = abi.decode(data[4:68], (address));
            return s_isWhitelistedTarget[spender];
        }

        // ── Rule 3: Yield vaults — ERC4626 ops only, receiver/owner must be this ──
        if (s_isYieldVault[target]) {
            if (data.length < 4) return false;
            bytes4 selector = bytes4(data[:4]);

            // deposit(uint256 assets, address receiver)
            // mint(uint256 shares, address receiver)
            if (selector == IERC4626.deposit.selector || selector == IERC4626.mint.selector) {
                if (data.length < 68) return false;
                address receiver = abi.decode(data[36:68], (address));
                return receiver == address(this);
            }

            // withdraw(uint256 assets, address receiver, address owner)
            // redeem(uint256 shares, address receiver, address owner)
            if (selector == IERC4626.withdraw.selector || selector == IERC4626.redeem.selector) {
                if (data.length < 100) return false;
                address receiver = abi.decode(data[36:68], (address));
                address owner_ = abi.decode(data[68:100], (address));
                return receiver == address(this) && owner_ == address(this);
            }

            // Any other selector on a yield vault: rejected
            return false;
        }

        // ── Rule 4: Other whitelisted targets (adapters) — allowed ──
        return s_isWhitelistedTarget[target];
    }

    /// @dev Revoke approvals created by token approve() actions in this execution batch.
    function _revokeTokenApprovals(Action[] calldata actions) internal {
        for (uint256 i = 0; i < actions.length; i++) {
            Action calldata action = actions[i];
            if (action.target != asset() && action.target != address(i_ceoToken)) continue;

            bytes calldata data = action.data;
            if (data.length < 68) continue;
            if (bytes4(data[:4]) != IERC20.approve.selector) continue;

            address spender = abi.decode(data[4:68], (address));
            IERC20(action.target).forceApprove(spender, 0);
        }
    }

    /// @dev Distribute $CEO fees to the top 10 agents (CEO: 30%, ranks 2-10: 70% split)
    function _distributeFees(uint256 totalCeo) internal {
        if (totalCeo == 0) return;

        // Get sorted leaderboard (top 10)
        address[10] memory topAgents;
        int256[10] memory topScores;
        uint256 topCount;

        uint256 len = s_agentList.length;
        for (uint256 i = 0; i < len; i++) {
            address a = s_agentList[i];
            if (!s_agents[a].active) continue;
            int256 sc = s_agents[a].score;

            if (topCount < 10) {
                // Insert into array
                topAgents[topCount] = a;
                topScores[topCount] = sc;
                topCount++;
                // Bubble up
                uint256 j = topCount - 1;
                while (j > 0 && topScores[j] > topScores[j - 1]) {
                    // Swap
                    (topScores[j], topScores[j - 1]) = (topScores[j - 1], topScores[j]);
                    (topAgents[j], topAgents[j - 1]) = (topAgents[j - 1], topAgents[j]);
                    j--;
                }
            } else if (sc > topScores[9]) {
                // Replace last and re-sort
                topAgents[9] = a;
                topScores[9] = sc;
                uint256 j = 9;
                while (j > 0 && topScores[j] > topScores[j - 1]) {
                    (topScores[j], topScores[j - 1]) = (topScores[j - 1], topScores[j]);
                    (topAgents[j], topAgents[j - 1]) = (topAgents[j - 1], topAgents[j]);
                    j--;
                }
            }
        }

        if (topCount == 0) return;

        if (topCount == 1) {
            // Only one agent — gets everything
            s_claimableFees[topAgents[0]] += totalCeo;
            emit FeesAccrued(topAgents[0], totalCeo);
            return;
        }

        // CEO (rank #1) gets 30%
        uint256 ceoShare = totalCeo.mulDiv(30, 100, Math.Rounding.Floor);
        s_claimableFees[topAgents[0]] += ceoShare;
        emit FeesAccrued(topAgents[0], ceoShare);

        // Remaining 70% split equally among ranks #2-#topCount
        uint256 remaining = totalCeo - ceoShare;
        uint256 othersCount = topCount - 1;
        uint256 perAgent = remaining / othersCount;
        uint256 dust = remaining - (perAgent * othersCount);

        for (uint256 i = 1; i < topCount; i++) {
            uint256 share = perAgent;
            if (i == 1) share += dust; // give dust to #2
            s_claimableFees[topAgents[i]] += share;
            emit FeesAccrued(topAgents[i], share);
        }
    }

    /// @dev Reward agents who voted on the winning side of the winning proposal
    function _rewardVoters(uint256 epoch, uint256 winnerId) internal {
        Proposal storage winner = s_epochProposals[epoch][winnerId];
        bool winningSupport = winner.votesFor >= winner.votesAgainst;

        uint256 len = s_agentList.length;
        for (uint256 i = 0; i < len; i++) {
            address a = s_agentList[i];
            if (!s_hasVoted[epoch][winnerId][a]) continue;
            if (s_voteSupport[epoch][winnerId][a] == winningSupport) {
                s_agents[a].score += SCORE_VOTED_WINNING_SIDE;
            }
        }
    }

    /// @dev Post reputation updates to ERC-8004 if configured
    function _postEpochReputation(uint256 epoch, address proposer, bool profitable) internal {
        if (address(s_erc8004Reputation) == address(0)) return;

        uint256 agentId = s_agents[proposer].erc8004Id;
        if (agentId == 0) return;

        int128 scoreDelta = profitable ? int128(SCORE_PROPOSAL_PROFITABLE) : int128(SCORE_PROPOSAL_UNPROFITABLE);

        try s_erc8004Reputation.giveFeedback(
            agentId,
            scoreDelta,
            0, // valueDecimals
            "ceoPerformance",
            _uint2str(epoch),
            "", // endpoint
            "", // feedbackURI
            bytes32(0) // feedbackHash
        ) {
            emit ERC8004ReputationPosted(epoch, proposer, scoreDelta);
        } catch {
            // Non-critical: don't revert if reputation posting fails
        }
    }

    /// @dev Convert uint to string for ERC-8004 tags
    function _uint2str(uint256 value) internal pure returns (string memory) {
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
