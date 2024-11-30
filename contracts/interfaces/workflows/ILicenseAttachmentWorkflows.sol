// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import { WorkflowStructs } from "../../lib/WorkflowStructs.sol";

/// @title License Attachment Workflows Interface
/// @notice Interface for IP license attachment workflows.
interface ILicenseAttachmentWorkflows {
    /// @notice Register Programmable IP License Terms (if unregistered) and attach it to IP.
    /// @param ipId The ID of the IP.
    /// @param licenseTermsData The PIL terms and licensing configuration data to be attached to the IP.
    /// @param sigAttachAndConfig Signature data for attachLicenseTerms and setLicensingConfig to the IP via the Licensing Module.
    /// @return licenseTermsIds The IDs of the newly registered PIL terms.
    function registerPILTermsAndAttach(
        address ipId,
        WorkflowStructs.LicenseTermsData[] calldata licenseTermsData,
        WorkflowStructs.SignatureData calldata sigAttachAndConfig
    ) external returns (uint256[] memory licenseTermsIds);

    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP,
    /// register Programmable IPLicense
    /// Terms (if unregistered), and attach it to the registered IP.
    /// @dev Requires caller to have the minter role or the SPG NFT to allow public minting.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param licenseTermsData The PIL terms and licensing configuration data to be attached to the IP.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    /// @return licenseTermsIds The IDs of the newly registered PIL terms.
    function mintAndRegisterIpAndAttachPILTerms(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.LicenseTermsData[] calldata licenseTermsData,
        bool allowDuplicates
    ) external returns (address ipId, uint256 tokenId, uint256[] memory licenseTermsIds);

    /// @notice Register a given NFT as an IP and attach Programmable IP License Terms.
    /// @dev Because IP Account is created in this function, we need to set the permission via signature to allow this
    /// contract to attach PIL Terms to the newly created IP Account in the same function.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param licenseTermsData The PIL terms and licensing configuration data to be attached to the IP.
    /// @param sigMetadataAndAttachAndConfig Signature data for setAll (metadata), attachLicenseTerms, and
    /// setLicensingConfig to the IP via the Core Metadata Module and Licensing Module.
    /// @return ipId The ID of the newly registered IP.
    /// @return licenseTermsIds The IDs of the newly registered PIL terms.
    function registerIpAndAttachPILTerms(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.LicenseTermsData[] calldata licenseTermsData,
        WorkflowStructs.SignatureData calldata sigMetadataAndAttachAndConfig
    ) external returns (address ipId, uint256[] memory licenseTermsIds);
}
