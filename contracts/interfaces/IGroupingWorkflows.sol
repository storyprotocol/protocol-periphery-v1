// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { IStoryProtocolGateway as ISPG } from "../interfaces/IStoryProtocolGateway.sol";

/// @title Grouping Workflows Interface
interface IGroupingWorkflows {
    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP,
    /// attach Programmable IP License Terms to the registered IP, and add it to a group IP.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param groupId The ID of the group IP to add the newly registered IP.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param licenseTermsId The ID of the registered PIL terms that will be attached to the newly registered IP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param sigAddToGroup Signature data for addIp to the group IP via the Grouping Module.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIpAndAttachPILTermsAndAddToGroup(
        address spgNftContract,
        address groupId,
        address recipient,
        uint256 licenseTermsId,
        ISPG.IPMetadata calldata ipMetadata,
        ISPG.SignatureData calldata sigAddToGroup
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Register an NFT as IP with metadata, attach Programmable IP License Terms to the registered IP,
    /// and add it to a group IP.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param groupId The ID of the group IP to add the newly registered IP.
    /// @param licenseTermsId The ID of the registered PIL terms that will be attached to the newly registered IP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadataAndAttach Signature data for setAll (metadata) and attachLicenseTerms to the IP
    /// via the Core Metadata Module and Licensing Module.
    /// @param sigAddToGroup Signature data for addIp to the group IP via the Grouping Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIpAndAttachPILTermsAndAddToGroup(
        address nftContract,
        uint256 tokenId,
        address groupId,
        uint256 licenseTermsId,
        ISPG.IPMetadata calldata ipMetadata,
        ISPG.SignatureData calldata sigMetadataAndAttach,
        ISPG.SignatureData calldata sigAddToGroup
    ) external returns (address ipId);

    /// @notice Register a group IP with a group reward pool, register Programmable IP License Terms,
    /// attach it to the group IP, and add individual IPs to the group IP.
    /// @dev ipIds must be have the same PIL terms as the group IP.
    /// @param groupPool The address of the group reward pool.
    /// @param ipIds The IDs of the IPs to add to the newly registered group IP.
    /// @param groupIpTerms The PIL terms to be registered and attached to the newly registered group IP.
    /// @return groupId The ID of the newly registered group IP.
    /// @return groupLicenseTermsId The ID of the newly registered PIL terms.
    function registerGroupAndAttachPILTermsAndAddIps(
        address groupPool,
        address[] calldata ipIds,
        PILTerms calldata groupIpTerms
    ) external returns (address groupId, uint256 groupLicenseTermsId);
}
