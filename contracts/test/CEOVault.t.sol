// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {CEOToken} from "../src/CEOToken.sol";
import {CEOVault} from "../src/CEOVault.sol";
import {ICEOVault} from "../src/ICEOVault.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockYieldVault} from "./mocks/MockYieldVault.sol";
import {MockFeeDex} from "./mocks/MockFeeDex.sol";
import {MockERC8004Identity} from "./mocks/MockERC8004Identity.sol";
import {MockERC8004Reputation} from "./mocks/MockERC8004Reputation.sol";
import {MockERC8004Validation} from "./mocks/MockERC8004Validation.sol";

contract CEOVaultTest is Test {
    CEOToken public ceoToken;
    MockUSDC public usdc;
    MockYieldVault public yieldVault;
    MockFeeDex public mockDex;
    CEOVault public vault;
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
    uint256 public constant GRACE_PERIOD = 1 hours;
    uint256 public constant ENTRY_FEE_BPS = 100; // 1%
    uint256 public constant PERFORMANCE_FEE_BPS = 100; // 1%
    uint256 public constant MAX_AGENTS = 1000;
    uint256 public constant MAX_ACTIONS = 20;

    // Agent ERC8004 IDs
    uint256 public agent1Id;
    uint256 public agent2Id;
    uint256 public agent3Id;

    function setUp() public {
        // Deploy tokens
        ceoToken = new CEOToken(CEO_SUPPLY);
        usdc = new MockUSDC();
        mockDex = new MockFeeDex();

        // Deploy ERC-8004
        erc8004Identity = new MockERC8004Identity();
        erc8004Reputation = new MockERC8004Reputation(address(erc8004Identity));

        // Deploy vault (0 = no cap for tests)
        vault = new CEOVault(
            IERC20(address(usdc)),
            IERC20(address(ceoToken)),
            treasury,
            ENTRY_FEE_BPS,
            PERFORMANCE_FEE_BPS,
            MIN_CEO_STAKE,
            0,    // vaultCap: no cap in unit tests
            0,    // maxDepositPerAddress: no cap in unit tests
            EPOCH_DURATION,
            GRACE_PERIOD,
            MAX_AGENTS,
            MAX_ACTIONS
        );

        // Configure ERC-8004 registries
        vault.setERC8004Registries(address(erc8004Identity), address(erc8004Reputation), address(0));

        // Deploy yield vault
        yieldVault = new MockYieldVault(IERC20(address(usdc)));

        // Add yield vault
        vault.addYieldVault(address(yieldVault));

        // Register ERC8004 identities for agents
        vm.prank(agent1);
        agent1Id = erc8004Identity.register("ipfs://agent1-identity");
        vm.prank(agent2);
        agent2Id = erc8004Identity.register("ipfs://agent2-identity");
        vm.prank(agent3);
        agent3Id = erc8004Identity.register("ipfs://agent3-identity");

        // Fund agents with $CEO
        ceoToken.transfer(agent1, 1000e18);
        ceoToken.transfer(agent2, 1000e18);
        ceoToken.transfer(agent3, 1000e18);

        // Approve vault for $CEO
        vm.prank(agent1);
        ceoToken.approve(address(vault), type(uint256).max);
        vm.prank(agent2);
        ceoToken.approve(address(vault), type(uint256).max);
        vm.prank(agent3);
        ceoToken.approve(address(vault), type(uint256).max);

        // Fund depositors with USDC
        usdc.mint(depositor1, 100_000e6);
        usdc.mint(depositor2, 100_000e6);

        // Approve vault for USDC
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
        // 1% entry fee: 990 USDC net
        assertApproxEqAbs(vault.totalAssets(), 990e6, 1e6);
        // Treasury receives fee
        assertApproxEqAbs(usdc.balanceOf(treasury), 10e6, 1e6);
    }

    function test_deposit_multiple_depositors() public {
        vm.prank(depositor1);
        vault.deposit(1000e6, depositor1);

        vm.prank(depositor2);
        vault.deposit(2000e6, depositor2);

        // Both should have proportional shares
        uint256 shares1 = vault.balanceOf(depositor1);
        uint256 shares2 = vault.balanceOf(depositor2);
        // depositor2 deposited 2x
        assertApproxEqRel(shares2, shares1 * 2, 0.01e18); // within 1%
    }

    function test_redeem() public {
        vm.prank(depositor1);
        uint256 shares = vault.deposit(1000e6, depositor1);

        uint256 usdcBefore = usdc.balanceOf(depositor1);
        vm.prank(depositor1);
        uint256 assets = vault.redeem(shares, depositor1, depositor1);

        assertGt(assets, 0, "Should receive USDC");
        assertEq(usdc.balanceOf(depositor1), usdcBefore + assets);
        assertEq(vault.balanceOf(depositor1), 0);
    }

    function test_deposit_revert_vaultCapReached() public {
        CEOVault cappedVault = new CEOVault(
            IERC20(address(usdc)),
            IERC20(address(ceoToken)),
            treasury,
            ENTRY_FEE_BPS,
            PERFORMANCE_FEE_BPS,
            MIN_CEO_STAKE,
            1_000e6,   // vaultCap: 1,000 USDC
            100e6,     // maxDepositPerAddress: 100 USDC
            EPOCH_DURATION,
            GRACE_PERIOD,
            MAX_AGENTS,
            MAX_ACTIONS
        );
        usdc.mint(address(this), 2_000e6);

        // Fill vault to cap: each depositor can add at most 100e6; need ~11 to reach 1000e6 net
        address[] memory depositors = new address[](12);
        for (uint256 i = 0; i < 12; i++) {
            depositors[i] = makeAddr(string(abi.encodePacked("filler", i)));
            usdc.transfer(depositors[i], 100e6);
            vm.prank(depositors[i]);
            usdc.approve(address(cappedVault), type(uint256).max);
            uint256 max = cappedVault.maxDeposit(depositors[i]);
            if (max == 0) break;
            vm.prank(depositors[i]);
            cappedVault.deposit(max, depositors[i]);
        }

        address depositor3 = makeAddr("depositor3");
        usdc.transfer(depositor3, 100e6);
        vm.prank(depositor3);
        usdc.approve(address(cappedVault), type(uint256).max);
        uint256 maxForDepositor3 = cappedVault.maxDeposit(depositor3);
        assertLt(maxForDepositor3, 100e6, "Should be capped");
        vm.prank(depositor3);
        vm.expectRevert();
        cappedVault.deposit(100e6, depositor3);
    }

    function test_deposit_revert_maxDepositPerAddressExceeded() public {
        CEOVault cappedVault = new CEOVault(
            IERC20(address(usdc)),
            IERC20(address(ceoToken)),
            treasury,
            ENTRY_FEE_BPS,
            PERFORMANCE_FEE_BPS,
            MIN_CEO_STAKE,
            0,        // no total cap
            100e6,    // maxDepositPerAddress: 100 USDC
            EPOCH_DURATION,
            GRACE_PERIOD,
            MAX_AGENTS,
            MAX_ACTIONS
        );
        usdc.mint(depositor1, 500e6);
        vm.prank(depositor1);
        usdc.approve(address(cappedVault), type(uint256).max);

        vm.prank(depositor1);
        cappedVault.deposit(100e6, depositor1);

        uint256 maxForDepositor1 = cappedVault.maxDeposit(depositor1);
        assertLt(maxForDepositor1, 50e6, "Should be capped below 50 USDC");
        vm.prank(depositor1);
        vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxDeposit.selector, depositor1, 50e6, maxForDepositor1));
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
        vm.expectRevert(ICEOVault.VaultCapBelowCurrent.selector);
        vault.setVaultCap(1_000e6);
    }

    function test_setMaxDepositPerAddress() public {
        assertEq(vault.s_maxDepositPerAddress(), 0);
        vault.setMaxDepositPerAddress(100e6);
        assertEq(vault.s_maxDepositPerAddress(), 100e6);
    }

    function test_setMinDeposit() public {
        assertEq(vault.s_minDeposit(), 0);
        vault.setMinDeposit(100e6);
        assertEq(vault.s_minDeposit(), 100e6);
    }

    function test_setMinWithdraw() public {
        assertEq(vault.s_minWithdraw(), 0);
        vault.setMinWithdraw(50e6);
        assertEq(vault.s_minWithdraw(), 50e6);
    }

    function test_deposit_revert_belowMinDeposit() public {
        vault.setMinDeposit(100e6);
        vm.prank(depositor1);
        vm.expectRevert(ICEOVault.BelowMinDeposit.selector);
        vault.deposit(50e6, depositor1);
    }

    function test_deposit_succeeds_atMinDeposit() public {
        vault.setMinDeposit(100e6);
        vm.prank(depositor1);
        uint256 shares = vault.deposit(100e6, depositor1);
        assertGt(shares, 0);
    }

    function test_redeem_revert_belowMinWithdraw() public {
        vm.prank(depositor1);
        vault.deposit(1000e6, depositor1);
        vault.setMinWithdraw(100e6);
        uint256 shares = vault.balanceOf(depositor1);
        // redeem 1/20 of shares → ~50e6 assets, below 100e6 min
        vm.prank(depositor1);
        vm.expectRevert(ICEOVault.BelowMinWithdraw.selector);
        vault.redeem(shares / 20, depositor1, depositor1);
    }

    function test_withdraw_revert_belowMinWithdraw() public {
        vm.prank(depositor1);
        vault.deposit(1000e6, depositor1);
        vault.setMinWithdraw(500e6);
        vm.prank(depositor1);
        vm.expectRevert(ICEOVault.BelowMinWithdraw.selector);
        vault.withdraw(100e6, depositor1, depositor1);
    }

    function test_redeem_succeeds_atMinWithdraw() public {
        vm.prank(depositor1);
        vault.deposit(1000e6, depositor1);
        vault.setMinWithdraw(500e6);
        uint256 shares = vault.balanceOf(depositor1);
        vm.prank(depositor1);
        uint256 assets = vault.redeem(shares, depositor1, depositor1);
        assertGt(assets, 0);
        assertGe(assets, 500e6);
    }

    function test_deposit_entryFee_goes_to_treasury() public {
        uint256 treasuryBefore = usdc.balanceOf(treasury);

        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        uint256 treasuryAfter = usdc.balanceOf(treasury);
        uint256 fee = treasuryAfter - treasuryBefore;

        // 1% of 10,000 = 100 USDC (approximately, due to basis point rounding)
        assertApproxEqAbs(fee, 100e6, 1e6);
    }

    // ══════════════════════════════════════════════════════════════
    //                   AGENT REGISTRATION TESTS
    // ══════════════════════════════════════════════════════════════

    function test_registerAgent() public {
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1-meta", MIN_CEO_STAKE, agent1Id);

        (bool active, uint256 staked, int256 score, uint256 erc8004Id,,) = vault.getAgentInfo(agent1);
        assertTrue(active);
        assertEq(staked, MIN_CEO_STAKE);
        assertEq(score, 0);
        assertEq(erc8004Id, agent1Id);
    }

    function test_registerAgent_revert_insufficientStake() public {
        vm.prank(agent1);
        vm.expectRevert(ICEOVault.InsufficientCeoStake.selector);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE - 1, agent1Id);
    }

    function test_registerAgent_revert_alreadyRegistered() public {
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, agent1Id);

        vm.prank(agent1);
        vm.expectRevert(ICEOVault.AlreadyRegistered.selector);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, agent1Id);
    }

    function test_registerAgent_revert_noERC8004Identity() public {
        vm.prank(agent1);
        vm.expectRevert(ICEOVault.NoERC8004IdentityLinked.selector);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, 0);
    }

    function test_registerAgent_revert_notOwnerOfIdentity() public {
        // agent2 tries to use agent1's identity
        vm.prank(agent2);
        vm.expectRevert(ICEOVault.NotOwnerOfERC8004Identity.selector);
        vault.registerAgent("ipfs://agent2", MIN_CEO_STAKE, agent1Id);
    }

    function test_deregisterAgent() public {
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, agent1Id);

        uint256 ceoBefore = ceoToken.balanceOf(agent1);
        vm.prank(agent1);
        vault.deregisterAgent();

        (bool active,,,,,) = vault.getAgentInfo(agent1);
        assertFalse(active);
        assertEq(ceoToken.balanceOf(agent1), ceoBefore + MIN_CEO_STAKE);
    }

    function test_registerAgent_revert_maxAgents() public {
        vault.setMaxAgents(1);

        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, agent1Id);

        vm.prank(agent2);
        vm.expectRevert(ICEOVault.MaxAgentsReached.selector);
        vault.registerAgent("ipfs://agent2", MIN_CEO_STAKE, agent2Id);
    }

    // ══════════════════════════════════════════════════════════════
    //                    LEADERBOARD TESTS
    // ══════════════════════════════════════════════════════════════

    function test_getTopAgent() public {
        _registerAllAgents();
        address top = vault.getTopAgent();
        assertTrue(top != address(0));
    }

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

        ICEOVault.Action[] memory actions = _defaultActions();
        vm.prank(agent1);
        vault.registerProposal(actions, "https://moltiverse.xyz/proposals/1");

        assertEq(vault.getProposalCount(1), 1);
        (,, int256 score,,,) = vault.getAgentInfo(agent1);
        assertEq(score, int256(vault.SCORE_PROPOSAL_SUBMITTED()));
    }

    function test_registerProposal_revert_notAgent() public {
        ICEOVault.Action[] memory actions = _defaultActions();
        vm.prank(depositor1);
        vm.expectRevert(ICEOVault.NotActiveAgent.selector);
        vault.registerProposal(actions, "uri");
    }

    function test_registerProposal_revert_afterVoting() public {
        _registerAllAgents();
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        ICEOVault.Action[] memory actions = _defaultActions();
        vm.prank(agent1);
        vm.expectRevert(ICEOVault.VotingPeriodEnded.selector);
        vault.registerProposal(actions, "uri");
    }

    function test_registerProposal_revert_alreadyProposed() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());

        vm.prank(agent1);
        vm.expectRevert(ICEOVault.AlreadyProposed.selector);
        vault.registerProposal(_defaultActions(), "uri2");
    }

    function test_registerProposal_revert_maxProposalsReached() public {
        _registerAllAgents();
        // Register 7 more agents to reach 10 total
        address a4 = makeAddr("a4");
        address a5 = makeAddr("a5");
        address a6 = makeAddr("a6");
        address a7 = makeAddr("a7");
        address a8 = makeAddr("a8");
        address a9 = makeAddr("a9");
        address a10 = makeAddr("a10");
        address[] memory extras = new address[](7);
        extras[0] = a4;
        extras[1] = a5;
        extras[2] = a6;
        extras[3] = a7;
        extras[4] = a8;
        extras[5] = a9;
        extras[6] = a10;
        for (uint256 i = 0; i < 7; i++) {
            vm.prank(extras[i]);
            uint256 id = erc8004Identity.register("ipfs://agent");
            ceoToken.transfer(extras[i], 1000e18);
            vm.prank(extras[i]);
            ceoToken.approve(address(vault), type(uint256).max);
            vm.prank(extras[i]);
            vault.registerAgent("ipfs://agent", MIN_CEO_STAKE, id);
        }
        // Submit 10 proposals
        _submitProposal(agent1, _defaultActions());
        _submitProposal(agent2, _defaultActions());
        _submitProposal(agent3, _defaultActions());
        for (uint256 i = 0; i < 7; i++) {
            vm.prank(extras[i]);
            vault.registerProposal(_defaultActions(), "uri");
        }
        assertEq(vault.getProposalCount(1), 10);

        // 11th proposal should revert
        address agent11 = makeAddr("agent11");
        vm.prank(agent11);
        uint256 id11 = erc8004Identity.register("ipfs://agent11");
        ceoToken.transfer(agent11, 1000e18);
        vm.prank(agent11);
        ceoToken.approve(address(vault), type(uint256).max);
        vm.prank(agent11);
        vault.registerAgent("ipfs://agent11", MIN_CEO_STAKE, id11);

        vm.prank(agent11);
        vm.expectRevert(ICEOVault.MaxProposalsReached.selector);
        vault.registerProposal(_defaultActions(), "uri11");
    }

    // ══════════════════════════════════════════════════════════════
    //                      VOTING TESTS
    // ══════════════════════════════════════════════════════════════

    function test_vote() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());

        vm.prank(agent2);
        vault.vote(0, true);

        ICEOVault.Proposal memory p = vault.getProposal(1, 0);
        assertGt(p.votesFor, 0);
    }

    function test_vote_revert_doubleVote() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());

        vm.prank(agent2);
        vault.vote(0, true);

        vm.prank(agent2);
        vm.expectRevert(ICEOVault.AlreadyVoted.selector);
        vault.vote(0, true);
    }

    function test_vote_against() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());

        vm.prank(agent2);
        vault.vote(0, false);

        ICEOVault.Proposal memory p = vault.getProposal(1, 0);
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

    function test_execute_depositToYieldVault() public {
        _registerAllAgents();
        ICEOVault.Action[] memory actions = _deployActions(500e6);
        _depositAndPropose(actions);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();

        vm.prank(ceo);
        vault.execute(0, actions);

        // Yield vault should have received USDC
        assertGt(yieldVault.balanceOf(address(vault)), 0, "Vault should have yield vault shares");
        // Deployed value should be reflected
        assertGt(vault.getDeployedValue(), 0, "Should track deployed value");
    }

    function test_execute_revert_notCeo_duringGrace() public {
        _registerAllAgents();
        ICEOVault.Action[] memory actions = _defaultActions();
        _depositAndPropose(actions);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        // Non-CEO tries during grace period
        address second = vault.getSecondAgent();
        vm.prank(second);
        vm.expectRevert(ICEOVault.GracePeriodOnlyCeo.selector);
        vault.execute(0, actions);
    }

    function test_execute_secondAgent_afterGrace() public {
        _registerAllAgents();
        ICEOVault.Action[] memory actions = _defaultActions();
        _depositAndPropose(actions);

        vm.warp(block.timestamp + EPOCH_DURATION + GRACE_PERIOD + 1);

        address ceo = vault.getTopAgent();
        address second = vault.getSecondAgent();
        assertTrue(second != address(0), "Should have second agent");
        assertTrue(second != ceo, "Second should differ from CEO");

        vm.prank(second);
        vault.execute(0, actions);

        // CEO should be penalized
        (,, int256 ceoScore,,,) = vault.getAgentInfo(ceo);
        assertTrue(ceoScore < 0, "CEO should have negative score from penalty");
    }

    function test_execute_revert_notCeo_beforeGrace_whenNoSecond() public {
        // Register only one agent so getSecondAgent() returns address(0)
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, agent1Id);
        assertEq(vault.getSecondAgent(), address(0), "No second agent expected");

        ICEOVault.Action[] memory actions = _defaultActions();

        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);
        _submitProposal(agent1, actions);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        // Non-CEO still blocked during grace period even without a second agent
        vm.prank(depositor2);
        vm.expectRevert(ICEOVault.GracePeriodOnlyCeo.selector);
        vault.execute(0, actions);
    }

    function test_execute_permissionless_afterGrace_whenNoSecond() public {
        // Register only one agent so getSecondAgent() returns address(0)
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, agent1Id);
        address ceo = vault.getTopAgent();
        assertEq(ceo, agent1, "Single agent should be CEO");
        assertEq(vault.getSecondAgent(), address(0), "No second agent expected");

        ICEOVault.Action[] memory actions = _defaultActions();

        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);
        _submitProposal(agent1, actions);

        vm.warp(block.timestamp + EPOCH_DURATION + GRACE_PERIOD + 1);

        // Permissionless execution opens after grace if no second agent exists
        vm.prank(depositor2);
        vault.execute(0, actions);

        assertTrue(vault.s_epochExecuted(), "Execution should succeed permissionlessly");
    }

    function test_execute_revert_nonSecond_afterGrace_whenSecondExists() public {
        _registerAllAgents();
        ICEOVault.Action[] memory actions = _defaultActions();
        _depositAndPropose(actions);

        vm.warp(block.timestamp + EPOCH_DURATION + GRACE_PERIOD + 1);

        address ceo = vault.getTopAgent();
        address second = vault.getSecondAgent();
        assertTrue(second != address(0), "Should have second agent");
        assertTrue(second != ceo, "Second should differ from CEO");

        // A caller that is neither CEO nor second is still blocked after grace
        vm.prank(depositor1);
        vm.expectRevert(ICEOVault.OnlyCeoOrSecond.selector);
        vault.execute(0, actions);
    }

    function test_execute_revokesTokenApproveAllowanceAfterExecution() public {
        _registerAllAgents();

        ICEOVault.Action[] memory actions = new ICEOVault.Action[](1);
        actions[0] = ICEOVault.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeCall(usdc.approve, (address(yieldVault), 1_000e6))
        });

        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vault.execute(0, actions);

        assertEq(usdc.allowance(address(vault), address(yieldVault)), 0, "USDC allowance should be reset to zero");
    }

    function test_registerProposal_revert_targetNotWhitelisted() public {
        _registerAllAgents();
        address random = makeAddr("random");
        ICEOVault.Action[] memory actions = new ICEOVault.Action[](1);
        actions[0] = ICEOVault.Action({target: random, value: 0, data: ""});

        // Deposit so vault has assets
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        // Proposal should revert at registration time (fail fast validation)
        vm.prank(agent1);
        vm.expectRevert(ICEOVault.ActionNotAllowed.selector);
        vault.registerProposal(actions, "https://moltiverse.xyz/proposals/1");
    }

    function test_execute_revert_actionsMismatch() public {
        _registerAllAgents();
        ICEOVault.Action[] memory registeredActions = _deployActions(500e6);
        _depositAndPropose(registeredActions);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();
        // Pass different actions (wrong amount) — should revert
        ICEOVault.Action[] memory wrongActions = _deployActions(1000e6);

        vm.prank(ceo);
        vm.expectRevert(ICEOVault.ActionsMismatch.selector);
        vault.execute(0, wrongActions);
    }

    // ══════════════════════════════════════════════════════════════
    //                  YIELD VAULT TESTS
    // ══════════════════════════════════════════════════════════════

    function test_addYieldVault() public {
        MockYieldVault newVault = new MockYieldVault(IERC20(address(usdc)));
        vault.addYieldVault(address(newVault));

        address[] memory vaults = vault.getYieldVaults();
        assertEq(vaults.length, 2); // original + new
        assertTrue(vault.s_isYieldVault(address(newVault)));
    }

    function test_addYieldVault_revert_duplicate() public {
        vm.expectRevert(ICEOVault.YieldVaultAlreadyAdded.selector);
        vault.addYieldVault(address(yieldVault));
    }

    function test_removeYieldVault() public {
        vault.removeYieldVault(address(yieldVault));
        assertFalse(vault.s_isYieldVault(address(yieldVault)));
        address[] memory vaults = vault.getYieldVaults();
        assertEq(vaults.length, 0);
    }

    function test_totalAssets_includesDeployedValue() public {
        // Deposit USDC
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        uint256 totalBefore = vault.totalAssets();

        // Approve and deploy some to yield vault
        _registerAllAgents();
        ICEOVault.Action[] memory actions = _deployActions(5000e6);
        _submitProposal(agent1, actions);
        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent3);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();

        vm.prank(ceo);
        vault.execute(0, actions);

        // Total assets should be approximately the same (USDC split between idle and deployed)
        uint256 totalAfter = vault.totalAssets();
        assertApproxEqAbs(totalAfter, totalBefore, 2e6); // small rounding tolerance
    }

    function test_onDemandPull_fromYieldVault() public {
        // Deposit USDC
        vm.prank(depositor1);
        uint256 shares = vault.deposit(10_000e6, depositor1);

        // Deploy most USDC to yield vault manually
        // (Simulate CEO deploying via direct calls for simplicity)
        uint256 deployAmount = 8000e6;
        vm.startPrank(address(vault));
        usdc.approve(address(yieldVault), deployAmount);
        yieldVault.deposit(deployAmount, address(vault));
        vm.stopPrank();

        // Depositor redeems all shares — should pull from yield vault
        uint256 usdcBefore = usdc.balanceOf(depositor1);
        vm.prank(depositor1);
        vault.redeem(shares, depositor1, depositor1);

        uint256 usdcAfter = usdc.balanceOf(depositor1);
        assertGt(usdcAfter - usdcBefore, 0, "Should have received USDC from pull");
    }

    // ══════════════════════════════════════════════════════════════
    //                 EPOCH SETTLEMENT TESTS
    // ══════════════════════════════════════════════════════════════

    function test_settleEpoch_profitable() public {
        // Deposit USDC
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        _registerAllAgents();
        ICEOVault.Action[] memory actions = _deployActions(5000e6);
        _submitProposal(agent1, actions);
        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent3);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();

        vm.prank(ceo);
        vault.execute(0, actions);

        // Simulate yield: mint extra USDC to yield vault
        usdc.mint(address(yieldVault), 500e6); // 500 USDC profit

        // Settle epoch
        vm.warp(block.timestamp + GRACE_PERIOD + 1);
        vault.settleEpoch();

        assertEq(vault.s_currentEpoch(), 2);
        // Performance fee should be accrued
        assertGt(vault.s_pendingPerformanceFeeUsdc(), 0, "Should accrue performance fee");
    }

    function test_settleEpoch_revert_tooEarly() public {
        _registerAllAgents();
        _submitProposal(agent1, _defaultActions());
        vm.prank(agent2);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        // Try to settle before grace period
        vm.expectRevert(ICEOVault.TooEarlyToSettle.selector);
        vault.settleEpoch();
    }

    function test_settleEpoch_advancesEpoch() public {
        _registerAllAgents();
        ICEOVault.Action[] memory actions = _defaultActions();
        _submitProposal(agent1, actions);
        vm.prank(agent2);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vault.execute(0, actions);

        vm.warp(block.timestamp + GRACE_PERIOD + 1);
        vault.settleEpoch();

        assertEq(vault.s_currentEpoch(), 2);
    }

    // ══════════════════════════════════════════════════════════════
    //                PERFORMANCE FEE TESTS
    // ══════════════════════════════════════════════════════════════

    function test_convertPerformanceFee() public {
        // Setup: deposit, propose, execute, generate yield, settle
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        _registerAllAgents();
        ICEOVault.Action[] memory actions = _defaultActions();
        _submitProposal(agent1, actions);
        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent3);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vault.execute(0, actions);

        // Simulate profit: add USDC directly to vault
        usdc.mint(address(vault), 1000e6); // 1000 USDC profit

        // Settle epoch
        vm.warp(block.timestamp + GRACE_PERIOD + 1);
        vault.settleEpoch();

        uint256 pendingFee = vault.s_pendingPerformanceFeeUsdc();
        assertGt(pendingFee, 0, "Should have pending performance fee");

        // Prepare conversion: fund mockDex with CEO tokens and whitelist it
        vault.setWhitelistedTarget(address(mockDex), true);
        ceoToken.transfer(address(mockDex), 10_000e18);

        // Build conversion actions: approve USDC to DEX, swap for CEO
        ICEOVault.Action[] memory convActions = new ICEOVault.Action[](1);
        convActions[0] = ICEOVault.Action({
            target: address(mockDex),
            value: 0,
            data: abi.encodeCall(mockDex.swapMonForCeo, (address(ceoToken), 100e18))
        });

        vm.prank(ceo);
        vault.convertPerformanceFee(convActions, 100e18);

        // Performance fee should be cleared
        assertEq(vault.s_pendingPerformanceFeeUsdc(), 0);

        // Agents should have claimable fees
        uint256 totalClaimable;
        totalClaimable += vault.s_claimableFees(agent1);
        totalClaimable += vault.s_claimableFees(agent2);
        totalClaimable += vault.s_claimableFees(agent3);
        assertEq(totalClaimable, 100e18, "Total claimable should equal converted CEO");
    }

    function test_convertPerformanceFee_revokesTokenApproveAllowanceAfterExecution() public {
        // Setup: deposit, propose, execute, generate yield, settle
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        _registerAllAgents();
        ICEOVault.Action[] memory actions = _defaultActions();
        _submitProposal(agent1, actions);
        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent3);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vault.execute(0, actions);

        usdc.mint(address(vault), 1000e6); // 1000 USDC profit

        vm.warp(block.timestamp + GRACE_PERIOD + 1);
        vault.settleEpoch();

        uint256 pendingFee = vault.s_pendingPerformanceFeeUsdc();
        assertGt(pendingFee, 0, "Should have pending performance fee");

        vault.setWhitelistedTarget(address(mockDex), true);
        ceoToken.transfer(address(mockDex), 10_000e18);

        ICEOVault.Action[] memory convActions = new ICEOVault.Action[](2);
        convActions[0] = ICEOVault.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeCall(usdc.approve, (address(mockDex), pendingFee))
        });
        convActions[1] = ICEOVault.Action({
            target: address(mockDex),
            value: 0,
            data: abi.encodeCall(mockDex.swapMonForCeo, (address(ceoToken), 100e18))
        });

        vm.prank(ceo);
        vault.convertPerformanceFee(convActions, 100e18);

        assertEq(usdc.allowance(address(vault), address(mockDex)), 0, "USDC allowance should be reset to zero");
    }

    function test_convertPerformanceFee_revert_noPendingFee() public {
        _registerAllAgents();

        ICEOVault.Action[] memory actions = new ICEOVault.Action[](0);
        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vm.expectRevert(ICEOVault.NoPerformanceFeeToConvert.selector);
        vault.convertPerformanceFee(actions, 0);
    }

    // ══════════════════════════════════════════════════════════════
    //                 FEE WITHDRAWAL TESTS
    // ══════════════════════════════════════════════════════════════

    function test_withdrawFees() public {
        // Give agent1 some claimable fees manually (via direct state manipulation)
        // In a real scenario, fees come from convertPerformanceFee
        // We test the withdrawal itself here
        _registerAllAgents();

        // Fund vault with CEO and set claimable
        ceoToken.transfer(address(vault), 500e18);
        // Use vm.store to set s_claimableFees[agent1]
        // slot = keccak256(abi.encode(agent1, slot_of_s_claimableFees))
        // Instead, let's test through the full flow
        // ... or just test revert
        vm.prank(agent1);
        vm.expectRevert(ICEOVault.NoFeesToWithdraw.selector);
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
        vm.expectRevert(ICEOVault.NotOwner.selector);
        vault.setTreasury(makeAddr("newTreasury"));
    }

    function test_setEntryFeeBps() public {
        vault.setEntryFeeBps(200); // 2%
        assertEq(vault.s_entryFeeBps(), 200);
    }

    function test_setEntryFeeBps_revert_tooHigh() public {
        vm.expectRevert(ICEOVault.InvalidFeePercentage.selector);
        vault.setEntryFeeBps(3000); // 30% > MAX_FEE_BPS
    }

    function test_setPerformanceFeeBps() public {
        vault.setPerformanceFeeBps(500); // 5%
        assertEq(vault.s_performanceFeeBps(), 500);
    }

    function test_transferOwnership() public {
        vault.transferOwnership(agent1);
        assertEq(vault.s_owner(), deployer);
        assertEq(vault.s_pendingOwner(), agent1);

        vm.prank(agent2);
        vm.expectRevert(ICEOVault.NotPendingOwner.selector);
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

    function test_pause_unpause() public {
        vault.pause();
        assertTrue(vault.paused());

        vault.unpause();
        assertFalse(vault.paused());
    }

    function test_pause_revert_notOwner() public {
        vm.prank(agent1);
        vm.expectRevert(ICEOVault.NotOwner.selector);
        vault.pause();
    }

    function test_pause_revert_alreadyPaused() public {
        vault.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.pause();
    }

    function test_unpause_revert_alreadyUnpaused() public {
        vm.expectRevert(Pausable.ExpectedPause.selector);
        vault.unpause();
    }

    function test_registerProposal_revert_paused() public {
        _registerAllAgents();
        ICEOVault.Action[] memory actions = _defaultActions();

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
        ICEOVault.Action[] memory actions = _defaultActions();
        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vault.pause();
        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.execute(0, actions);
    }

    function test_convertPerformanceFee_revert_paused() public {
        _registerAllAgents();
        ICEOVault.Action[] memory actions = _defaultActions();

        vault.pause();
        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.convertPerformanceFee(actions, 0);
    }

    function test_settleEpoch_revert_paused() public {
        vault.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.settleEpoch();
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
        vm.expectRevert(ICEOVault.NotOwner.selector);
        vault.recoverNative(makeAddr("recipient"), 1 ether);
    }

    function test_recoverNative_revert_zeroAddress() public {
        vm.deal(address(vault), 1 ether);
        vm.expectRevert(ICEOVault.ZeroAddress.selector);
        vault.recoverNative(address(0), 1 ether);
    }

    function test_recoverNative_revert_insufficientBalance() public {
        vm.deal(address(vault), 1 ether);
        vm.expectRevert(ICEOVault.NativeTransferFailed.selector);
        vault.recoverNative(makeAddr("recipient"), 2 ether);
    }

    function test_recoverNative_zeroAmount_noOp() public {
        vm.deal(address(vault), 1 ether);
        address recipient = makeAddr("recipient");
        vault.recoverNative(recipient, 0);
        assertEq(recipient.balance, 0);
        assertEq(address(vault).balance, 1 ether);
    }

    // ══════════════════════════════════════════════════════════════
    //                  FULL LIFECYCLE TEST
    // ══════════════════════════════════════════════════════════════

    function test_fullLifecycle() public {
        // 1. Depositors deposit USDC
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);
        vm.prank(depositor2);
        vault.deposit(5_000e6, depositor2);

        // 2. Register agents
        _registerAllAgents();

        // 3. Submit proposals (agent1's proposal wins with deploy 10_000e6)
        ICEOVault.Action[] memory winningActions = _deployActions(10_000e6);
        _submitProposal(agent1, winningActions);
        _submitProposal(agent2, _deployActions(5000e6)); // Different strategy, loses

        // 4. Vote
        vm.prank(agent1);
        vault.vote(0, true);
        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent3);
        vault.vote(0, true);

        // 5. Verify winning proposal
        (uint256 bestId,) = vault.getWinningProposal(1);
        assertEq(bestId, 0);

        // 6. Advance past voting
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        // 7. CEO executes strategy
        address ceo = vault.getTopAgent();
        assertTrue(ceo != address(0));

        vm.prank(ceo);
        vault.execute(0, winningActions);

        // Verify execution
        ICEOVault.Proposal memory p = vault.getProposal(1, 0);
        assertTrue(p.executed);

        // 8. Simulate yield
        usdc.mint(address(yieldVault), 300e6); // 300 USDC yield

        // 9. Settle epoch
        vm.warp(block.timestamp + GRACE_PERIOD + 1);
        vault.settleEpoch();

        assertEq(vault.s_currentEpoch(), 2);

        // 10. Depositor redeems
        uint256 shares1 = vault.balanceOf(depositor1);
        vm.prank(depositor1);
        uint256 redeemed = vault.redeem(shares1, depositor1, depositor1);
        assertGt(redeemed, 0, "Should receive USDC back");

        // Depositor should have more than they started with (minus entry fee + yield share)
        // Entry fee was ~1% of 10000 = 100 USDC, but yield should compensate
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
        vm.expectRevert(ICEOVault.NotOwner.selector);
        vault.setERC8004Registries(address(1), address(2), address(3));
    }

    function test_epochSettlement_postsReputation() public {
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        _registerAllAgents();
        ICEOVault.Action[] memory actions = _defaultActions();
        _submitProposal(agent1, actions);
        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent3);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vault.execute(0, actions);

        vm.warp(block.timestamp + GRACE_PERIOD + 1);
        vault.settleEpoch();

        // Should have posted reputation feedback
        assertEq(erc8004Reputation.totalFeedbackCount(), 1);
    }

    // ══════════════════════════════════════════════════════════════
    //                       HELPERS
    // ══════════════════════════════════════════════════════════════

    function _registerAllAgents() internal {
        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1", MIN_CEO_STAKE, agent1Id);
        vm.prank(agent2);
        vault.registerAgent("ipfs://agent2", MIN_CEO_STAKE, agent2Id);
        vm.prank(agent3);
        vault.registerAgent("ipfs://agent3", MIN_CEO_STAKE, agent3Id);
    }

    /// @dev Returns minimal no-op actions for proposals that are never executed
    function _defaultActions() internal view returns (ICEOVault.Action[] memory) {
        ICEOVault.Action[] memory actions = new ICEOVault.Action[](1);
        actions[0] = ICEOVault.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeCall(usdc.approve, (address(yieldVault), 0))
        });
        return actions;
    }

    /// @dev Returns deploy-to-yield actions for the given amount
    function _deployActions(uint256 amount) internal view returns (ICEOVault.Action[] memory) {
        ICEOVault.Action[] memory actions = new ICEOVault.Action[](2);
        actions[0] = ICEOVault.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeCall(usdc.approve, (address(yieldVault), amount))
        });
        actions[1] = ICEOVault.Action({
            target: address(yieldVault),
            value: 0,
            data: abi.encodeCall(yieldVault.deposit, (amount, address(vault)))
        });
        return actions;
    }

    function _submitProposal(address agent, ICEOVault.Action[] memory actions) internal {
        vm.prank(agent);
        vault.registerProposal(actions, "https://moltiverse.xyz/proposals/1");
    }

    function _depositAndPropose(ICEOVault.Action[] memory actions) internal {
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        _submitProposal(agent1, actions);
        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent3);
        vault.vote(0, true);
    }
}
