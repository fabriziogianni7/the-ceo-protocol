// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IERC8004Reputation — ERC-8004 Reputation Registry interface
/// @notice Standard interface for posting and fetching agent feedback signals.
///         See: https://eips.ethereum.org/EIPS/eip-8004
interface IERC8004Reputation {
    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        int128 value,
        uint8 valueDecimals,
        string indexed indexedTag1,
        string tag1,
        string tag2,
        string endpoint,
        string feedbackURI,
        bytes32 feedbackHash
    );

    event FeedbackRevoked(uint256 indexed agentId, address indexed clientAddress, uint64 indexed feedbackIndex);

    /// @notice Give feedback to an agent.
    /// @param agentId The ERC-8004 agent ID (NFT tokenId).
    /// @param value Fixed-point feedback value (e.g., score, yield).
    /// @param valueDecimals Decimals for the value (0-18).
    /// @param tag1 Primary tag (e.g., "proposalScore", "ceoPerformance").
    /// @param tag2 Secondary tag (e.g., epoch number).
    /// @param endpoint Optional endpoint URI.
    /// @param feedbackURI Optional URI to off-chain feedback details.
    /// @param feedbackHash Optional keccak256 hash of the feedbackURI content.
    function giveFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external;

    /// @notice Revoke previously given feedback.
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external;

    /// @notice Get aggregated summary for an agent filtered by clients and tags.
    function getSummary(uint256 agentId, address[] calldata clientAddresses, string calldata tag1, string calldata tag2)
        external
        view
        returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals);

    /// @notice Read a specific feedback entry.
    function readFeedback(uint256 agentId, address clientAddress, uint64 feedbackIndex)
        external
        view
        returns (int128 value, uint8 valueDecimals, string memory tag1, string memory tag2, bool isRevoked);

    /// @notice Get the Identity Registry address.
    function getIdentityRegistry() external view returns (address);
}
