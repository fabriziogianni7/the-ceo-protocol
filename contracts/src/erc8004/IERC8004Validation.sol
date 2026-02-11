// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IERC8004Validation — ERC-8004 Validation Registry interface
/// @notice Enables agents to request verification of their work and validators
///         to provide responses tracked on-chain.
///         See: https://eips.ethereum.org/EIPS/eip-8004
interface IERC8004Validation {
    event ValidationRequest(
        address indexed validatorAddress, uint256 indexed agentId, string requestURI, bytes32 indexed requestHash
    );

    event ValidationResponse(
        address indexed validatorAddress,
        uint256 indexed agentId,
        bytes32 indexed requestHash,
        uint8 response,
        string responseURI,
        bytes32 responseHash,
        string tag
    );

    /// @notice Request validation for an agent's work.
    /// @param validatorAddress The validator contract to handle this request.
    /// @param agentId The ERC-8004 agent ID.
    /// @param requestURI Off-chain data with all info needed for validation.
    /// @param requestHash keccak256 commitment of the request payload.
    function validationRequest(address validatorAddress, uint256 agentId, string calldata requestURI, bytes32 requestHash)
        external;

    /// @notice Respond to a validation request.
    /// @param requestHash The original request hash.
    /// @param response Value 0-100 (0=failed, 100=passed, intermediate for spectrum).
    /// @param responseURI Optional off-chain evidence.
    /// @param responseHash Optional commitment to responseURI content.
    /// @param tag Optional categorization tag.
    function validationResponse(
        bytes32 requestHash,
        uint8 response,
        string calldata responseURI,
        bytes32 responseHash,
        string calldata tag
    ) external;

    /// @notice Get validation status for a request.
    function getValidationStatus(bytes32 requestHash)
        external
        view
        returns (
            address validatorAddress,
            uint256 agentId,
            uint8 response,
            bytes32 responseHash,
            string memory tag,
            uint256 lastUpdate
        );

    /// @notice Get the Identity Registry address.
    function getIdentityRegistry() external view returns (address);
}
