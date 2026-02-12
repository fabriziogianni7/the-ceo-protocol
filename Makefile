# ═══════════════════════════════════════════════════════════════════════════════
# CEO Protocol — Makefile
# ═══════════════════════════════════════════════════════════════════════════════
#
# Usage: make <target>
#   Run from project root. All forge commands execute in contracts/
#
# Prerequisites:
#   - Foundry (forge, cast, anvil)
#   - MONAD_RPC_URL (required for deploy, test-fork, test-fork-uniswap)
#   - Account imported via: cast wallet import <ACCOUNT> --interactive
#
# Optional (for verification):
#   - MONAD_EXPLORER_API_KEY — Block explorer API key (e.g. Blockscout)
#   - MONAD_CHAIN_ID — Monad mainnet chain ID (default: 143)
#
# ═══════════════════════════════════════════════════════════════════════════════

CONTRACTS_DIR := contracts
ACCOUNT ?= the-ceo
ACCOUNT_ADDRESS ?= 0xC1923710468607b8B7DB38a6AfBB9B432744390c
MONAD_CHAIN_ID ?= 143
CEOVAULT_ADDRESS ?= 0x6133f5D45CCCC768B47e8065B3e4Da8e6566703d

# Load .env from contracts folder (MONAD_RPC_URL, MONAD_EXPLORER_API_KEY, etc.)
# Uses shell sourcing so values with :, =, etc. are handled correctly
include  $(CONTRACTS_DIR)/.env
export

# Workaround: skip system proxy (avoids "Socket operation on non-socket" / SCDynamicStore crash on macOS)
export NO_PROXY := *
export no_proxy := *

.PHONY: help build test test-fork test-fork-uniswap test-adapters \
	format fmt snapshot clean deploy deploy-dry deploy-verify \
	submodules install verify-vault verify-adapters

# ── Default target ──
help:
	@echo "CEO Protocol — Available targets:"
	@echo ""
	@echo "  Build & test:"
	@echo "    make build              Compile contracts"
	@echo "    make test               Run unit tests (no fork)"
	@echo "    make test-fork          Run fork tests (requires MONAD_RPC_URL)"
	@echo "    make test-fork-uniswap  Run Uniswap/nad.fun integration fork tests"
	@echo "    make test-adapters      Run adapter tests (CEOVaultSwapAdapter, NadFunBuyAdapter)"
	@echo ""
	@echo "  Code quality:"
	@echo "    make format             Format Solidity with forge fmt"
	@echo "    make snapshot           Create gas snapshot"
	@echo ""
	@echo "  Deployment:"
	@echo "    make deploy             Deploy to Monad (broadcast)"
	@echo "    make deploy-dry         Simulate deploy (no broadcast)"
	@echo "    make deploy-verify      Deploy + verify on block explorer (single call)"
	@echo ""
	@echo "  Setup:"
	@echo "    make submodules         Init/update git submodules"
	@echo "    make install            submodules + forge install"
	@echo ""
	@echo "  Verification (standalone):"
	@echo "    make verify-vault       Verify CEOVault (set CEOVAULT_ADDRESS)"
	@echo "    make verify-adapters    Verify adapters (set CEOVAULT_SWAP_ADAPTER, NADFUN_ADAPTER)"
	@echo ""
	@echo "  Other:"
	@echo "    make clean              Remove build artifacts"
	@echo ""
	@echo "  Environment:"
	@echo "    ACCOUNT=mykey make deploy   Use specific Foundry account"
	@echo "    MONAD_RPC_URL=...           Required for deploy and fork tests"

# ═══════════════════════════════════════════════════════════════════════════════
# Build & test
# ═══════════════════════════════════════════════════════════════════════════════

## Compile all contracts (Foundry + via_ir)
build:
	@cd $(CONTRACTS_DIR) && forge build

## Run unit tests (CEOVault.t.sol) — no RPC required
test:
	@cd $(CONTRACTS_DIR) && forge test --match-contract CEOVaultTest

## Run fork tests against Monad mainnet — requires MONAD_RPC_URL
test-fork:
	@cd $(CONTRACTS_DIR) && forge test --match-contract CEOVaultFork --fork-url "$${MONAD_RPC_URL}"

## Run Uniswap V4 + nad.fun integration fork tests — requires MONAD_RPC_URL
test-fork-uniswap:
	@cd $(CONTRACTS_DIR) && forge test --match-contract CEOVaultForkUniswap --fork-url "$${MONAD_RPC_URL}"

## Run adapter tests (CEOVaultSwapAdapter, NadFunBuyAdapter)
test-adapters:
	@cd $(CONTRACTS_DIR) && forge test --match-contract CEOVaultSwapAdapterTest NadFunBuyAdapterTest

## Run all tests (unit + adapters; no fork)
test-all:
	@cd $(CONTRACTS_DIR) && forge test --no-match-contract 'CEOVaultFork*'

# ═══════════════════════════════════════════════════════════════════════════════
# Code quality
# ═══════════════════════════════════════════════════════════════════════════════

## Format Solidity (forge fmt)
format: fmt
fmt:
	@cd $(CONTRACTS_DIR) && forge fmt

## Create gas snapshot in contracts/.gas-snapshot
snapshot:
	@cd $(CONTRACTS_DIR) && forge snapshot

# ═══════════════════════════════════════════════════════════════════════════════
# Deployment
# ═══════════════════════════════════════════════════════════════════════════════

## Simulate deployment (no broadcast) — checks constructor args & gas
deploy-dry:
	@cd $(CONTRACTS_DIR) && forge script script/Deploy.s.sol:DeployScript \
		--rpc-url "$${MONAD_RPC_URL}" \
		--account $(ACCOUNT)

## Deploy to Monad mainnet — requires MONAD_RPC_URL and funded account
deploy:
	@cd $(CONTRACTS_DIR) && forge script script/Deploy.s.sol:DeployScript \
		--rpc-url "$${MONAD_RPC_URL}" \
		--account $(ACCOUNT) \
		--broadcast

## Deploy + verify in one call — requires MONAD_RPC_URL, MONAD_EXPLORER_API_KEY
## Verification runs immediately after broadcast; API key from foundry.toml [etherscan.monad]
deploy-verify:
	@cd $(CONTRACTS_DIR) && forge script script/Deploy.s.sol:DeployScript \
		--rpc-url "$${MONAD_RPC_URL}" \
		--account $(ACCOUNT) \
		--sender $(ACCOUNT_ADDRESS) \
		--broadcast \
		--verify \
    	--verifier etherscan \
		--chain 143 \
    	--etherscan-api-key $${MONAD_EXPLORER_API_KEY} 

# ═══════════════════════════════════════════════════════════════════════════════
# Setup
# ═══════════════════════════════════════════════════════════════════════════════

## Initialize git submodules (e.g. v4-periphery)
submodules:
	@git submodule update --init --recursive

## Full setup: submodules + forge install
install: submodules
	@cd $(CONTRACTS_DIR) && forge install

# ═══════════════════════════════════════════════════════════════════════════════
# Standalone verification (post-deploy)
# ═══════════════════════════════════════════════════════════════════════════════

## Verify CEOVault — set CEOVAULT_ADDRESS to deployed address
verify-vault:
	@test -n "$(CEOVAULT_ADDRESS)" || (echo "Set CEOVAULT_ADDRESS"; exit 1)
	@cd $(CONTRACTS_DIR) && forge verify-contract $(CEOVAULT_ADDRESS) src/CEOVault.sol:CEOVault \
	    --chain 143 \
    	--verifier etherscan \
    	--etherscan-api-key $${MONAD_EXPLORER_API_KEY} --watch



	
		

## Verify adapters — set CEOVAULT_SWAP_ADAPTER and NADFUN_ADAPTER
verify-adapters:
	@test -n "$(CEOVAULT_SWAP_ADAPTER)" || (echo "Set CEOVAULT_SWAP_ADAPTER"; exit 1)
	@test -n "$(NADFUN_ADAPTER)" || (echo "Set NADFUN_ADAPTER"; exit 1)
	@cd $(CONTRACTS_DIR) && forge verify-contract $(CEOVAULT_SWAP_ADAPTER) src/adapters/CEOVaultSwapAdapter.sol:CEOVaultSwapAdapter \
		--chain monad
	@cd $(CONTRACTS_DIR) && forge verify-contract $(NADFUN_ADAPTER) src/adapters/NadFunBuyAdapter.sol:NadFunBuyAdapter \
		--chain monad

# ═══════════════════════════════════════════════════════════════════════════════
# Clean
# ═══════════════════════════════════════════════════════════════════════════════

## Remove build artifacts and cache
clean:
	@cd $(CONTRACTS_DIR) && forge clean
