// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {CEOToken} from "../src/CEOToken.sol";
import {CEOVaultV2} from "../src/CEOVaultV2.sol";
import {ICEOVaultV2} from "../src/ICEOVaultV2.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockYieldVault} from "./mocks/MockYieldVault.sol";
import {MockERC8004Identity} from "./mocks/MockERC8004Identity.sol";
import {MockERC8004Reputation} from "./mocks/MockERC8004Reputation.sol";
import {MockFeeDex} from "./mocks/MockFeeDex.sol";
import {MockLending} from "./mocks/MockLending.sol";
import {MockLendingValueAdapter} from "./mocks/MockLendingValueAdapter.sol";
import {IValueAdapter} from "../src/IValueAdapter.sol";

/// @title MockRevertingValueAdapter — Value adapter that always reverts (for testing fault tolerance)
contract MockRevertingValueAdapter is IValueAdapter {
    function getDeployedValue(address) external pure override returns (uint256) {
        revert("MockRevertingValueAdapter");
    }
}

/// @title CEOVaultV2StrategiesTest — Strategy-focused tests for CEOVaultV2
/// @notice Tests governance proposal execution flows: DEX, lending, rebalance, multi-step strategies.
contract CEOVaultV2StrategiesTest is Test {
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

    // ══════════════════════════════════════════════════════════════
    //              BASIC STRATEGY: YIELD VAULT DEPOSIT
    // ══════════════════════════════════════════════════════════════

    /// @notice Strategy: Approve USDC to yield vault, then deposit.
    ///         Simplest deploy flow — capital moves from idle to ERC4626 yield vault.
    function test_strategy_depositToYieldVault() public {
        _registerAllAgents();
        ICEOVaultV2.Action[] memory actions = _deployActions(500e6);
        _depositAndPropose(actions);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        (address[] memory agents,) = vault.getLeaderboard();
        vm.prank(agents[0]);
        vault.execute(0, actions);

        assertGt(yieldVault.balanceOf(address(vault)), 0);
        assertGt(vault.getDeployedValue(), 0);
    }

    // ══════════════════════════════════════════════════════════════
    //              DEX STRATEGY
    // ══════════════════════════════════════════════════════════════

    /// @notice Strategy: Call whitelisted DEX to swap/receive tokens.
    ///         Vault calls MockFeeDex.swapMonForCeo() — DEX sends CEO to vault.
    ///         Tests non-yield-vault target + allowed selector flow.
    function test_strategy_dexSwapReceivesCeo() public {
        MockFeeDex mockDex = new MockFeeDex();
        vm.label(address(mockDex), "MockFeeDex");

        ceoToken.transfer(address(mockDex), 100e18);
        vault.setWhitelistedTarget(address(mockDex), true);
        vault.addAllowedSelector(address(mockDex), MockFeeDex.swapMonForCeo.selector);

        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({
            target: address(mockDex),
            value: 0,
            data: abi.encodeWithSelector(MockFeeDex.swapMonForCeo.selector, address(ceoToken), 50e18)
        });

        _submitProposal(agent1, actions);
        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent3);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        uint256 ceoBefore = ceoToken.balanceOf(address(vault));
        vm.prank(depositor1);
        vault.execute(0, actions);

        assertEq(ceoToken.balanceOf(address(vault)), ceoBefore + 50e18, "Vault should have received 50 CEO from DEX");
    }

    // ══════════════════════════════════════════════════════════════
    //              LENDING STRATEGY
    // ══════════════════════════════════════════════════════════════

    /// @notice Strategy: Approve USDC to lending protocol, then supply.
    ///         Capital moves from vault to lending; vault holds lending receipt (balanceOf).
    function test_strategy_lendingSupply() public {
        MockLending mockLending = new MockLending(IERC20(address(usdc)));
        vm.label(address(mockLending), "MockLending");

        vault.setWhitelistedTarget(address(mockLending), true);
        vault.addAllowedSelector(address(mockLending), MockLending.supply.selector);

        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        uint256 supplyAmount = 5000e6;
        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](2);
        actions[0] = ICEOVaultV2.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, address(mockLending), supplyAmount)
        });
        actions[1] = ICEOVaultV2.Action({
            target: address(mockLending),
            value: 0,
            data: abi.encodeWithSelector(MockLending.supply.selector, supplyAmount)
        });

        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        uint256 usdcBefore = usdc.balanceOf(address(vault));
        vm.prank(depositor1);
        vault.execute(0, actions);

        assertEq(mockLending.balanceOf(address(vault)), supplyAmount, "Vault should have supplied to lending");
        assertEq(usdc.balanceOf(address(vault)), usdcBefore - supplyAmount, "Vault USDC should have decreased");
    }

    // ══════════════════════════════════════════════════════════════
    //              REBALANCE STRATEGY
    // ══════════════════════════════════════════════════════════════

    /// @notice Strategy: Rebalance idle USDC across two yield vaults (50/50).
    ///         Single action: executeRebalance allocates totalAssets by bps.
    function test_strategy_rebalance50_50AcrossTwoYieldVaults() public {
        MockYieldVault yieldVault2 = new MockYieldVault(IERC20(address(usdc)));
        vm.label(address(yieldVault2), "MockYieldVault2");
        vault.addYieldVault(address(yieldVault2));

        _registerAllAgents();

        ICEOVaultV2.AllocationTarget[] memory allocs = new ICEOVaultV2.AllocationTarget[](2);
        allocs[0] = ICEOVaultV2.AllocationTarget({vault: address(yieldVault), bps: 5000});
        allocs[1] = ICEOVaultV2.AllocationTarget({vault: address(yieldVault2), bps: 5000});

        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({
            target: address(vault),
            value: 0,
            data: abi.encodeWithSelector(CEOVaultV2.executeRebalance.selector, allocs)
        });

        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vm.prank(depositor1);
        vault.execute(0, actions);

        uint256 shares1 = IERC20(address(yieldVault)).balanceOf(address(vault));
        uint256 shares2 = IERC20(address(yieldVault2)).balanceOf(address(vault));
        assertGt(shares1, 0, "Yield vault 1 should have shares");
        assertGt(shares2, 0, "Yield vault 2 should have shares");
        assertApproxEqRel(shares1, shares2, 0.1e18, "Allocation should be roughly 50/50");
    }

    /// @notice Revert: executeRebalance with non-yield-vault target fails validation.
    function test_strategy_rebalance_revert_invalidAllocation() public {
        address nonYieldVault = makeAddr("nonYieldVault");
        ICEOVaultV2.AllocationTarget[] memory allocs = new ICEOVaultV2.AllocationTarget[](1);
        allocs[0] = ICEOVaultV2.AllocationTarget({vault: nonYieldVault, bps: 10000});

        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({
            target: address(vault),
            value: 0,
            data: abi.encodeWithSelector(CEOVaultV2.executeRebalance.selector, allocs)
        });

        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.ActionNotAllowed.selector);
        vault.registerProposal(actions, "https://moltiverse.xyz/proposals/invalid");
    }

    // ══════════════════════════════════════════════════════════════
    //              GOVERNANCE SELF-CALL STRATEGIES
    // ══════════════════════════════════════════════════════════════

    /// @notice Strategy: Governance adds a token to approvable list via proposal.
    ///         Vault self-calls addApprovableToken — enables future proposals to approve that token.
    function test_strategy_governance_addApprovableToken() public {
        address someToken = makeAddr("someToken");

        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({
            target: address(vault),
            value: 0,
            data: abi.encodeWithSelector(CEOVaultV2.addApprovableToken.selector, someToken)
        });

        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vm.prank(depositor1);
        vault.execute(0, actions);

        assertTrue(vault.s_isApprovableToken(someToken), "Token should be approvable");
    }

    /// @notice Strategy: Governance removes a token from approvable list via proposal.
    ///         Owner adds token first; winning proposal self-calls removeApprovableToken.
    function test_strategy_governance_removeApprovableToken() public {
        address token = makeAddr("governanceToken");
        vault.addApprovableToken(token);
        assertTrue(vault.s_isApprovableToken(token));

        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({
            target: address(vault),
            value: 0,
            data: abi.encodeWithSelector(CEOVaultV2.removeApprovableToken.selector, token)
        });

        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vm.prank(depositor1);
        vault.execute(0, actions);

        assertFalse(vault.s_isApprovableToken(token), "Token should no longer be approvable");
    }

    /// @notice Revert: addApprovableToken(address(0)) fails validation.
    function test_strategy_governance_addApprovableToken_revert_zeroAddress() public {
        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](1);
        actions[0] = ICEOVaultV2.Action({
            target: address(vault),
            value: 0,
            data: abi.encodeWithSelector(CEOVaultV2.addApprovableToken.selector, address(0))
        });

        vm.prank(agent1);
        vm.expectRevert(ICEOVaultV2.ActionNotAllowed.selector);
        vault.registerProposal(actions, "https://moltiverse.xyz/proposals/zero");
    }

    // ══════════════════════════════════════════════════════════════
    //              MULTI-STEP STRATEGIES
    // ══════════════════════════════════════════════════════════════

    /// @notice Strategy: Approve → supply to lending → rebalance remainder to yield vault.
    ///         Splits capital: part in lending, part in yield vault.
    function test_strategy_approveSupplyRebalanceDeposit() public {
        MockLending mockLending = new MockLending(IERC20(address(usdc)));
        vm.label(address(mockLending), "MockLending");

        vault.setWhitelistedTarget(address(mockLending), true);
        vault.addAllowedSelector(address(mockLending), MockLending.supply.selector);

        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        uint256 supplyAmount = 3000e6;
        ICEOVaultV2.AllocationTarget[] memory allocs = new ICEOVaultV2.AllocationTarget[](1);
        allocs[0] = ICEOVaultV2.AllocationTarget({vault: address(yieldVault), bps: 10000});

        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](3);
        actions[0] = ICEOVaultV2.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, address(mockLending), supplyAmount)
        });
        actions[1] = ICEOVaultV2.Action({
            target: address(mockLending),
            value: 0,
            data: abi.encodeWithSelector(MockLending.supply.selector, supplyAmount)
        });
        actions[2] = ICEOVaultV2.Action({
            target: address(vault),
            value: 0,
            data: abi.encodeWithSelector(CEOVaultV2.executeRebalance.selector, allocs)
        });

        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vm.prank(depositor1);
        vault.execute(0, actions);

        assertEq(mockLending.balanceOf(address(vault)), supplyAmount, "Lending should have supplied amount");
        assertGt(IERC20(address(yieldVault)).balanceOf(address(vault)), 0, "Yield vault should have remainder");
    }

    /// @notice Strategy: Redeem from lending → rebalance to yield vaults.
    ///         Withdraws USDC from lending, then rebalances idle into yield vaults.
    function test_strategy_redeemFromLendingThenRebalance() public {
        MockLending mockLending = new MockLending(IERC20(address(usdc)));
        vm.label(address(mockLending), "MockLending");

        vault.setWhitelistedTarget(address(mockLending), true);
        vault.addAllowedSelector(address(mockLending), MockLending.supply.selector);
        vault.addAllowedSelector(address(mockLending), MockLending.redeem.selector);

        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        // First: supply to lending
        uint256 supplyAmount = 4000e6;
        ICEOVaultV2.Action[] memory supplyActions = new ICEOVaultV2.Action[](2);
        supplyActions[0] = ICEOVaultV2.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, address(mockLending), supplyAmount)
        });
        supplyActions[1] = ICEOVaultV2.Action({
            target: address(mockLending),
            value: 0,
            data: abi.encodeWithSelector(MockLending.supply.selector, supplyAmount)
        });

        _depositAndPropose(supplyActions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        vm.prank(depositor1);
        vault.execute(0, supplyActions);
        // execute chains settle internally

        assertEq(mockLending.balanceOf(address(vault)), supplyAmount);

        // Second epoch: redeem half from lending, rebalance to yield vault
        uint256 epoch2Start = vault.s_epochStartTime(); // Use vault's epoch start (set by settle)

        vm.prank(depositor1);
        vault.deposit(1e6, depositor1); // Small deposit to have funds in epoch 2

        uint256 redeemAmount = 2000e6;
        ICEOVaultV2.AllocationTarget[] memory allocs = new ICEOVaultV2.AllocationTarget[](1);
        allocs[0] = ICEOVaultV2.AllocationTarget({vault: address(yieldVault), bps: 10000});

        ICEOVaultV2.Action[] memory redeemActions = new ICEOVaultV2.Action[](2);
        redeemActions[0] = ICEOVaultV2.Action({
            target: address(mockLending),
            value: 0,
            data: abi.encodeWithSelector(MockLending.redeem.selector, redeemAmount)
        });
        redeemActions[1] = ICEOVaultV2.Action({
            target: address(vault),
            value: 0,
            data: abi.encodeWithSelector(CEOVaultV2.executeRebalance.selector, allocs)
        });

        _submitProposal(agent1, redeemActions);
        vm.prank(agent2);
        vault.vote(0, true);
        vm.prank(agent3);
        vault.vote(0, true);

        vm.warp(epoch2Start + EPOCH_DURATION + 1); // Advance past voting for epoch 2
        (address[] memory agents,) = vault.getLeaderboard();
        vm.prank(agents[0]);
        vault.execute(0, redeemActions);

        assertEq(mockLending.balanceOf(address(vault)), supplyAmount - redeemAmount, "Lending balance should decrease");
        assertGt(IERC20(address(yieldVault)).balanceOf(address(vault)), 0, "Yield vault should have received");
    }

    /// @notice Strategy: Four actions — approve, supply, approve yield vault, deposit.
    ///         Tests longer ordered sequence and gas behavior.
    function test_strategy_fourActions_approveSupplyApproveDeposit() public {
        MockLending mockLending = new MockLending(IERC20(address(usdc)));
        vm.label(address(mockLending), "MockLending");

        vault.setWhitelistedTarget(address(mockLending), true);
        vault.addAllowedSelector(address(mockLending), MockLending.supply.selector);

        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        uint256 supplyAmount = 2000e6;
        uint256 depositAmount = 3000e6;

        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](4);
        actions[0] = ICEOVaultV2.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, address(mockLending), supplyAmount)
        });
        actions[1] = ICEOVaultV2.Action({
            target: address(mockLending),
            value: 0,
            data: abi.encodeWithSelector(MockLending.supply.selector, supplyAmount)
        });
        actions[2] = ICEOVaultV2.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, address(yieldVault), depositAmount)
        });
        actions[3] = ICEOVaultV2.Action({
            target: address(yieldVault),
            value: 0,
            data: abi.encodeWithSelector(IERC4626.deposit.selector, depositAmount, address(vault))
        });

        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vm.prank(depositor1);
        vault.execute(0, actions);

        assertEq(mockLending.balanceOf(address(vault)), supplyAmount);
        assertGt(IERC20(address(yieldVault)).balanceOf(address(vault)), 0);
    }

    /// @notice Strategy: Lending then DEX — supply to lending, then call DEX.
    ///         Tests chaining lending and DEX in one proposal.
    function test_strategy_lendingThenDex() public {
        MockLending mockLending = new MockLending(IERC20(address(usdc)));
        MockFeeDex mockDex = new MockFeeDex();
        vm.label(address(mockLending), "MockLending");
        vm.label(address(mockDex), "MockFeeDex");

        ceoToken.transfer(address(mockDex), 50e18);
        vault.setWhitelistedTarget(address(mockLending), true);
        vault.addAllowedSelector(address(mockLending), MockLending.supply.selector);
        vault.setWhitelistedTarget(address(mockDex), true);
        vault.addAllowedSelector(address(mockDex), MockFeeDex.swapMonForCeo.selector);

        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        uint256 supplyAmount = 3000e6;

        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](3);
        actions[0] = ICEOVaultV2.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, address(mockLending), supplyAmount)
        });
        actions[1] = ICEOVaultV2.Action({
            target: address(mockLending),
            value: 0,
            data: abi.encodeWithSelector(MockLending.supply.selector, supplyAmount)
        });
        actions[2] = ICEOVaultV2.Action({
            target: address(mockDex),
            value: 0,
            data: abi.encodeWithSelector(MockFeeDex.swapMonForCeo.selector, address(ceoToken), 25e18)
        });

        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        uint256 ceoBefore = ceoToken.balanceOf(address(vault));
        vm.prank(depositor1);
        vault.execute(0, actions);

        assertEq(mockLending.balanceOf(address(vault)), supplyAmount);
        assertEq(ceoToken.balanceOf(address(vault)), ceoBefore + 25e18);
    }

    // ══════════════════════════════════════════════════════════════
    //              VALUE ADAPTER STRATEGIES
    // ══════════════════════════════════════════════════════════════

    /// @notice Strategy: Supply to lending + value adapter reports deployed value.
    ///         totalAssets() includes both yield vaults and adapter-reported lending balance.
    function test_strategy_valueAdapterIncludedInTotalAssets() public {
        MockLending mockLending = new MockLending(IERC20(address(usdc)));
        vm.label(address(mockLending), "MockLending");

        vault.setWhitelistedTarget(address(mockLending), true);
        vault.addAllowedSelector(address(mockLending), MockLending.supply.selector);

        MockLendingValueAdapter lendingAdapter = new MockLendingValueAdapter(mockLending);
        vault.addValueAdapter(address(lendingAdapter));

        _registerAllAgents();
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        uint256 supplyAmount = 5000e6;
        ICEOVaultV2.Action[] memory actions = new ICEOVaultV2.Action[](2);
        actions[0] = ICEOVaultV2.Action({
            target: address(usdc),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, address(mockLending), supplyAmount)
        });
        actions[1] = ICEOVaultV2.Action({
            target: address(mockLending),
            value: 0,
            data: abi.encodeWithSelector(MockLending.supply.selector, supplyAmount)
        });

        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vm.prank(depositor1);
        vault.execute(0, actions);

        assertEq(lendingAdapter.getDeployedValue(address(vault)), supplyAmount, "Adapter should report lending balance");
        assertEq(vault.getDeployedValue(), supplyAmount, "Vault deployed value should include lending via adapter");
        assertGt(vault.totalAssets(), 0, "Total assets should include value adapter reported value");
    }

    /// @notice Strategy: Reverting value adapter is skipped — totalAssets still works.
    ///         Vault uses try/catch; reverting adapter contributes 0 (conservative).
    function test_strategy_valueAdapterReverts_stillCountsOtherSources() public {
        MockRevertingValueAdapter revertingAdapter = new MockRevertingValueAdapter();
        vault.addValueAdapter(address(revertingAdapter));

        _registerAllAgents();
        ICEOVaultV2.Action[] memory actions = _deployActions(5000e6);
        _depositAndPropose(actions);
        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        vm.prank(depositor1);
        vault.execute(0, actions);

        // Yield vault value is counted; reverting adapter contributes 0
        assertGt(vault.getDeployedValue(), 0, "Yield vault value should be counted");
        assertGt(vault.totalAssets(), 0, "totalAssets should include yield vault despite reverting adapter");
    }
}
