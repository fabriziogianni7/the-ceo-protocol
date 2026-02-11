// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC8004Identity} from "../../src/erc8004/IERC8004Identity.sol";

/// @title MockERC8004Identity — Minimal mock of ERC-8004 Identity Registry for testing
contract MockERC8004Identity is IERC8004Identity {
    uint256 private _nextId = 1;

    mapping(uint256 => address) public owners;
    mapping(uint256 => string) public uris;
    mapping(uint256 => mapping(string => bytes)) public metadata;

    // ── Registration ──

    function register(string calldata agentURI, MetadataEntry[] calldata)
        external
        override
        returns (uint256 agentId)
    {
        agentId = _nextId++;
        owners[agentId] = msg.sender;
        uris[agentId] = agentURI;
        emit Registered(agentId, agentURI, msg.sender);
    }

    function register(string calldata agentURI) external override returns (uint256 agentId) {
        agentId = _nextId++;
        owners[agentId] = msg.sender;
        uris[agentId] = agentURI;
        emit Registered(agentId, agentURI, msg.sender);
    }

    function register() external override returns (uint256 agentId) {
        agentId = _nextId++;
        owners[agentId] = msg.sender;
        emit Registered(agentId, "", msg.sender);
    }

    // ── URI ──

    function setAgentURI(uint256 agentId, string calldata newURI) external override {
        require(owners[agentId] == msg.sender, "Not owner");
        uris[agentId] = newURI;
        emit URIUpdated(agentId, newURI, msg.sender);
    }

    // ── Metadata ──

    function getMetadata(uint256 agentId, string memory metadataKey)
        external
        view
        override
        returns (bytes memory)
    {
        return metadata[agentId][metadataKey];
    }

    function setMetadata(uint256 agentId, string memory metadataKey, bytes memory metadataValue) external override {
        require(owners[agentId] == msg.sender, "Not owner");
        metadata[agentId][metadataKey] = metadataValue;
        emit MetadataSet(agentId, metadataKey, metadataKey, metadataValue);
    }

    // ── Views ──

    function getAgentWallet(uint256 agentId) external view override returns (address) {
        return owners[agentId];
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        require(owners[tokenId] != address(0), "Agent does not exist");
        return owners[tokenId];
    }

    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        return uris[tokenId];
    }
}
