// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CEOVault} from "../src/CEOVault.sol";
import {ICEOVault} from "../src/ICEOVault.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {MockFeeDex} from "./mocks/MockFeeDex.sol";

/// @title CEOVaultFork — Fork tests against Monad mainnet
/// @notice Run with: forge test --match-contract CEOVaultFork --fork-url $MONAD_RPC_URL
///
/// Environment variables:
///   MONAD_RPC_URL  — Monad RPC endpoint (required)
///   USDC_WHALE     — Address with USDC to fund depositors (optional; uses default if not set)
///   CEO_WHALE      — Address with $CEO to fund agents (optional; uses default if not set)
contract CEOVaultForkTest is Test {
    // ══════════════════════════════════════════════════════════════
    //                    MONAD MAINNET ADDRESSES
    // ══════════════════════════════════════════════════════════════

    address constant USDC_MONAD = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
    address constant CEO_TOKEN_MONAD = 0xCA26f09831A15dCB9f9D47CE1cC2e3B086467777;
    address constant ERC8004_IDENTITY = 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432;
    address constant ERC8004_REPUTATION = 0x8004BAa17C55a88189AE136b182e5fdA19dE9b63;

    // Steakhouse Morpho vaults
    address constant MORPHO_USDC_VAULT = 0xbeEFf443C3CbA3E369DA795002243BeaC311aB83;

    // Uniswap V4 on Monad (pool id: 0x18a9fc874581f3ba12b7898f80a683c66fd5877fd74b26a85ba9a3a79c549954)
    address constant UNISWAP_POOL_MANAGER = 0x188d586Ddcf52439676Ca21A244753fA19F9Ea8e;
    address constant UNISWAP_POSITION_DESCRIPTOR = 0x5770D2914355a6D0a39A70AeEa9bcCe55Df4201B;
    address constant UNISWAP_POSITION_MANAGER = 0x5b7eC4a94fF9beDb700fb82aB09d5846972F4016;
    address constant UNISWAP_QUOTER = 0xa222Dd357A9076d1091Ed6Aa2e16C9742dD26891;
    address constant UNISWAP_STATE_VIEW = 0x77395F3b2E73aE90843717371294fa97cC419D64;
    address constant UNISWAP_UNIVERSAL_ROUTER = 0x0D97Dc33264bfC1c226207428A79b26757fb9dc3;
    address constant UNISWAP_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // ══════════════════════════════════════════════════════════════
    //                         STATE
    // ══════════════════════════════════════════════════════════════

    CEOVault public vault;
    bool public forkConfigured;

    address public treasury = makeAddr("treasury");
    address public depositor1 = makeAddr("depositor1");
    address public agent1 = makeAddr("agent1");
    address public agent2 = makeAddr("agent2");

    uint256 public constant MIN_CEO_STAKE = 50_000e18;
    uint256 public constant EPOCH_DURATION = 7 days;
    uint256 public constant GRACE_PERIOD = 1 hours;
    uint256 public constant ENTRY_FEE_BPS = 100;
    uint256 public constant PERFORMANCE_FEE_BPS = 100;
    uint256 public constant MAX_AGENTS = 100;
    uint256 public constant MAX_ACTIONS = 20;

    uint256 public agent1Id;
    uint256 public agent2Id;

    function setUp() public {
        string memory rpcUrl = vm.envOr("MONAD_RPC_URL", string(""));
        if (bytes(rpcUrl).length > 0) {
            vm.createSelectFork(rpcUrl);
            forkConfigured = true;
        } else {
            try vm.activeFork() returns (uint256) {
                forkConfigured = true;
            } catch {
                return;
            }
        }

        vm.deal(address(this), 100 ether);

        // Deploy CEOVault
        vault = new CEOVault(
            IERC20(USDC_MONAD),
            IERC20(CEO_TOKEN_MONAD),
            treasury,
            ENTRY_FEE_BPS,
            PERFORMANCE_FEE_BPS,
            MIN_CEO_STAKE,
            0,         // vaultCap: no cap
            0,         // maxDepositPerAddress: no cap
            EPOCH_DURATION,
            GRACE_PERIOD,
            MAX_AGENTS,
            MAX_ACTIONS
        );

        vault.setERC8004Registries(ERC8004_IDENTITY, ERC8004_REPUTATION, address(0));
        vault.addYieldVault(MORPHO_USDC_VAULT);

        // Whitelist Uniswap V4 Universal Router for execute/convertPerformanceFee swap actions
        vault.setWhitelistedTarget(UNISWAP_UNIVERSAL_ROUTER, true);
        vault.setWhitelistedTarget(UNISWAP_POOL_MANAGER, true);

        console.log("CEOVault deployed at:", address(vault));

        // Fund test accounts from whales (set USDC_WHALE and CEO_WHALE for Monad)
        address usdcWhale =0x464Aec9Fa2a78F3312bb155e82f7D1b063A336BE;
        address ceoWhale = 0xC1923710468607b8B7DB38a6AfBB9B432744390c;

        if (usdcWhale != address(0)) {
            uint256 usdcBalance = IERC20(USDC_MONAD).balanceOf(usdcWhale);
            console.log("USDC whale balance:", usdcBalance / 1e6, "USDC");
            if (usdcBalance >= 100_000e6) {
                vm.prank(usdcWhale);
                IERC20(USDC_MONAD).transfer(depositor1, 100_000e6);
                console.log("Funded depositor1 with 100k USDC");
            }
        }

        if (ceoWhale != address(0)) {
            uint256 ceoBalance = IERC20(CEO_TOKEN_MONAD).balanceOf(ceoWhale);
            console.log("CEO whale balance:", ceoBalance / 1e18, "CEO");
            if (ceoBalance >= 200_000e18) {
                vm.prank(ceoWhale);
                IERC20(CEO_TOKEN_MONAD).transfer(agent1, 100_000e18);
                vm.prank(ceoWhale);
                IERC20(CEO_TOKEN_MONAD).transfer(agent2, 100_000e18);
                console.log("Funded agent1, agent2 with 100k CEO each");
            }
        }

        // Register ERC-8004 identities for agents
        vm.prank(agent1);
        agent1Id = IERC8004Identity(ERC8004_IDENTITY).register("ipfs://agent1-fork");
        vm.prank(agent2);
        agent2Id = IERC8004Identity(ERC8004_IDENTITY).register("ipfs://agent2-fork");
        console.log("ERC-8004 agent IDs:", agent1Id, agent2Id);

        vm.prank(agent1);
        IERC20(CEO_TOKEN_MONAD).approve(address(vault), type(uint256).max);
        vm.prank(agent2);
        IERC20(CEO_TOKEN_MONAD).approve(address(vault), type(uint256).max);

        vm.prank(depositor1);
        IERC20(USDC_MONAD).approve(address(vault), type(uint256).max);
    }

    function _skipIfNoFork() internal {
        if (!forkConfigured) {
            vm.skip(true);
        }
    }

    function _skipIfNoFunds() internal {
        if (IERC20(USDC_MONAD).balanceOf(depositor1) < 1000e6) {
            vm.skip(true);
        }
        if (IERC20(CEO_TOKEN_MONAD).balanceOf(agent1) < MIN_CEO_STAKE) {
            vm.skip(true);
        }
    }

    // ══════════════════════════════════════════════════════════════
    //                    FORK DEPLOYMENT TESTS
    // ══════════════════════════════════════════════════════════════

    function test_fork_deploy() public {
        _skipIfNoFork();
        assertEq(address(vault.asset()), USDC_MONAD);
        assertEq(address(vault.i_ceoToken()), CEO_TOKEN_MONAD);
        assertEq(vault.s_treasury(), treasury);
        assertEq(vault.s_epochDuration(), EPOCH_DURATION);

        console.log("Fork deploy OK: vault", address(vault));
        console.log("  USDC:", USDC_MONAD);
        console.log("  CEO:", CEO_TOKEN_MONAD);
    }

    function test_fork_erc8004_configured() public {
        _skipIfNoFork();
        assertEq(address(vault.s_erc8004Identity()), ERC8004_IDENTITY);
        assertEq(address(vault.s_erc8004Reputation()), ERC8004_REPUTATION);

        console.log("ERC-8004 identity:", ERC8004_IDENTITY);
        console.log("ERC-8004 reputation:", ERC8004_REPUTATION);
    }

    function test_fork_yieldVault_added() public {
        _skipIfNoFork();
        address[] memory vaults = vault.getYieldVaults();
        assertEq(vaults.length, 1);
        assertEq(vaults[0], MORPHO_USDC_VAULT);

        console.log("Yield vault added:", MORPHO_USDC_VAULT);
    }

    function test_fork_uniswapV4_whitelisted() public {
        _skipIfNoFork();
        assertTrue(vault.s_isWhitelistedTarget(UNISWAP_UNIVERSAL_ROUTER));
        assertTrue(vault.s_isWhitelistedTarget(UNISWAP_POOL_MANAGER));

        console.log("Uniswap V4 Universal Router:", UNISWAP_UNIVERSAL_ROUTER);
        console.log("Uniswap V4 PoolManager:", UNISWAP_POOL_MANAGER);
    }

    // ══════════════════════════════════════════════════════════════
    //                    DEPOSIT / REDEEM TESTS
    // ══════════════════════════════════════════════════════════════

    function test_fork_deposit() public {
        _skipIfNoFork();
        _skipIfNoFunds();

        uint256 depositAmount = 1000e6;
        vm.prank(depositor1);
        uint256 shares = vault.deposit(depositAmount, depositor1);

        assertGt(shares, 0);
        assertEq(vault.balanceOf(depositor1), shares);
        assertApproxEqAbs(vault.totalAssets(), depositAmount * (10_000 - ENTRY_FEE_BPS) / 10_000, 1e6);

        console.log("Deposit:", depositAmount / 1e6, "USDC, shares:", shares);
        console.log("  totalAssets:", vault.totalAssets() / 1e6);
    }

    function test_fork_redeem() public {
        _skipIfNoFork();
        _skipIfNoFunds();

        vm.prank(depositor1);
        uint256 shares = vault.deposit(5000e6, depositor1);

        uint256 usdcBefore = IERC20(USDC_MONAD).balanceOf(depositor1);
        vm.prank(depositor1);
        uint256 assets = vault.redeem(shares, depositor1, depositor1);

        assertGt(assets, 0);
        assertEq(IERC20(USDC_MONAD).balanceOf(depositor1), usdcBefore + assets);
        assertEq(vault.balanceOf(depositor1), 0);

        console.log("Redeem:", shares, "shares ->", assets / 1e6);
    }

    // ══════════════════════════════════════════════════════════════
    //                   AGENT REGISTRATION TESTS
    // ══════════════════════════════════════════════════════════════

    function test_fork_registerAgent() public {
        _skipIfNoFork();
        _skipIfNoFunds();

        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1-fork", MIN_CEO_STAKE, agent1Id);

        (bool active, uint256 staked,, uint256 erc8004Id,,) = vault.getAgentInfo(agent1);
        assertTrue(active);
        assertEq(staked, MIN_CEO_STAKE);
        assertEq(erc8004Id, agent1Id);

        console.log("Agent registered:", agent1);
        console.log("  staked:", staked / 1e18, "CEO");
        console.log("  erc8004Id:", erc8004Id);
    }

    function test_fork_deposit_execute_redeem() public {
        _skipIfNoFork();
        _skipIfNoFunds();

        vm.prank(depositor1);
        uint256 shares = vault.deposit(10_000e6, depositor1);
        console.log("Full lifecycle: deposited 10k USDC, shares:", shares);

        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1-fork", MIN_CEO_STAKE, agent1Id);
        vm.prank(agent2);
        vault.registerAgent("ipfs://agent2-fork", MIN_CEO_STAKE, agent2Id);

        ICEOVault.Action[] memory actions = _deployActions(5000e6);
        vm.prank(agent1);
        vault.registerProposal(actions, "https://moltiverse.xyz/fork-test");

        vm.prank(agent2);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vault.execute(0, actions);

        uint256 morphoShares = IERC4626(MORPHO_USDC_VAULT).balanceOf(address(vault));
        uint256 deployedValue = vault.getDeployedValue();
        assertGt(morphoShares, 0);
        assertGt(deployedValue, 0);

        console.log("Executed by CEO:", ceo);
        console.log("  Morpho shares:", morphoShares);
        console.log("  deployed value:", deployedValue / 1e6, "USDC");

        vm.warp(block.timestamp + GRACE_PERIOD + 1);
        vault.settleEpoch();
        console.log("Epoch settled, current epoch:", vault.s_currentEpoch());

        vm.prank(depositor1);
        uint256 redeemed = vault.redeem(shares, depositor1, depositor1);
        console.log("Full lifecycle complete: redeemed", redeemed / 1e6);
    }

    // ══════════════════════════════════════════════════════════════
    //                CONVERT PERFORMANCE FEE TESTS
    // ══════════════════════════════════════════════════════════════

    function test_fork_convertPerformanceFee() public {
        _skipIfNoFork();
        _skipIfNoFunds();

        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1-fork", MIN_CEO_STAKE, agent1Id);
        vm.prank(agent2);
        vault.registerAgent("ipfs://agent2-fork", MIN_CEO_STAKE, agent2Id);

        ICEOVault.Action[] memory actions = _noopActions();
        vm.prank(agent1);
        vault.registerProposal(actions, "https://moltiverse.xyz/fork-test");
        vm.prank(agent2);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vault.execute(0, actions);

        address usdcWhale = 0x464Aec9Fa2a78F3312bb155e82f7D1b063A336BE;
        vm.prank(usdcWhale);
        IERC20(USDC_MONAD).transfer(address(vault), 1000e6);

        vm.warp(block.timestamp + GRACE_PERIOD + 1);
        vault.settleEpoch();

        uint256 pendingFee = vault.s_pendingPerformanceFeeUsdc();
        assertGt(pendingFee, 0, "Should have pending performance fee");

        MockFeeDex mockDex = new MockFeeDex();
        address ceoWhale = 0xC1923710468607b8B7DB38a6AfBB9B432744390c;
        vm.prank(ceoWhale);
        IERC20(CEO_TOKEN_MONAD).transfer(address(mockDex), 10_000e18);
        vault.setWhitelistedTarget(address(mockDex), true);

        ICEOVault.Action[] memory convActions = new ICEOVault.Action[](1);
        convActions[0] = ICEOVault.Action({
            target: address(mockDex),
            value: 0,
            data: abi.encodeCall(mockDex.swapMonForCeo, (CEO_TOKEN_MONAD, 100e18))
        });

        vm.prank(ceo);
        vault.convertPerformanceFee(convActions, 100e18);

        assertEq(vault.s_pendingPerformanceFeeUsdc(), 0);
        uint256 totalClaimable = vault.s_claimableFees(agent1) + vault.s_claimableFees(agent2);
        assertEq(totalClaimable, 100e18);

        console.log("convertPerformanceFee OK: cleared", pendingFee / 1e6, "USDC, distributed 100 CEO");
    }

    function test_fork_convertPerformanceFee_revert_noPendingFee() public {
        _skipIfNoFork();
        _skipIfNoFunds();

        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1-fork", MIN_CEO_STAKE, agent1Id);
        vm.prank(agent2);
        vault.registerAgent("ipfs://agent2-fork", MIN_CEO_STAKE, agent2Id);

        ICEOVault.Action[] memory actions = new ICEOVault.Action[](0);
        address ceo = vault.getTopAgent();

        vm.prank(ceo);
        vm.expectRevert(ICEOVault.NoPerformanceFeeToConvert.selector);
        vault.convertPerformanceFee(actions, 0);
    }

    // ══════════════════════════════════════════════════════════════
    //                 EXECUTE STRATEGY PROPOSAL TESTS
    // ══════════════════════════════════════════════════════════════

    function test_fork_execute_strategy_noop() public {
        _skipIfNoFork();
        _skipIfNoFunds();

        vm.prank(depositor1);
        vault.deposit(1000e6, depositor1);

        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1-fork", MIN_CEO_STAKE, agent1Id);
        vm.prank(agent2);
        vault.registerAgent("ipfs://agent2-fork", MIN_CEO_STAKE, agent2Id);

        ICEOVault.Action[] memory actions = _noopActions();
        vm.prank(agent1);
        vault.registerProposal(actions, "https://moltiverse.xyz/noop-strategy");

        vm.prank(agent2);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vault.execute(0, actions);

        ICEOVault.Proposal memory p = vault.getProposal(1, 0);
        assertTrue(p.executed);

        console.log("Execute no-op strategy OK");
    }

    function test_fork_execute_strategy_revert_actionsMismatch() public {
        _skipIfNoFork();
        _skipIfNoFunds();

        vm.prank(depositor1);
        vault.deposit(1000e6, depositor1);

        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1-fork", MIN_CEO_STAKE, agent1Id);
        vm.prank(agent2);
        vault.registerAgent("ipfs://agent2-fork", MIN_CEO_STAKE, agent2Id);

        ICEOVault.Action[] memory registeredActions = _deployActions(1000e6);
        vm.prank(agent1);
        vault.registerProposal(registeredActions, "https://moltiverse.xyz/strategy");

        vm.prank(agent2);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();
        ICEOVault.Action[] memory wrongActions = _deployActions(2000e6);

        vm.prank(ceo);
        vm.expectRevert(ICEOVault.ActionsMismatch.selector);
        vault.execute(0, wrongActions);
    }

    function test_fork_execute_strategy_multipleProposals_winnerExecutes() public {
        _skipIfNoFork();
        _skipIfNoFunds();

        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1-fork", MIN_CEO_STAKE, agent1Id);
        vm.prank(agent2);
        vault.registerAgent("ipfs://agent2-fork", MIN_CEO_STAKE, agent2Id);

        ICEOVault.Action[] memory actions1 = _deployActions(5000e6);
        ICEOVault.Action[] memory actions2 = _noopActions();

        vm.prank(agent1);
        vault.registerProposal(actions1, "https://moltiverse.xyz/strategy-a");
        vm.prank(agent2);
        vault.registerProposal(actions2, "https://moltiverse.xyz/strategy-b");

        vm.prank(agent1);
        vault.vote(0, true);
        vm.prank(agent2);
        vault.vote(0, true);

        (uint256 bestId,) = vault.getWinningProposal(1);
        assertEq(bestId, 0);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);

        address ceo = vault.getTopAgent();
        vm.prank(ceo);
        vault.execute(0, actions1);

        assertGt(IERC4626(MORPHO_USDC_VAULT).balanceOf(address(vault)), 0);
        assertGt(vault.getDeployedValue(), 0);

        console.log("Multiple proposals: winner (proposal 0) executed");
    }

    // ══════════════════════════════════════════════════════════════
    //                       HELPERS
    // ══════════════════════════════════════════════════════════════
    // ══════════════════════════════════════════════════════════════

    function _deployActions(uint256 amount) internal view returns (ICEOVault.Action[] memory) {
        ICEOVault.Action[] memory actions = new ICEOVault.Action[](2);
        actions[0] = ICEOVault.Action({
            target: USDC_MONAD,
            value: 0,
            data: abi.encodeWithSignature("approve(address,uint256)", MORPHO_USDC_VAULT, amount)
        });
        actions[1] = ICEOVault.Action({
            target: MORPHO_USDC_VAULT,
            value: 0,
            data: abi.encodeWithSignature("deposit(uint256,address)", amount, address(vault))
        });
        return actions;
    }

    function _noopActions() internal view returns (ICEOVault.Action[] memory) {
        ICEOVault.Action[] memory actions = new ICEOVault.Action[](1);
        actions[0] = ICEOVault.Action({
            target: USDC_MONAD,
            value: 0,
            data: abi.encodeWithSignature("approve(address,uint256)", MORPHO_USDC_VAULT, 0)
        });
        return actions;
    }
}

/// @dev Minimal interface for ERC-8004 register
interface IERC8004Identity {
    function register(string calldata agentURI) external returns (uint256 agentId);
    function ownerOf(uint256 tokenId) external view returns (address);
}
