// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { WorkflowStructs } from "../lib/WorkflowStructs.sol";

/// @title Registration Workflows Interface
/// @notice Interface for IP Registration Workflows.
interface IRegistrationWorkflows {
    /// @notice Event emitted when a new NFT collection is created.
    /// @param spgNftContract The address of the SPGNFT collection.
    event CollectionCreated(address indexed spgNftContract);

    /// @notice Creates a new NFT collection to be used by SPG.
    /// @param name The name of the collection.
    /// @param symbol The symbol of the collection.
    /// @param maxSupply The maximum supply of the collection.
    /// @param mintFee The cost to mint an NFT from the collection.
    /// @param mintFeeToken The token to be used for mint payment.
    /// @param mintFeeRecipient The address to receive mint fees.
    /// @param owner The owner of the collection. Zero address indicates no owner.
    /// @param mintOpen Whether the collection is open for minting on creation. Configurable by the owner.
    /// @param isPublicMinting If true, anyone can mint from the collection. If false, only the addresses with the
    /// minter role can mint. Configurable by the owner.
    /// @return spgNftContract The address of the newly created SPGNFT collection.
    function createCollection(
        string calldata name,
        string calldata symbol,
        uint32 maxSupply,
        uint256 mintFee,
        address mintFeeToken,
        address mintFeeRecipient,
        address owner,
        bool mintOpen,
        bool isPublicMinting
    ) external returns (address spgNftContract);

    /// @notice Mint an NFT from a SPGNFT collection and register it with metadata as an IP.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIp(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Registers an NFT as IP with metadata.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIp(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.SignatureData calldata sigMetadata
    ) external returns (address ipId);
}
