// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC8004Validation} from "../../src/erc8004/IERC8004Validation.sol";

/// @title MockERC8004Validation — Minimal mock of ERC-8004 Validation Registry for testing
contract MockERC8004Validation is IERC8004Validation {
    address public identityRegistryAddr;

    struct ValidationEntry {
        address validatorAddress;
        uint256 agentId;
        uint8 response;
        bytes32 responseHash;
        string tag;
        uint256 lastUpdate;
    }

    mapping(bytes32 => ValidationEntry) public validations;

    // Track requests for test assertions
    bytes32 public lastRequestHash;
    uint256 public lastAgentId;
    address public lastValidatorAddress;
    string public lastRequestURI;
    uint256 public totalRequests;

    constructor(address _identityRegistry) {
        identityRegistryAddr = _identityRegistry;
    }

    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestURI,
        bytes32 requestHash
    ) external override {
        validations[requestHash] = ValidationEntry({
            validatorAddress: validatorAddress,
            agentId: agentId,
            response: 0,
            responseHash: bytes32(0),
            tag: "",
            lastUpdate: block.timestamp
        });

        lastRequestHash = requestHash;
        lastAgentId = agentId;
        lastValidatorAddress = validatorAddress;
        lastRequestURI = requestURI;
        totalRequests++;

        emit ValidationRequest(validatorAddress, agentId, requestURI, requestHash);
    }

    function validationResponse(
        bytes32 requestHash,
        uint8 response,
        string calldata responseURI,
        bytes32 responseHash,
        string calldata tag
    ) external override {
        ValidationEntry storage v = validations[requestHash];
        require(v.validatorAddress == msg.sender, "Not the validator");
        v.response = response;
        v.responseHash = responseHash;
        v.tag = tag;
        v.lastUpdate = block.timestamp;

        emit ValidationResponse(msg.sender, v.agentId, requestHash, response, responseURI, responseHash, tag);
    }

    function getValidationStatus(bytes32 requestHash)
        external
        view
        override
        returns (
            address validatorAddress,
            uint256 agentId,
            uint8 response,
            bytes32 responseHash,
            string memory tag,
            uint256 lastUpdate
        )
    {
        ValidationEntry storage v = validations[requestHash];
        return (v.validatorAddress, v.agentId, v.response, v.responseHash, v.tag, v.lastUpdate);
    }

    function getIdentityRegistry() external view override returns (address) {
        return identityRegistryAddr;
    }
}
