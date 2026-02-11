// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC8004Reputation} from "../../src/erc8004/IERC8004Reputation.sol";

/// @title MockERC8004Reputation — Minimal mock of ERC-8004 Reputation Registry for testing
/// @dev Simplified to avoid stack-too-deep issues. Production impl compiles with --via-ir.
contract MockERC8004Reputation is IERC8004Reputation {
    address public identityRegistry;

    struct StoredFeedback {
        uint256 agentId;
        int128 value;
        uint8 valueDecimals;
        bool isRevoked;
    }

    // Simple array of all feedback
    StoredFeedback[] public allFeedback;

    // Last feedback data (for test assertions)
    uint256 public lastAgentId;
    int128 public lastValue;
    string public lastTag1;
    string public lastTag2;

    constructor(address _identityRegistry) {
        identityRegistry = _identityRegistry;
    }

    function totalFeedbackCount() external view returns (uint256) {
        return allFeedback.length;
    }

    function giveFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata,
        string calldata,
        bytes32
    ) external override {
        allFeedback.push(
            StoredFeedback({agentId: agentId, value: value, valueDecimals: valueDecimals, isRevoked: false})
        );

        lastAgentId = agentId;
        lastValue = value;
        lastTag1 = tag1;
        lastTag2 = tag2;
    }

    function revokeFeedback(uint256, uint64) external override {
        // No-op for mock
    }

    function getSummary(uint256, address[] calldata, string calldata, string calldata)
        external
        pure
        override
        returns (uint64, int128, uint8)
    {
        return (0, 0, 0);
    }

    function readFeedback(uint256, address, uint64)
        external
        pure
        override
        returns (int128, uint8, string memory, string memory, bool)
    {
        return (0, 0, "", "", false);
    }

    function getIdentityRegistry() external view override returns (address) {
        return identityRegistry;
    }
}
