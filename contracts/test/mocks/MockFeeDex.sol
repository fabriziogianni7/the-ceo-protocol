// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockFeeDex {
    using SafeERC20 for IERC20;

    error PayoutFailed();

    receive() external payable {}

    function payoutProfit(uint256 amount) external {
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert PayoutFailed();
    }

    function swapMonForCeo(address ceoToken, uint256 ceoOut) external payable returns (uint256) {
        IERC20(ceoToken).safeTransfer(msg.sender, ceoOut);
        return ceoOut;
    }
}
