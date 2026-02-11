// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {V4Router} from "@uniswap/v4-periphery/src/V4Router.sol";
import {ReentrancyLock} from "@uniswap/v4-periphery/src/base/ReentrancyLock.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

/// @title CEOVaultSwapAdapter
/// @notice Adapter that allows CEOVault to swap USDC → output token via Uniswap V4.
/// @dev Implements IUnlockCallback via V4Router. When called by the vault, pulls input from
///      msg.sender (vault) and sends output to msg.sender.
contract CEOVaultSwapAdapter is V4Router, ReentrancyLock {
    constructor(IPoolManager _poolManager) V4Router(_poolManager) {}

    /// @notice Execute encoded swap actions (SWAP_EXACT_IN_SINGLE + SETTLE_ALL + TAKE_ALL).
    /// @param data abi.encode(actions, params) from Planner.finalizeSwap
    function executeActions(bytes calldata data) external payable isNotLocked {
        _executeActions(data);
    }

    function _pay(Currency token, address payer, uint256 amount) internal override {
        if (payer == address(this)) {
            token.transfer(address(poolManager), amount);
        } else {
            SafeTransferLib.safeTransferFrom(
                ERC20(Currency.unwrap(token)), payer, address(poolManager), amount
            );
        }
    }

    function msgSender() public view override returns (address) {
        return _getLocker();
    }

    receive() external payable {}
}
