// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { WorkflowStructs } from "../../lib/WorkflowStructs.sol";

/// @title License Attachment Workflows Interface
/// @notice Interface for IP license attachment workflows.
interface ILicenseAttachmentWorkflows {
    /// @notice Mint an NFT from a SPGNFT collection, register it as an IP, attach provided IP metadata,
    /// register Programmable IPLicense Terms (if unregistered), and attach it to the newly registered IP.
    /// @dev Requires caller to have the minter role or the SPG NFT to allow public minting.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param terms The PIL terms to be registered and attached to the newly registered IP.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    /// @return licenseTermsIds The IDs of the newly registered PIL terms.
    function mintAndRegisterIpAndAttachPILTerms(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        PILTerms[] calldata terms,
        bool allowDuplicates
    ) external returns (address ipId, uint256 tokenId, uint256[] memory licenseTermsIds);

    /// @notice Mint an NFT from a SPGNFT collection, register as an IP, attach provided IP metadata,
    /// and attach the provided license terms to the newly registered IP.
    /// @dev Requires caller to have the minter role or the SPG NFT to allow public minting.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param recipient The address of the recipient of the newly minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param licenseTemplates The addresses of the license templates used of the license terms to be attached.
    /// @param licenseTermsIds The IDs of the license terms to attach. The i th license terms ID must be a valid license
    ///        terms that was registered in the i th license template.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIpAndAttachLicenseTerms(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        address[] calldata licenseTemplates,
        uint256[] calldata licenseTermsIds,
        bool allowDuplicates
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Register a given NFT as an IP, attach provided IP metadata, and attach the provided license terms to the
    ///         newly registered IP.
    /// @dev Since IP Account is created in this function, we need signatures to allow this contract to set metadata
    ///      and attach PIL Terms to the newly created IP Account on behalf of the owner.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param licenseTemplates The addresses of the license templates used of the license terms to be attached.
    /// @param licenseTermsIds The IDs of the license terms to attach. The i th license terms ID must be a valid license
    ///        terms that was registered in the i th license template.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigsAttach Signature data for attachLicenseTerms to the IP via the Licensing Module.
    ///        The i th signature data is for attaching the i th license terms registered in the i th license template
    ///        to the IP.
    /// @return ipId The ID of the newly registered IP.
    function registerIpAndAttachLicenseTerms(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        address[] calldata licenseTemplates,
        uint256[] calldata licenseTermsIds,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData[] calldata sigsAttach
    ) external returns (address ipId);
}
