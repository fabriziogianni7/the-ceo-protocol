// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IValueAdapter} from "../../src/IValueAdapter.sol";
import {MockLending} from "./MockLending.sol";

/// @title MockLendingValueAdapter — Value adapter that reports vault's balance in MockLending
/// @dev Used to test totalAssets() including deployed value from lending protocols
contract MockLendingValueAdapter is IValueAdapter {
    MockLending public immutable lending;

    constructor(MockLending lending_) {
        lending = lending_;
    }

    function getDeployedValue(address vault) external view override returns (uint256) {
        return lending.balanceOf(vault);
    }
}
