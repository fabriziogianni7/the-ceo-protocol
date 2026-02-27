// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IValueAdapter} from "../../src/IValueAdapter.sol";

/// @title MockValueAdapter — Mock for testing value adapter integration
contract MockValueAdapter is IValueAdapter {
    mapping(address => uint256) public deployedValue;

    function setDeployedValue(address vault, uint256 value) external {
        deployedValue[vault] = value;
    }

    function getDeployedValue(address vault) external view override returns (uint256) {
        return deployedValue[vault];
    }
}
