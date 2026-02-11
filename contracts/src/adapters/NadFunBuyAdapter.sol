// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title NadFunBuyAdapter
/// @notice Receives MON from Uniswap swap and buys $CEO on nad.fun.
/// @dev Uses BondingCurveRouter or DexRouter (both have same buy(BuyParams) payable interface).
interface INadFunRouter {
    struct BuyParams {
        uint256 amountOutMin;
        address token;
        address to;
        uint256 deadline;
    }

    function buy(BuyParams calldata params) external payable;
}

/// @notice Adapter that receives native MON and forwards to nad.fun buy.
/// @dev Hardened: output always goes to msg.sender (the vault). The caller
///      cannot redirect $CEO to an arbitrary address.
contract NadFunBuyAdapter {
    error NoMonToBuy();

    /// @notice Buy $CEO on nad.fun with received MON, send to caller (vault).
    /// @param router BondingCurveRouter or DexRouter (from Lens.getAmountOut)
    /// @param token $CEO token address
    /// @param amountOutMin Minimum $CEO (slippage)
    function buyCeo(address router, address token, uint256 amountOutMin) external {
        uint256 monBalance = address(this).balance;
        if (monBalance == 0) revert NoMonToBuy();

        INadFunRouter.BuyParams memory params = INadFunRouter.BuyParams({
            amountOutMin: amountOutMin,
            token: token,
            to: msg.sender, // always send $CEO back to caller (the vault)
            deadline: block.timestamp + 300
        });

        INadFunRouter(router).buy{value: monBalance}(params);
    }

    receive() external payable {}
}
