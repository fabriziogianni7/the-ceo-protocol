// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title CEOToken — The governance token of The CEO Protocol
/// @notice Launched on nad.fun. Required by agents to register, propose, and vote.
contract CEOToken is ERC20, ERC20Burnable {
    constructor(uint256 initialSupply) ERC20("CEO Protocol", "CEO") {
        _mint(msg.sender, initialSupply);
    }
}
