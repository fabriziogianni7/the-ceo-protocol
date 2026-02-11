// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CEOVault} from "../src/CEOVault.sol";
import {CEOVaultSwapAdapter} from "../src/adapters/CEOVaultSwapAdapter.sol";
import {NadFunBuyAdapter} from "../src/adapters/NadFunBuyAdapter.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/// @notice Deploy The CEO Protocol v2 to Monad.
///
/// Usage:
///   forge script script/Deploy.s.sol:DeployScript \
///     --rpc-url $MONAD_RPC_URL \
///     --account <account_name> \
///     --broadcast
///
/// Environment variables:
///   MONAD_RPC_URL           — RPC endpoint
///   CEO_TOKEN_ADDRESS       — If set, use existing $CEO token (e.g., from nad.fun)
///   TREASURY_ADDRESS        — Treasury that receives entry fees (defaults to msg.sender)
///   ERC8004_IDENTITY        — ERC-8004 Identity Registry address
///   ERC8004_REPUTATION      — ERC-8004 Reputation Registry address (optional)
///   ERC8004_VALIDATION      — ERC-8004 Validation Registry address (optional)
contract DeployScript is Script {
    // USDC on Monad
    address constant USDC_MONAD = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
    // Uniswap V4 PoolManager on Monad
    address constant UNISWAP_POOL_MANAGER = 0x188d586Ddcf52439676Ca21A244753fA19F9Ea8e;
    address constant CEO_TOKEN_ADDRESS = 0xCA26f09831A15dCB9f9D47CE1cC2e3B086467777;
    address constant ERC8004_IDENTITY = 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432;
    address constant ERC8004_REPUTATION = 0x8004BAa17C55a88189AE136b182e5fdA19dE9b63;

    function run() external {
        address existingCeoToken = vm.envOr("CEO_TOKEN_ADDRESS", CEO_TOKEN_ADDRESS);
        address treasury = vm.envOr("TREASURY_ADDRESS", msg.sender);
        address erc8004Identity = vm.envOr("ERC8004_IDENTITY", ERC8004_IDENTITY);
        address erc8004Reputation = vm.envOr("ERC8004_REPUTATION", ERC8004_REPUTATION);
        address erc8004Validation = vm.envOr("ERC8004_VALIDATION", address(0));

        vm.startBroadcast();
    
        // Deploy CEOVault
        CEOVault vault = new CEOVault(
            IERC20(USDC_MONAD),         // USDC on Monad
            IERC20(existingCeoToken),   // $CEO token
            treasury,                   // entry fee recipient (buys $CEO from nad.fun)
            100,                        // entryFeeBps: 1%
            100,                        // performanceFeeBps: 1%
            50000e18,                   // minCeoStake: 50,000 $CEO
            1_000e6,                    // vaultCap: 1,000 USDC total (experimental)
            100e6,                      // maxDepositPerAddress: 100 USDC per address
            7 days,                     // epochDuration: 7d
            1 hours,                    // ceoGracePeriod: 1h
            100,                        // maxAgents
            20                          // maxActions per execute
        );

        console.log("Deployer:", msg.sender);
        console.log("Deployed CEOVault:", address(vault));
        console.log("Asset (USDC):", USDC_MONAD);
        console.log("Treasury:", treasury);

        // Configure ERC-8004 registries if provided
        if (erc8004Identity != address(0)) {
            vault.setERC8004Registries(erc8004Identity, erc8004Reputation, erc8004Validation);
            console.log("ERC-8004 Identity:", erc8004Identity);
            console.log("ERC-8004 Reputation:", erc8004Reputation);
            console.log("ERC-8004 Validation:", erc8004Validation);
        }

        // Deploy adapters for convertPerformanceFee (USDC→MON→$CEO via Uniswap V4 + nad.fun)
        CEOVaultSwapAdapter swapAdapter = new CEOVaultSwapAdapter(IPoolManager(UNISWAP_POOL_MANAGER));
        NadFunBuyAdapter nadFunBuyAdapter = new NadFunBuyAdapter();
        vault.setWhitelistedTarget(address(swapAdapter), true);
        vault.setWhitelistedTarget(address(nadFunBuyAdapter), true);
        console.log("CEOVaultSwapAdapter:", address(swapAdapter));
        console.log("NadFunBuyAdapter:", address(nadFunBuyAdapter));

        vm.stopBroadcast();
    }
}
