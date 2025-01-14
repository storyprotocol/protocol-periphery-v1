// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ISPGNFT } from "../../interfaces/ISPGNFT.sol";
import { WorkflowStructs } from "../../lib/WorkflowStructs.sol";

/// @title Registration Workflows Interface
/// @notice Interface for IP Registration Workflows.
interface IRegistrationWorkflows {
    /// @notice Event emitted when a new NFT collection is created.
    /// @param spgNftContract The address of the SPGNFT collection.
    event CollectionCreated(address indexed spgNftContract);

    /// @notice Creates a new NFT collection to be used by SPG.
    /// @param spgNftInitParams The init params for the SPGNFT collection. See {ISPGNFT-InitParams}.
    /// @return spgNftContract The address of the newly created SPGNFT collection.
    function createCollection(ISPGNFT.InitParams calldata spgNftInitParams) external returns (address spgNftContract);

    /// @notice Mint an NFT from a SPGNFT collection and register it with metadata as an IP.
    /// @dev Requires caller to have the minter role or the SPG NFT to allow public minting.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// If a duplicate is found, returns existing token Id and IP Id instead of minting/registering a new one.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIp(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        bool allowDuplicates
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
