// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IERC8004Identity — ERC-8004 Identity Registry interface
/// @notice Minimal interface for the ERC-8004 Identity Registry (ERC-721 based).
///         Agents register to get an on-chain NFT identity with a URI pointing
///         to their registration file (capabilities, endpoints, supported trust models).
///         See: https://eips.ethereum.org/EIPS/eip-8004
interface IERC8004Identity {
    struct MetadataEntry {
        string metadataKey;
        bytes metadataValue;
    }

    event Registered(uint256 indexed agentId, string agentURI, address indexed owner);
    event URIUpdated(uint256 indexed agentId, string newURI, address indexed updatedBy);
    event MetadataSet(
        uint256 indexed agentId, string indexed indexedMetadataKey, string metadataKey, bytes metadataValue
    );

    /// @notice Register a new agent. Mints an ERC-721 NFT.
    function register(string calldata agentURI, MetadataEntry[] calldata metadata)
        external
        returns (uint256 agentId);

    /// @notice Register a new agent with just a URI.
    function register(string calldata agentURI) external returns (uint256 agentId);

    /// @notice Register a new agent (URI set later).
    function register() external returns (uint256 agentId);

    /// @notice Update the agent's URI.
    function setAgentURI(uint256 agentId, string calldata newURI) external;

    /// @notice Get on-chain metadata for an agent.
    function getMetadata(uint256 agentId, string memory metadataKey) external view returns (bytes memory);

    /// @notice Set on-chain metadata for an agent.
    function setMetadata(uint256 agentId, string memory metadataKey, bytes memory metadataValue) external;

    /// @notice Get the wallet address associated with an agent.
    function getAgentWallet(uint256 agentId) external view returns (address);

    /// @notice Get the owner of an agent NFT (standard ERC-721).
    function ownerOf(uint256 tokenId) external view returns (address);

    /// @notice Get the token URI (same as agentURI).
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
