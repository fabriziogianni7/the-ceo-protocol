// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {CEOToken} from "../src/CEOToken.sol";
import {CEOVaultV2} from "../src/CEOVaultV2.sol";
import {ICEOVaultV2} from "../src/ICEOVaultV2.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockYieldVault} from "./mocks/MockYieldVault.sol";
import {MockERC8004Identity} from "./mocks/MockERC8004Identity.sol";
import {MockERC8004Reputation} from "./mocks/MockERC8004Reputation.sol";
import {MockValueAdapter} from "./mocks/MockValueAdapter.sol";
import {MockFeeDex} from "./mocks/MockFeeDex.sol";
import {MockLending} from "./mocks/MockLending.sol";
import {MockLendingValueAdapter} from "./mocks/MockLendingValueAdapter.sol";

/// @title CEOVaultV2Test — Comprehensive tests for CEOVaultV2
contract CEOVaultV2Test is Test {
    CEOToken public ceoToken;
    MockUSDC public usdc;
    MockYieldVault public yieldVault;
    CEOVaultV2 public vault;
    MockERC8004Identity public erc8004Identity;
    MockERC8004Reputation public erc8004Reputation;

    address public deployer = address(this);
    address public treasury = makeAddr("treasury");
    address public depositor1 = makeAddr("depositor1");
    address public depositor2 = makeAddr("depositor2");
    address public agent1 = makeAddr("agent1");
    address public agent2 = makeAddr("agent2");
    address public agent3 = makeAddr("agent3");

    uint256 public constant CEO_SUPPLY = 1_000_000e18;
    uint256 public constant MIN_CEO_STAKE = 100e18;
    uint256 public constant EPOCH_DURATION = 1 days;
    uint256 public constant ENTRY_FEE_BPS = 100;
    uint256 public constant MAX_AGENTS = 1000;
    uint256 public constant MAX_ACTIONS = 20;

    uint256 public agent1Id;
    uint256 public agent2Id;
    uint256 public agent3Id;

    function setUp() public {
        vm.label(address(this), "Test");
        vm.label(treasury, "treasury");
        vm.label(depositor1, "depositor1");
        vm.label(depositor2, "depositor2");
        vm.label(agent1, "agent1");
        vm.label(agent2, "agent2");
        vm.label(agent3, "agent3");

        ceoToken = new CEOToken(CEO_SUPPLY);
        usdc = new MockUSDC();
        erc8004Identity = new MockERC8004Identity();
        erc8004Reputation = new MockERC8004Reputation(address(erc8004Identity));

        vm.label(address(ceoToken), "CEOToken");
        vm.label(address(usdc), "USDC");
        vm.label(address(erc8004Identity), "ERC8004Identity");
        vm.label(address(erc8004Reputation), "ERC8004Reputation");

        vault = new CEOVaultV2(
            IERC20(address(usdc)),
            IERC20(address(ceoToken)),
            treasury,
            ENTRY_FEE_BPS,
            MIN_CEO_STAKE,
            0,
            0,
            EPOCH_DURATION,
            MAX_AGENTS,
            MAX_ACTIONS
        );

        vm.label(address(vault), "CEOVaultV2");

        vault.setERC8004Registries(address(erc8004Identity), address(erc8004Reputation), address(0));

        yieldVault = new MockYieldVault(IERC20(address(usdc)));
        vault.addYieldVault(address(yieldVault));
        vm.label(address(yieldVault), "MockYieldVault");

        ceoToken.transfer(agent1, 1000e18);
        ceoToken.transfer(agent2, 1000e18);
        ceoToken.transfer(agent3, 1000e18);

        vm.prank(agent1);
        ceoToken.approve(address(vault), type(uint256).max);
        vm.prank(agent2);
        ceoToken.approve(address(vault), type(uint256).max);
        vm.prank(agent3);
        ceoToken.approve(address(vault), type(uint256).max);

        usdc.mint(depositor1, 100_000e6);
        usdc.mint(depositor2, 100_000e6);
        vm.prank(depositor1);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(depositor2);
        usdc.approve(address(vault), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════
    //                    DEPOSIT / REDEEM TESTS
    // ══════════════════════════════════════════════════════════════

    function test_deposit() public {
        vm.prank(depositor1);
        uint256 shares = vault.deposit(1000e6, depositor1);

        assertGt(shares, 0, "Should receive shares");
        assertEq(vault.balanceOf(depositor1), shares);
        assertApproxEqAbs(vault.totalAssets(), 990e6, 1e6); // 1% fee
        assertApproxEqAbs(usdc.balanceOf(treasury), 10e6, 1e6);
    }

    function test_deposit_multipleDepositors() public {
        vm.prank(depositor1);
        vault.deposit(1000e6, depositor1);
        vm.prank(depositor2);
        vault.deposit(2000e6, depositor2);

        uint256 shares1 = vault.balanceOf(depositor1);
        uint256 shares2 = vault.balanceOf(depositor2);
        assertApproxEqRel(shares2, shares1 * 2, 0.01e18);
    }

    function test_redeem() public {
        vm.prank(depositor1);
        uint256 shares = vault.deposit(1000e6, depositor1);

        uint256 usdcBefore = usdc.balanceOf(depositor1);
        vm.prank(depositor1);
        uint256 assets = vault.redeem(shares, depositor1, depositor1);

        assertGt(assets, 0);
        assertEq(usdc.balanceOf(depositor1), usdcBefore + assets);
        assertEq(vault.balanceOf(depositor1), 0);
    }

    function test_deposit_revert_vaultCapReached() public {
        CEOVaultV2 cappedVault = new CEOVaultV2(
            IERC20(address(usdc)),
            IERC20(address(ceoToken)),
            treasury,
            ENTRY_FEE_BPS,
            MIN_CEO_STAKE,
            1_000e6,
            100e6,
            EPOCH_DURATION,
            MAX_AGENTS,
            MAX_ACTIONS
        );
        cappedVault.setERC8004Registries(address(erc8004Identity), address(erc8004Reputation), address(0));
        cappedVault.addYieldVault(address(yieldVault));

        usdc.mint(address(this), 2_000e6);
        for (uint256 i = 0; i < 12; i++) {
            address filler = makeAddr(string(abi.encodePacked("filler", i)));
            usdc.transfer(filler, 100e6);
            vm.prank(filler);
            usdc.approve(address(cappedVault), type(uint256).max);
            uint256 max = cappedVault.maxDeposit(filler);
            if (max == 0) break;
            vm.prank(filler);
            cappedVault.deposit(max, filler);
        }

        address depositor3 = makeAddr("depositor3");
        usdc.transfer(depositor3, 100e6);
        vm.prank(depositor3);
        usdc.approve(address(cappedVault), type(uint256).max);
        vm.prank(depositor3);
        vm.expectRevert();
        cappedVault.deposit(100e6, depositor3);
    }

    function test_deposit_revert_maxDepositPerAddressExceeded() public {
        CEOVaultV2 cappedVault = new CEOVaultV2(
            IERC20(address(usdc)),
            IERC20(address(ceoToken)),
            treasury,
            ENTRY_FEE_BPS,
            MIN_CEO_STAKE,
            0,
            100e6,
            EPOCH_DURATION,
            MAX_AGENTS,
            MAX_ACTIONS
        );
        cappedVault.setERC8004Registries(address(erc8004Identity), address(erc8004Reputation), address(0));
        cappedVault.addYieldVault(address(yieldVault));

        vm.prank(depositor1);
        usdc.approve(address(cappedVault), type(uint256).max);
        vm.prank(depositor1);
        cappedVault.deposit(100e6, depositor1);

        uint256 max = cappedVault.maxDeposit(depositor1);
        assertLt(max, 50e6);
        vm.prank(depositor1);
        vm.expectRevert();
        cappedVault.deposit(50e6, depositor1);
    }

    function test_setVaultCap() public {
        assertEq(vault.s_vaultCap(), 0);
        vault.setVaultCap(1_000e6);
        assertEq(vault.s_vaultCap(), 1_000e6);
    }

    function test_setVaultCap_revert_belowCurrent() public {
        vm.prank(depositor1);
        vault.deposit(5_000e6, depositor1);
        vm.expectRevert(ICEOVaultV2.VaultCapBelowCurrent.selector);
        vault.setVaultCap(1_000e6);
    }

    function test_setMinDeposit_setMinWithdraw() public {
        assertEq(vault.s_minDeposit(), 0);
        assertEq(vault.s_minWithdraw(), 0);
        vault.setMinDeposit(100e6);
        vault.setMinWithdraw(50e6);
        assertEq(vault.s_minDeposit(), 100e6);
        assertEq(vault.s_minWithdraw(), 50e6);
    }

    function test_deposit_revert_belowMinDeposit() public {
        vault.setMinDeposit(100e6);
        vm.prank(depositor1);
        vm.expectRevert(ICEOVaultV2.BelowMinDeposit.selector);
        vault.deposit(50e6, depositor1);
    }

    function test_redeem_revert_belowMinWithdraw() public {
        vm.prank(depositor1);
        vault.deposit(1000e6, depositor1);
        vault.setMinWithdraw(100e6);
        uint256 shares = vault.balanceOf(depositor1);
        vm.prank(depositor1);
        vm.expectRevert(ICEOVaultV2.BelowMinWithdraw.selector);
        vault.redeem(shares / 20, depositor1, depositor1);
    }

    function test_deposit_entryFee_goesToTreasury() public {
        uint256 treasuryBefore = usdc.balanceOf(treasury);
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);
        uint256 fee = usdc.balanceOf(treasury) - treasuryBefore;
        assertApproxEqAbs(fee, 100e6, 1e6);
    }

    function test_deposit_entryFee_distributedToTop10Agents() public {
        vault.setEntryFeeRecipient(address(vault));

        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        _depositAndPropose(_defaultActions());
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        (address[] memory agents,) = vault.getLeaderboard();
        vm.prank(agents[0]);
        vault.execute(0, _defaultActions());
        // execute chains settle internally

        vm.prank(depositor2);
        vault.deposit(5_000e6, depositor2);

        uint256 totalClaimable;
        totalClaimable += vault.getClaimableFees(agent1);
        totalClaimable += vault.getClaimableFees(agent2);
        totalClaimable += vault.getClaimableFees(agent3);
        assertGt(totalClaimable, 0, "Agents should have claimable fees");
    }

    // ══════════════════════════════════════════════════════════════
    //                   AGENT REGISTRATION TESTS
    // ══════════════════════════════════════════════════════════════

    function test_registerAgent_autoRegisterWhenErc8004IdZero() public {
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1-meta", MIN_CEO_STAKE, 0);

        (bool active, uint256 staked, int256 score, uint256 erc8004Id,,) = vault.getAgentInfo(agent1);
        assertTrue(active);
        assertEq(staked, MIN_CEO_STAKE);
        assertEq(score, 0);
        assertGt(erc8004Id, 0);
        assertEq(erc8004Identity.ownerOf(erc8004Id), agent1);
        assertEq(erc8004Identity.tokenURI(erc8004Id), "ipfs://agent1-meta");
    }

    function test_registerAgent_existingIdentityWhenErc8004IdNonZero() public {
        vm.prank(agent1);
        agent1Id = erc8004Identity.register("ipfs://agent1-identity");
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1-meta", MIN_CEO_STAKE, agent1Id);

        (bool active,,, uint256 linkedId,,) = vault.getAgentInfo(agent1);
        assertTrue(active);
        assertEq(linkedId, agent1Id);
    }

    function test_registerAgent_revert_autoRegisterWhenRegistryNotConfigured() public {
        vault.setERC8004Registries(address(0), address(erc8004Reputation), address(0));
        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.IdentityRegistryNotConfigured.selector);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, 0);
    }

    function test_registerAgent_revert_notOwnerWhenErc8004IdNonZero() public {
        vm.prank(agent1);
        agent1Id = erc8004Identity.register("ipfs://agent1-identity");
        vm.prank(agent2);
        vm.expectRevert(ICEOVaultV2.NotOwnerOfERC8004Identity.selector);
        vault.registerAgent("ipfs://agent2", MIN_CEO_STAKE, agent1Id);
    }

    function test_registerAgent_revert_insufficientStake() public {
        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.InsufficientCeoStake.selector);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE - 1, 0);
    }

    function test_registerAgent_revert_alreadyRegistered() public {
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, 0);
        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.AlreadyRegistered.selector);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, 0);
    }

    function test_registerAgent_revert_maxAgents() public {
        vault.setMaxAgents(1);
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, 0);
        vm.prank(agent2);
        vm.expectRevert(ICEOVaultV2.MaxAgentsReached.selector);
        vault.registerAgent("ipfs://agent2", MIN_CEO_STAKE, 0);
    }

    function test_deregisterAgent() public {
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, 0);

        uint256 ceoBefore = ceoToken.balanceOf(agent1);
        vm.prank(agent1);
        vault.deregisterAgent();

        (bool active,,,,,) = vault.getAgentInfo(agent1);
        assertFalse(active);
        assertEq(ceoToken.balanceOf(agent1), ceoBefore + MIN_CEO_STAKE);
    }

    // ══════════════════════════════════════════════════════════════
    //                    LEADERBOARD TESTS
    // ══════════════════════════════════════════════════════════════

    function test_getLeaderboard() public {
        _registerAllAgents();
        (address[] memory addrs, int256[] memory scores) = vault.getLeaderboard();
        assertEq(addrs.length, 3);
        assertEq(scores.length, 3);
    }

    // ══════════════════════════════════════════════════════════════
    //                     PROPOSAL TESTS
    // ══════════════════════════════════════════════════════════════

    function test_registerProposal() public {
        _registerAllAgents();

        ICEOVaultV2.Action[] memory actions = _defaultActions();
        vm.prank(agent1);
        vault.registerProposal(actions, "https://moltiverse.xyz/proposals/1");

        assertEq(vault.getProposalCount(1), 1);
        (,, int256 score,,,) = vault.getAgentInfo(agent1);
        assertEq(score, vault.SCORE_PROPOSAL_SUBMITTED());
    }

    function test_registerProposal_revert_notAgent() public {
        ICEOVaultV2.Action[] memory actions = _defaultActions();
        vm.prank(depositor1);
        vm.expectRevert(ICEOVaultV2.NotActiveAgent.selector);
        vault.registerProposal(actions, "uri");
    }

    function test_registerProposal_revert_afterVoting() public {
        _registerAllAgents();
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        ICEOVaultV2.Action[] memory actions = _defaultActions();
        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.VotingPeriodEnded.selector);
        vault.registerProposal(actions, "uri");
    }

    function test_registerProposal_revert_alreadyProposed() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());

        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.AlreadyProposed.selector);
        vault.registerProposal(_defaultActions(), "uri2");
    }

    function test_registerProposal_revert_maxProposalsReached() public {
        _registerAllAgents();
        address[7] memory extras = [
            makeAddr("a4"), makeAddr("a5"), makeAddr("a6"), makeAddr("a7"),
            makeAddr("a8"), makeAddr("a9"), makeAddr("a10")
        ];
        for (uint256 i = 0; i < 7; i++) {
            vm.prank(extras[i]);
            uint256 id = erc8004Identity.register("ipfs://agent");
            ceoToken.transfer(extras[i], 1000e18);
            vm.prank(extras[i]);
            ceoToken.approve(address(vault), type(uint256).max);
            vm.prank(extras[i]);
            vault.registerAgent("ipfs://agent", MIN_CEO_STAKE, id);
        }
        for (uint256 i = 0; i < 10; i++) {
            address a = i < 3 ? (i == 0 ? agent1 : (i == 1 ? agent2 : agent3)) : extras[i - 3];
            vm.prank(a);
            vault.registerProposal(_defaultActions(), "uri");
        }
        assertEq(vault.getProposalCount(1), 10);

        address agent11 = makeAddr("agent11");
        vm.prank(agent11);
        uint256 id11 = erc8004Identity.register("ipfs://agent11");
        ceoToken.transfer(agent11, 1000e18);
        vm.prank(agent11);
        ceoToken.approve(address(vault), type(uint256).max);
        vm.prank(agent11);
        vault.registerAgent("ipfs://agent11", MIN_CEO_STAKE, id11);

        vm.prank(agent11);
        vm.expectRevert(ICEOVaultV2.MaxProposalsReached.selector);
        vault.registerProposal(_defaultActions(), "uri11");
    }

    function test_registerProposal_revert_targetNotWhitelisted() public {
        _registerAllAgents();
        address random = makeAddr("random");
        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({target: random, value: 0, data: ""});

        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.ActionNotAllowed.selector);
        vault.registerProposal(actions, "https://moltiverse.xyz/proposals/1");
    }

    function test_registerProposal_revert_selectorNotAllowed() public {
        _registerAllAgents();
        address dexTarget = makeAddr("dexTarget");
        vault.setWhitelistedTarget(dexTarget, true);
        // Do NOT add any allowed selector

        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({
            target: dexTarget,
            value: 0,
            data: abi.encodeWithSelector(bytes4(keccak256("swap(uint256)")), 100e6)
        });

        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.ActionNotAllowed.selector);
        vault.registerProposal(actions, "https://moltiverse.xyz/proposals/1");
    }

    // ══════════════════════════════════════════════════════════════
    //                      VOTING TESTS
    // ══════════════════════════════════════════════════════════════

    function test_vote() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());

        vm.prank(agent2);
        vault.vote(0, true);

        ICEOVaultV2.Proposal memory p = vault.getProposal(1, 0);
        assertGt(p.votesFor, 0);
    }

    function test_vote_revert_doubleVote() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());

        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent2);
        vm.expectRevert(ICEOVaultV2.AlreadyVoted.selector);
        vault.vote(0, true);
    }

    function test_vote_against() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());

        vm.prank(agent2);
        vault.vote(0, false);

        ICEOVaultV2.Proposal memory p = vault.getProposal(1, 0);
        assertGt(p.votesAgainst, 0);
    }

    function test_getWinningProposal() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());
        _submitProposal(agent2, _defaultActions());

        vm.prank(agent3);
        vault.vote(0, true);

        (uint256 bestId,) = vault.getWinningProposal(1);
        assertEq(bestId, 0);
    }

    function test_isVotingOpen() public {
        assertTrue(vault.isVotingOpen());
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        assertFalse(vault.isVotingOpen());
    }

    // ══════════════════════════════════════════════════════════════
    //                    EXECUTION TESTS
    // ══════════════════════════════════════════════════════════════

    function test_execute_permissionless_anyoneCanExecuteAfterVoting() public {
        _registerAllAgents();
        ICEOVaultV2.Action[] memory actions = _defaultActions();
        _depositAndPropose(actions);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vm.prank(depositor1);
        vault.execute(0, actions);

        ICEOVaultV2.Proposal memory p = vault.getProposal(1, 0);
        assertTrue(p.executed);
    }

    function test_execute_revokesTokenApproveAllowanceAfterExecution() public {
        _registerAllAgents();

        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, address(yieldVault), 1_000e6)
        });

        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        (address[] memory agents,) = vault.getLeaderboard();
        vm.prank(agents[0]);
        vault.execute(0, actions);

        assertEq(usdc.allowance(address(vault), address(yieldVault)), 0);
    }

    function test_execute_revert_actionsMismatch() public {
        _registerAllAgents();
        ICEOVaultV2.Action[] memory registeredActions = _deployActions(500e6);
        _depositAndPropose(registeredActions);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        ICEOVaultV2.Action[] memory wrongActions = _deployActions(1000e6);

        vm.prank(depositor1);
        vm.expectRevert(ICEOVaultV2.ActionsMismatch.selector);
        vault.execute(0, wrongActions);
    }

    function test_execute_revert_votingStillOpen() public {
        _registerAllAgents();
        _depositAndPropose(_defaultActions());

        vm.prank(depositor1);
        vm.expectRevert(ICEOVaultV2.VotingStillOpen.selector);
        vault.execute(0, _defaultActions());
    }

    function test_execute_revert_alreadyExecuted() public {
        _registerAllAgents();
        _depositAndPropose(_defaultActions());
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vm.prank(depositor1);
        vault.execute(0, _defaultActions());
        // execute chains settle; epoch advanced to 2. Second execute fails because
        // epoch 2 voting is still open (same block) -> VotingStillOpen
        vm.prank(depositor2);
        vm.expectRevert(ICEOVaultV2.VotingStillOpen.selector);
        vault.execute(0, _defaultActions());
    }

    function test_execute_revert_notWinningProposal() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());
        _submitProposal(agent2, _defaultActions());
        vm.prank(agent3);
        vault.vote(1, true);

        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vm.prank(depositor1);
        vm.expectRevert(ICEOVaultV2.NotWinningProposal.selector);
        vault.execute(0, _defaultActions());
    }

    // ══════════════════════════════════════════════════════════════
    //                  YIELD VAULT TESTS
    // ══════════════════════════════════════════════════════════════

    function test_addYieldVault() public {
        MockYieldVault newVault = new MockYieldVault(IERC20(address(usdc)));
        vault.addYieldVault(address(newVault));

        address[] memory vaults = vault.getYieldVaults();
        assertEq(vaults.length, 2);
        assertTrue(vault.s_isYieldVault(address(newVault)));
    }

    function test_addYieldVault_revert_duplicate() public {
        vm.expectRevert(ICEOVaultV2.YieldVaultAlreadyAdded.selector);
        vault.addYieldVault(address(yieldVault));
    }

    function test_removeYieldVault() public {
        vault.removeYieldVault(address(yieldVault));
        assertFalse(vault.s_isYieldVault(address(yieldVault)));
        address[] memory vaults = vault.getYieldVaults();
        assertEq(vaults.length, 0);
    }

    function test_totalAssets_includesDeployedValue() public {
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        _registerAllAgents();
        ICEOVaultV2.Action[] memory actions = _deployActions(5000e6);
        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        (address[] memory agents,) = vault.getLeaderboard();
        vm.prank(agents[0]);
        vault.execute(0, actions);

        assertGt(vault.getDeployedValue(), 0, "Deployed value should include yield vault");
        assertGt(vault.totalAssets(), 0, "Total assets should include idle + deployed");
    }

    function test_onDemandPull_fromYieldVault() public {
        vm.prank(depositor1);
        uint256 shares = vault.deposit(10_000e6, depositor1);

        uint256 deployAmount = 8000e6;
        vm.startPrank(address(vault));
        usdc.approve(address(yieldVault), deployAmount);
        yieldVault.deposit(deployAmount, address(vault));
        vm.stopPrank();

        uint256 usdcBefore = usdc.balanceOf(depositor1);
        vm.prank(depositor1);
        vault.redeem(shares, depositor1, depositor1);

        assertGt(usdc.balanceOf(depositor1) - usdcBefore, 0);
    }

    // ══════════════════════════════════════════════════════════════
    //                 EPOCH SETTLEMENT TESTS
    // ══════════════════════════════════════════════════════════════

    function test_settleEpoch_profitable() public {
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        _registerAllAgents();
        ICEOVaultV2.Action[] memory actions = _deployActions(5000e6);
        _depositAndPropose(actions);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        (address[] memory agents,) = vault.getLeaderboard();
        vm.prank(agents[0]);
        vault.execute(0, actions);
        // execute chains settle internally
        usdc.mint(address(yieldVault), 500e6);

        assertEq(vault.s_currentEpoch(), 2);
    }

    function test_settleEpoch_revert_whenExecuteChainedSettle() public {
        _registerAllAgents();
        _depositAndPropose(_defaultActions());
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        (address[] memory agents,) = vault.getLeaderboard();
        vm.prank(agents[0]);
        vault.execute(0, _defaultActions());
        // execute chains settle; epoch advanced to 2. settleEpoch would try to settle epoch 2
        // but epoch 2 voting is still open -> VotingStillOpen
        vm.expectRevert(ICEOVaultV2.VotingStillOpen.selector);
        vault.settleEpoch();
    }

    function test_settleEpoch_advancesEpoch() public {
        _registerAllAgents();
        _depositAndPropose(_defaultActions());

        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        (address[] memory agents,) = vault.getLeaderboard();
        vm.prank(agents[0]);
        vault.execute(0, _defaultActions());
        // execute chains settle internally
        assertEq(vault.s_currentEpoch(), 2);
    }

    function test_settleEpoch_noExecution_advancesEpoch() public {
        _registerAllAgents();
        _depositAndPropose(_defaultActions());
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        // No one executes; anyone can settle to advance epoch
        vault.settleEpoch();
        assertEq(vault.s_currentEpoch(), 2);
    }

    // ══════════════════════════════════════════════════════════════
    //                 FEE WITHDRAWAL TESTS
    // ══════════════════════════════════════════════════════════════

    function test_withdrawFees() public {
        vault.setEntryFeeRecipient(address(vault));
        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        uint256 claimable = vault.getClaimableFees(agent1);
        if (claimable > 0) {
            uint256 usdcBefore = usdc.balanceOf(agent1);
            vm.prank(agent1);
            vault.withdrawFees();
            assertEq(usdc.balanceOf(agent1), usdcBefore + claimable);
        }
    }

    function test_withdrawFees_revert_noFeesToWithdraw() public {
        _registerAllAgents();
        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.NoFeesToWithdraw.selector);
        vault.withdrawFees();
    }

    // ══════════════════════════════════════════════════════════════
    //                     ADMIN TESTS
    // ══════════════════════════════════════════════════════════════

    function test_setTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        vault.setTreasury(newTreasury);
        assertEq(vault.s_treasury(), newTreasury);
    }

    function test_setTreasury_revert_notOwner() public {
        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.NotOwner.selector);
        vault.setTreasury(makeAddr("newTreasury"));
    }

    function test_setEntryFeeBps() public {
        vault.setEntryFeeBps(200);
        assertEq(vault.s_entryFeeBps(), 200);
    }

    function test_setEntryFeeBps_revert_tooHigh() public {
        vm.expectRevert(ICEOVaultV2.InvalidFeePercentage.selector);
        vault.setEntryFeeBps(3000);
    }

    function test_transferOwnership() public {
        vault.transferOwnership(agent1);
        assertEq(vault.s_owner(), deployer);
        assertEq(vault.s_pendingOwner(), agent1);

        vm.prank(agent2);
        vm.expectRevert(ICEOVaultV2.NotPendingOwner.selector);
        vault.acceptOwnership();

        vm.prank(agent1);
        vault.acceptOwnership();
        assertEq(vault.s_owner(), agent1);
        assertEq(vault.s_pendingOwner(), address(0));
    }

    function test_setWhitelistedTarget() public {
        address target = makeAddr("dexRouter");
        vault.setWhitelistedTarget(target, true);
        assertTrue(vault.s_isWhitelistedTarget(target));

        vault.setWhitelistedTarget(target, false);
        assertFalse(vault.s_isWhitelistedTarget(target));
    }

    function test_addValueAdapter() public {
        MockValueAdapter adapter = new MockValueAdapter();
        vault.addValueAdapter(address(adapter));

        address[] memory adapters = vault.getValueAdapters();
        assertEq(adapters.length, 1);
        assertEq(adapters[0], address(adapter));
    }

    function test_addValueAdapter_revert_duplicate() public {
        MockValueAdapter adapter = new MockValueAdapter();
        vault.addValueAdapter(address(adapter));
        vm.expectRevert(ICEOVaultV2.ValueAdapterAlreadyAdded.selector);
        vault.addValueAdapter(address(adapter));
    }

    function test_removeValueAdapter() public {
        MockValueAdapter adapter = new MockValueAdapter();
        vault.addValueAdapter(address(adapter));
        vault.removeValueAdapter(address(adapter));

        address[] memory adapters = vault.getValueAdapters();
        assertEq(adapters.length, 0);
    }

    function test_addAllowedSelector() public {
        address target = makeAddr("target");
        vault.setWhitelistedTarget(target, true);
        vault.addAllowedSelector(target, bytes4(keccak256("foo()")));

        bytes4[] memory selectors = vault.getAllowedSelectors(target);
        assertEq(selectors.length, 1);
    }

    function test_addApprovableToken() public {
        address token = makeAddr("token");
        vault.addApprovableToken(token);
        assertTrue(vault.s_isApprovableToken(token));
    }

    function test_pause_unpause() public {
        vault.pause();
        assertTrue(vault.paused());

        vault.unpause();
        assertFalse(vault.paused());
    }

    function test_pause_revert_notOwner() public {
        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.NotOwner.selector);
        vault.pause();
    }

    function test_recoverNative() public {
        vm.deal(address(vault), 2 ether);
        address recipient = makeAddr("recipient");
        uint256 balanceBefore = recipient.balance;

        vault.recoverNative(recipient, 1 ether);

        assertEq(recipient.balance, balanceBefore + 1 ether);
        assertEq(address(vault).balance, 1 ether);
    }

    function test_recoverNative_revert_notOwner() public {
        vm.deal(address(vault), 1 ether);
        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.NotOwner.selector);
        vault.recoverNative(makeAddr("recipient"), 1 ether);
    }

    function test_recoverNative_revert_zeroAddress() public {
        vm.deal(address(vault), 1 ether);
        vm.expectRevert(ICEOVaultV2.ZeroAddress.selector);
        vault.recoverNative(address(0), 1 ether);
    }

    function test_recoverNative_revert_insufficientBalance() public {
        vm.deal(address(vault), 1 ether);
        vm.expectRevert(ICEOVaultV2.NativeTransferFailed.selector);
        vault.recoverNative(makeAddr("recipient"), 2 ether);
    }

    // ══════════════════════════════════════════════════════════════
    //                   PAUSE INTEGRATION TESTS
    // ══════════════════════════════════════════════════════════════

    function test_registerProposal_revert_paused() public {
        _registerAllAgents();
        ICEOVaultV2.Action[] memory actions = _defaultActions();

        vault.pause();
        vm.prank(agent1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.registerProposal(actions, "https://moltiverse.xyz/proposals/paused");
    }

    function test_vote_revert_paused() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());

        vault.pause();
        vm.prank(agent2);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.vote(0, true);
    }

    function test_execute_revert_paused() public {
        _registerAllAgents();
        _depositAndPropose(_defaultActions());
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vault.pause();
        (address[] memory agents,) = vault.getLeaderboard();
        vm.prank(agents[0]);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.execute(0, _defaultActions());
    }

    function test_settleEpoch_revert_paused() public {
        vault.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.settleEpoch();
    }

    // ══════════════════════════════════════════════════════════════
    //                 VALIDATE / SIMULATE ACTIONS
    // ══════════════════════════════════════════════════════════════

    function test_validateActions_valid() public view {
        ICEOVaultV2.Action[] memory actions = _defaultActions();
        assertTrue(vault.validateActions(actions));
    }

    function test_validateActions_invalidTarget() public {
        address random = makeAddr("random");
        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({target: random, value: 0, data: ""});
        assertFalse(vault.validateActions(actions));
    }

    function test_simulateActions_success() public {
        ICEOVaultV2.Action[] memory actions = _defaultActions();
        vm.expectRevert(
            abi.encodeWithSelector(ICEOVaultV2.SimulationComplete.selector, true, uint256(0), bytes(""))
        );
        vault.simulateActions(actions);
    }

    function test_simulateActions_revert_invalidAction() public {
        address random = makeAddr("random");
        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({target: random, value: 0, data: ""});

        vm.expectRevert();
        vault.simulateActions(actions);
    }

    // ══════════════════════════════════════════════════════════════
    //                  FULL LIFECYCLE TEST
    // ══════════════════════════════════════════════════════════════

    function test_fullLifecycle() public {
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);
        vm.prank(depositor2);
        vault.deposit(5_000e6, depositor2);

        _registerAllAgents();

        ICEOVaultV2.Action[] memory winningActions = _deployActions(10_000e6);
        _submitProposal(agent1, winningActions);
        _submitProposal(agent2, _deployActions(5000e6));

        vm.prank(agent1);
        vault.vote(0, true);
        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent3);
        vault.vote(0, true);

        (uint256 bestId,) = vault.getWinningProposal(1);
        assertEq(bestId, 0);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        (address[] memory agents,) = vault.getLeaderboard();
        vm.prank(agents[0]);
        vault.execute(0, winningActions);

        ICEOVaultV2.Proposal memory p = vault.getProposal(1, 0);
        assertTrue(p.executed);

        usdc.mint(address(yieldVault), 300e6);
        // execute chains settle internally

        assertEq(vault.s_currentEpoch(), 2);

        uint256 shares1 = vault.balanceOf(depositor1);
        vm.prank(depositor1);
        uint256 redeemed = vault.redeem(shares1, depositor1, depositor1);
        assertGt(redeemed, 0);
    }

    // ══════════════════════════════════════════════════════════════
    //               ERC-8004 INTEGRATION TESTS
    // ══════════════════════════════════════════════════════════════

    function test_setERC8004Registries() public {
        assertEq(address(vault.s_erc8004Identity()), address(erc8004Identity));
        assertEq(address(vault.s_erc8004Reputation()), address(erc8004Reputation));
    }

    function test_setERC8004Registries_revert_notOwner() public {
        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.NotOwner.selector);
        vault.setERC8004Registries(address(1), address(2), address(3));
    }

    function test_epochSettlement_postsReputation() public {
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        _registerAllAgents();
        _depositAndPropose(_defaultActions());

        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        (address[] memory agents,) = vault.getLeaderboard();
        vm.prank(agents[0]);
        vault.execute(0, _defaultActions());
        // execute chains settle internally

        assertEq(erc8004Reputation.totalFeedbackCount(), 1);
    }

    // ══════════════════════════════════════════════════════════════
    //                       HELPERS
    // ══════════════════════════════════════════════════════════════

    function _registerAllAgents() internal {
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, 0);
        vm.prank(agent2);
        vault.registerAgent("ipfs://agent2", MIN_CEO_STAKE, 0);
        vm.prank(agent3);
        vault.registerAgent("ipfs://agent3", MIN_CEO_STAKE, 0);
    }

    function _defaultActions() internal view returns (ICEOVaultV2.Action[] memory) {
        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, address(yieldVault), 0)
        });
        return actions;
    }

    function _deployActions(uint256 amount) internal view returns (ICEOVaultV2.Action[] memory) {
        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](2);
        actions[0] = ICEOVaultV2.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, address(yieldVault), amount)
        });
        actions[1] = ICEOVaultV2.Action({
            target: address(yieldVault),
            value: 0,
            data: abi.encodeWithSelector(IERC4626.deposit.selector, amount, address(vault))
        });
        return actions;
    }

    function _submitProposal(address agent, ICEOVaultV2.Action[] memory actions) internal {
        vm.prank(agent);
        vault.registerProposal(actions, "https://moltiverse.xyz/proposals/1");
    }

    function _depositAndPropose(ICEOVaultV2.Action[] memory actions) internal {
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        _submitProposal(agent1, actions);
        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent3);
        vault.vote(0, true);
    }
}
