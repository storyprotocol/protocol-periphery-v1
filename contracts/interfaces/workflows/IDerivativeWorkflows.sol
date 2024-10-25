// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { WorkflowStructs } from "../../lib/WorkflowStructs.sol";

/// @title Derivative Workflows Interface
/// @notice Interface for IP derivative workflows.
interface IDerivativeWorkflows {
    /// @notice Mint an NFT from a SPGNFT collection and register it as a derivative IP without license tokens.
    /// @dev Requires caller to have the minter role or the SPG NFT to allow public minting.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param derivData The derivative data to be used for registerDerivative.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param recipient The address to receive the minted NFT.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIpAndMakeDerivative(
        address spgNftContract,
        WorkflowStructs.MakeDerivative calldata derivData,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        address recipient,
        bool allowDuplicates
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Register the given NFT as a derivative IP with metadata without license tokens.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param derivData The derivative data to be used for registerDerivative.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigRegister Signature data for registerDerivative for the IP via the Licensing Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIpAndMakeDerivative(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.MakeDerivative calldata derivData,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData calldata sigRegister
    ) external returns (address ipId);

    /// @notice Mint an NFT from a SPGNFT collection and register it as a derivative IP using license tokens.
    /// @dev Requires caller to have the minter role or the SPG NFT to allow public minting. Caller must
    /// own the license tokens and have approved DerivativeWorkflows to transfer them.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param licenseTokenIds The IDs of the license tokens to be burned for linking the IP to parent IPs.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param recipient The address to receive the minted NFT.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIpAndMakeDerivativeWithLicenseTokens(
        address spgNftContract,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        address recipient,
        bool allowDuplicates
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Register the given NFT as a derivative IP using license tokens.
    /// @dev Caller must own the license tokens and have approved DerivativeWorkflows to transfer them.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param licenseTokenIds The IDs of the license tokens to be burned for linking the IP to parent IPs.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigRegister Signature data for registerDerivativeWithLicenseTokens for the IP via the Licensing Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIpAndMakeDerivativeWithLicenseTokens(
        address nftContract,
        uint256 tokenId,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData calldata sigRegister
    ) external returns (address ipId);
}
