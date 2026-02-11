// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CEOVault} from "../src/CEOVault.sol";
import {ICEOVault} from "../src/ICEOVault.sol";
import {CEOVaultSwapAdapter} from "../src/adapters/CEOVaultSwapAdapter.sol";
import {NadFunBuyAdapter} from "../src/adapters/NadFunBuyAdapter.sol";
import {SwapPlanner} from "./adapters/SwapPlanner.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {ActionConstants} from "@uniswap/v4-periphery/src/libraries/ActionConstants.sol";
import {IERC8004Identity} from "../src/erc8004/IERC8004Identity.sol";

/// @title CEOVaultForkUniswap — Integration test: convertPerformanceFee via USDC→MON→$CEO
/// @notice Flow: Uniswap V4 (USDC→MON) then nad.fun buy (MON→$CEO).
/// Run with: forge test --match-contract CEOVaultForkUniswap --fork-url $MONAD_RPC_URL
contract CEOVaultForkUniswapTest is Test {
    // ══════════════════════════════════════════════════════════════
    //                    MONAD MAINNET ADDRESSES
    // ══════════════════════════════════════════════════════════════

    address constant USDC_MONAD = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
    address constant CEO_TOKEN_MONAD = 0xCA26f09831A15dCB9f9D47CE1cC2e3B086467777;
    address constant ERC8004_IDENTITY = 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432;
    address constant ERC8004_REPUTATION = 0x8004BAa17C55a88189AE136b182e5fdA19dE9b63;
    address constant MORPHO_USDC_VAULT = 0xbeEFf443C3CbA3E369DA795002243BeaC311aB83;
    address constant UNISWAP_POOL_MANAGER = 0x188d586Ddcf52439676Ca21A244753fA19F9Ea8e;

    // nad.fun (Monad mainnet)
    address constant NADFUN_BONDING_CURVE_ROUTER = 0x6F6B8F1a20703309951a5127c45B49b1CD981A22;
    address constant NADFUN_DEX_ROUTER = 0x0B79d71AE99528D1dB24A4148b5f4F865cc2b137;
    address constant NADFUN_LENS = 0x7e78A8DE94f21804F7a17F4E8BF9EC2c872187ea;

    // USDC/MON pool (currency0=MON native, currency1=USDC). Pool id 0x18a9fc...
    PoolKey _sUsdcMonPoolKey;

    CEOVault public vault;
    CEOVaultSwapAdapter public swapAdapter;
    NadFunBuyAdapter public nadFunBuyAdapter;
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

        vault = new CEOVault(
            IERC20(USDC_MONAD),
            IERC20(CEO_TOKEN_MONAD),
            treasury,
            ENTRY_FEE_BPS,
            PERFORMANCE_FEE_BPS,
            MIN_CEO_STAKE,
            0,
            0,
            EPOCH_DURATION,
            GRACE_PERIOD,
            MAX_AGENTS,
            MAX_ACTIONS
        );

        vault.setERC8004Registries(ERC8004_IDENTITY, ERC8004_REPUTATION, address(0));
        vault.addYieldVault(MORPHO_USDC_VAULT);

        swapAdapter = new CEOVaultSwapAdapter(IPoolManager(UNISWAP_POOL_MANAGER));
        nadFunBuyAdapter = new NadFunBuyAdapter();
        vault.setWhitelistedTarget(address(swapAdapter), true);
        vault.setWhitelistedTarget(address(nadFunBuyAdapter), true);

        address usdcWhale = 0x464Aec9Fa2a78F3312bb155e82f7D1b063A336BE;
        address ceoWhale = 0xC1923710468607b8B7DB38a6AfBB9B432744390c;

        if (usdcWhale != address(0)) {
            uint256 usdcBalance = IERC20(USDC_MONAD).balanceOf(usdcWhale);
            if (usdcBalance >= 100_000e6) {
                vm.prank(usdcWhale);
                IERC20(USDC_MONAD).transfer(depositor1, 100_000e6);
            }
        }

        if (ceoWhale != address(0)) {
            uint256 ceoBalance = IERC20(CEO_TOKEN_MONAD).balanceOf(ceoWhale);
            if (ceoBalance >= MIN_CEO_STAKE * 3) {
                vm.prank(ceoWhale);
                IERC20(CEO_TOKEN_MONAD).transfer(agent1, MIN_CEO_STAKE);
                vm.prank(ceoWhale);
                IERC20(CEO_TOKEN_MONAD).transfer(agent2, MIN_CEO_STAKE);
            }
        }

        // Register ERC-8004 identities for agents (required for registerAgent)
        vm.prank(agent1);
        agent1Id = IERC8004Identity(ERC8004_IDENTITY).register("ipfs://agent1-fork-uniswap");
        vm.prank(agent2);
        agent2Id = IERC8004Identity(ERC8004_IDENTITY).register("ipfs://agent2-fork-uniswap");

        vm.prank(agent1);
        IERC20(CEO_TOKEN_MONAD).approve(address(vault), type(uint256).max);
        vm.prank(agent2);
        IERC20(CEO_TOKEN_MONAD).approve(address(vault), type(uint256).max);
        vm.prank(depositor1);
        IERC20(USDC_MONAD).approve(address(vault), type(uint256).max);

        // USDC/MON pool: currency0=MON (native), currency1=USDC (address(0) < USDC)
        _sUsdcMonPoolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(USDC_MONAD),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function _skipIfNoFork() internal {
        if (!forkConfigured) vm.skip(true);
    }

    function _skipIfNoFunds() internal {
        if (IERC20(USDC_MONAD).balanceOf(depositor1) < 10_000e6) vm.skip(true);
        if (IERC20(CEO_TOKEN_MONAD).balanceOf(agent1) < MIN_CEO_STAKE) vm.skip(true);
    }

    function _noopActions() internal pure returns (ICEOVault.Action[] memory) {
        ICEOVault.Action[] memory actions = new ICEOVault.Action[](1);
        // Must use allowed target (USDC); approve(non-zero, 0) is a harmless no-op (USDC rejects approve(0,0))
        actions[0] = ICEOVault.Action({
            target: USDC_MONAD,
            value: 0,
            data: abi.encodeWithSignature("approve(address,uint256)", address(1), 0)
        });
        return actions;
    }

    /// @notice Integration test: convertPerformanceFee via USDC→MON (Uniswap V4) → $CEO (nad.fun)
    function test_fork_convertPerformanceFee_uniswapV4_nadfun() public {
        _skipIfNoFork();
        _skipIfNoFunds();

        // Setup: deposit, execute no-op, simulate yield, settle
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

        // Step 1: USDC → MON via Uniswap V4 (output to NadFunBuyAdapter)
        // Pool: currency0=MON, currency1=USDC. Swap USDC→MON: zeroForOne=false
        uint256 amountIn = pendingFee;
        uint256 minCeoOut = 1; // Low for test; use Lens.getAmountIn for production

        bytes memory swapData = SwapPlanner.encodeExactInputSingle(
            _sUsdcMonPoolKey,
            false, // zeroForOne: USDC (currency1) → MON (currency0)
            uint128(amountIn),
            0, // no min MON out check (nad.fun will use whatever we get)
            address(nadFunBuyAdapter) // MON goes to NadFunBuyAdapter
        );

        // Try BondingCurveRouter first ($CEO on bonding curve); use NADFUN_DEX_ROUTER if graduated
        address nadFunRouter = NADFUN_BONDING_CURVE_ROUTER;

        ICEOVault.Action[] memory convActions = new ICEOVault.Action[](3);
        // Vault must approve adapter — V4 router uses transferFrom(vault, poolManager, amount)
        convActions[0] = ICEOVault.Action({
            target: USDC_MONAD,
            value: 0,
            data: abi.encodeCall(IERC20.approve, (address(swapAdapter), amountIn))
        });
        convActions[1] = ICEOVault.Action({
            target: address(swapAdapter),
            value: 0,
            data: abi.encodeCall(CEOVaultSwapAdapter.executeActions, (swapData))
        });
        convActions[2] = ICEOVault.Action({
            target: address(nadFunBuyAdapter),
            value: 0,
            data: abi.encodeCall(
                NadFunBuyAdapter.buyCeo,
                (nadFunRouter, CEO_TOKEN_MONAD, minCeoOut)
            )
        });

        vm.prank(ceo);
        vault.convertPerformanceFee(convActions, minCeoOut);

        assertEq(vault.s_pendingPerformanceFeeUsdc(), 0);
        uint256 totalClaimable = vault.s_claimableFees(agent1) + vault.s_claimableFees(agent2);
        assertGt(totalClaimable, 0);

        console.log("convertPerformanceFee USDC->MON->$CEO OK");
        console.log("  Total $CEO distributed to agents:", totalClaimable / 1e18);
    }

    /// @notice Integration test: execute() with Uniswap V4 swap (USDC→MON) as proposal action
    function test_fork_execute_uniswapV4_usdcToMon() public {
        _skipIfNoFork();
        _skipIfNoFunds();

        uint256 swapAmount = 1000e6;
        vm.prank(depositor1);
        vault.deposit(10_000e6, depositor1);

        vm.prank(agent1);
        vault.registerAgent("ipfs://agent1-fork", MIN_CEO_STAKE, agent1Id);
        vm.prank(agent2);
        vault.registerAgent("ipfs://agent2-fork", MIN_CEO_STAKE, agent2Id);

        bytes memory swapData = SwapPlanner.encodeExactInputSingle(
            _sUsdcMonPoolKey,
            false, // USDC → MON
            uint128(swapAmount),
            0,
            address(vault) // MON goes to vault
        );

        ICEOVault.Action[] memory actions = new ICEOVault.Action[](2);
        actions[0] = ICEOVault.Action({
            target: USDC_MONAD,
            value: 0,
            data: abi.encodeCall(IERC20.approve, (address(swapAdapter), swapAmount))
        });
        actions[1] = ICEOVault.Action({
            target: address(swapAdapter),
            value: 0,
            data: abi.encodeCall(CEOVaultSwapAdapter.executeActions, (swapData))
        });

        vm.prank(agent1);
        vault.registerProposal(actions, "https://moltiverse.xyz/fork-execute-swap");
        vm.prank(agent2);
        vault.vote(0, true);

        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        address ceo = vault.getTopAgent();

        uint256 vaultMonBefore = address(vault).balance;
        vm.prank(ceo);
        vault.execute(0, actions);
        uint256 vaultMonAfter = address(vault).balance;

        assertGt(vaultMonAfter, vaultMonBefore, "Vault should have received MON from swap");
        console.log("execute USDC->MON OK");
        console.log("  MON received by vault:", (vaultMonAfter - vaultMonBefore) / 1e18);
    }
}
