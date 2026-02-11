// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {INadFunRouter} from "../../src/adapters/NadFunBuyAdapter.sol";

/// @notice Mock nad.fun router for unit tests. Records buy() calls and optionally sends CEO to recipient.
contract MockNadFunRouter is INadFunRouter {
    event BuyCalled(uint256 value, uint256 amountOutMin, address token, address to, uint256 deadline);

    uint256 public s_lastValue;
    uint256 public s_lastAmountOutMin;
    address public s_lastToken;
    address public s_lastTo;
    uint256 public s_lastDeadline;

    address public s_ceoToken;

    constructor(address ceoToken_) {
        s_ceoToken = ceoToken_;
    }

    function buy(INadFunRouter.BuyParams calldata params) external payable override {
        s_lastValue = msg.value;
        s_lastAmountOutMin = params.amountOutMin;
        s_lastToken = params.token;
        s_lastTo = params.to;
        s_lastDeadline = params.deadline;
        emit BuyCalled(msg.value, params.amountOutMin, params.token, params.to, params.deadline);

        // Simulate: mint CEO to recipient (if we have a CEOToken that allows minting, or use transfer)
        if (s_ceoToken != address(0) && params.to != address(0) && msg.value > 0) {
            uint256 toMint = msg.value * 1000; // 1:1000 ratio for test
            try IERC20(s_ceoToken).transfer(params.to, toMint) {} catch {}
        }
    }
}
