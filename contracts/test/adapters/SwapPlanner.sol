// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {ActionConstants} from "@uniswap/v4-periphery/src/libraries/ActionConstants.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";

/// @notice Builds Uniswap V4 swap calldata for CEOVaultSwapAdapter.executeActions
library SwapPlanner {
    /// @notice Encode exact-input single-hop swap for vault (msg.sender receives output)
    /// @param poolKey Pool key (currency0 < currency1)
    /// @param zeroForOne true if swapping currency0 -> currency1
    /// @param amountIn Input amount
    /// @param amountOutMinimum Slippage tolerance (0 = no check)
    function encodeExactInputSingle(
        PoolKey memory poolKey,
        bool zeroForOne,
        uint128 amountIn,
        uint128 amountOutMinimum,
        address takeRecipient
    ) internal pure returns (bytes memory) {
        IV4Router.ExactInputSingleParams memory swapParams = IV4Router.ExactInputSingleParams({
            poolKey: poolKey,
            zeroForOne: zeroForOne,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            hookData: bytes("")
        });

        Currency currencyIn = zeroForOne ? poolKey.currency0 : poolKey.currency1;
        Currency currencyOut = zeroForOne ? poolKey.currency1 : poolKey.currency0;

        bytes memory actions;
        bytes[] memory params;

        if (takeRecipient == ActionConstants.MSG_SENDER) {
            // SWAP_EXACT_IN_SINGLE (0x06), SETTLE_ALL (0x0c), TAKE_ALL (0x0f)
            actions = hex"060c0f";
            params = new bytes[](3);
            params[0] = abi.encode(swapParams);
            params[1] = abi.encode(currencyIn, type(uint256).max);
            params[2] = abi.encode(currencyOut, uint256(0));
        } else {
            // SWAP_EXACT_IN_SINGLE, SETTLE, TAKE
            actions = hex"060b0e";
            params = new bytes[](3);
            params[0] = abi.encode(swapParams);
            params[1] = abi.encode(currencyIn, ActionConstants.OPEN_DELTA, true);
            params[2] = abi.encode(currencyOut, takeRecipient, ActionConstants.OPEN_DELTA);
        }

        return abi.encode(actions, params);
    }
}
