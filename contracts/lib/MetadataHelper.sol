// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";

import { IStoryProtocolGateway as ISPG } from "../interfaces/IStoryProtocolGateway.sol";

import { PermissionHelper } from "./PermissionHelper.sol";

/// @title Periphery Metadata Helper Library
/// @notice Library for all metadata related helper functions for Periphery contracts.
library MetadataHelper {
    /// @dev Sets the permission for SPG to set the metadata for the given IP, and the metadata for the given IP if
    /// metadata is non-empty and sets the metadata via signature.
    /// @param ipId The ID of the IP.
    /// @param coreMetadataModule The address of the Core Metadata Module.
    /// @param accessController The address of the Access Controller.
    /// @param ipMetadata The metadata to set.
    /// @param sigData Signature data for setAll for this IP by SPG via the Core Metadata Module.
    function setMetadataWithSig(
        address ipId,
        address coreMetadataModule,
        address accessController,
        ISPG.IPMetadata calldata ipMetadata,
        ISPG.SignatureData calldata sigData
    ) internal {
        if (sigData.signer != address(0) && sigData.deadline != 0 && sigData.signature.length != 0) {
            PermissionHelper.setPermissionForModule({
                ipId: ipId,
                module: coreMetadataModule,
                accessController: accessController,
                selector: ICoreMetadataModule.setAll.selector,
                sigData: sigData
            });
        }
        setMetadata(ipId, coreMetadataModule, ipMetadata);
    }

    /// @dev Sets the metadata for the given IP if metadata is non-empty.
    /// @dev Sets the metadata for the given IP if metadata is non-empty.
    /// @param ipId The ID of the IP.
    /// @param coreMetadataModule The address of the Core Metadata Module.
    /// @param ipMetadata The metadata to set.
    function setMetadata(address ipId, address coreMetadataModule, ISPG.IPMetadata calldata ipMetadata) internal {
        if (
            keccak256(abi.encodePacked(ipMetadata.ipMetadataURI)) != keccak256("") ||
            ipMetadata.ipMetadataHash != bytes32(0) ||
            ipMetadata.nftMetadataHash != bytes32(0)
        ) {
            ICoreMetadataModule(coreMetadataModule).setAll(
                ipId,
                ipMetadata.ipMetadataURI,
                ipMetadata.ipMetadataHash,
                ipMetadata.nftMetadataHash
            );
        }
    }
}
