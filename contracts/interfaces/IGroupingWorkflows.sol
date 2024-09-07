// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { IStoryProtocolGateway as ISPG } from "../interfaces/IStoryProtocolGateway.sol";

/// @title Grouping Workflows Interface
interface IGroupingWorkflows {
    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP,
    /// attach license terms to the registered IP, and add it to a group IP.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param groupId The ID of the group IP to add the newly registered IP.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param licenseTermsId The ID of the registered license terms that will be attached to the new IP.
    /// @param licenseTemplate The address of the license template used for `licenseTermsId`.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param sigAddToGroup Signature data for addIp to the group IP via the Grouping Module.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIpAndAttachLicenseAndAddToGroup(
        address spgNftContract,
        address groupId,
        address recipient,
        uint256 licenseTermsId,
        address licenseTemplate,
        ISPG.IPMetadata calldata ipMetadata,
        ISPG.SignatureData calldata sigAddToGroup
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Register an NFT as IP with metadata, attach license terms to the registered IP,
    /// and add it to a group IP.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param groupId The ID of the group IP to add the newly registered IP.
    /// @param licenseTermsId The ID of the registered license terms that will be attached to the new IP.
    /// @param licenseTemplate The address of the license template used for `licenseTermsId`.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadataAndAttach Signature data for setAll (metadata) and attachLicenseTerms to the IP
    /// via the Core Metadata Module and Licensing Module.
    /// @param sigAddToGroup Signature data for addIp to the group IP via the Grouping Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIpAndAttachLicenseAndAddToGroup(
        address nftContract,
        uint256 tokenId,
        address groupId,
        uint256 licenseTermsId,
        address licenseTemplate,
        ISPG.IPMetadata calldata ipMetadata,
        ISPG.SignatureData calldata sigMetadataAndAttach,
        ISPG.SignatureData calldata sigAddToGroup
    ) external returns (address ipId);

    /// @notice Register a group IP with a group reward pool, attach license terms to the group IP,
    /// and add individual IPs to the group IP.
    /// @dev ipIds must be have the same license terms as the group IP.
    /// @param groupPool The address of the group reward pool.
    /// @param ipIds The IDs of the IPs to add to the newly registered group IP.
    /// @param licenseTermsId The ID of the registered license terms that will be attached to the new group IP.
    /// @param licenseTemplate The address of the license template used for `licenseTermsId`.
    /// @return groupId The ID of the newly registered group IP.
    function registerGroupAndAttachLicenseAndAddIps(
        address groupPool,
        address[] calldata ipIds,
        uint256 licenseTermsId,
        address licenseTemplate
    ) external returns (address groupId);
}
