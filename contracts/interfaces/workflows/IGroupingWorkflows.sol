// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { WorkflowStructs } from "../../lib/WorkflowStructs.sol";

/// @title Grouping Workflows Interface
/// @notice Interface for IP grouping workflows.
interface IGroupingWorkflows {
    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP,
    /// attach license terms to the registered IP, and add it to a group IP.
    /// @dev Requires caller to have the minter role or the SPG NFT to allow public minting.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param groupId The ID of the group IP to add the newly registered IP.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param licenseInfo The information of the license terms that will be attached to the new IP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param sigAddToGroup Signature data for addIp to the group IP via the Grouping Module.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIpAndAttachLicenseAndAddToGroup(
        address spgNftContract,
        address groupId,
        address recipient,
        WorkflowStructs.LicenseInfo[] calldata licenseInfo,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.SignatureData calldata sigAddToGroup,
        bool allowDuplicates
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Register an NFT as IP with metadata, attach license terms to the registered IP,
    /// and add it to a group IP.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param groupId The ID of the group IP to add the newly registered IP.
    /// @param licenseInfo The information of the license terms that will be attached to the new IP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata).
    /// @param sigsAttach Signature data for attachLicenseTerms to the IP via the Licensing Module.
    ///        The i th signature data is for attaching the i th license terms registered
    ///        in the i th license template to the IP.
    /// @param sigAddToGroup Signature data for addIp to the group IP via the Grouping Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIpAndAttachLicenseAndAddToGroup(
        address nftContract,
        uint256 tokenId,
        address groupId,
        WorkflowStructs.LicenseInfo[] calldata licenseInfo,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData[] calldata sigsAttach,
        WorkflowStructs.SignatureData calldata sigAddToGroup
    ) external returns (address ipId);

    /// @notice Register a group IP with a group reward pool and attach license terms to the group IP
    /// @param groupPool The address of the group reward pool.
    /// @param licenseInfo The information of the license terms that will be attached to the new group IP.
    /// @return groupId The ID of the newly registered group IP.
    function registerGroupAndAttachLicense(
        address groupPool,
        WorkflowStructs.LicenseInfo calldata licenseInfo
    ) external returns (address groupId);

    /// @notice Register a group IP with a group reward pool, attach license terms to the group IP,
    /// and add individual IPs to the group IP.
    /// @dev ipIds must be have the same license terms as the group IP.
    /// @param groupPool The address of the group reward pool.
    /// @param ipIds The IDs of the IPs to add to the newly registered group IP.
    /// @param licenseInfo The information of the license terms that will be attached to the new group IP.
    /// @return groupId The ID of the newly registered group IP.
    function registerGroupAndAttachLicenseAndAddIps(
        address groupPool,
        address[] calldata ipIds,
        WorkflowStructs.LicenseInfo calldata licenseInfo
    ) external returns (address groupId);

    /// @notice Collect royalties for the entire group and distribute the rewards to each member IP's royalty vault
    /// @param groupIpId The ID of the group IP.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim.
    /// @param memberIpIds The IDs of the member IPs to distribute the rewards to.
    /// @return collectedRoyalties The amounts of royalties collected for each currency token.
    function collectRoyaltiesAndClaimReward(
        address groupIpId,
        address[] calldata currencyTokens,
        address[] calldata memberIpIds
    ) external returns (uint256[] memory collectedRoyalties);
}
