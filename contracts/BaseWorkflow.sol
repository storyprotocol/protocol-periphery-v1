// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { ISPGNFT } from "./interfaces/ISPGNFT.sol";
import { SPGNFTLib } from "./lib/SPGNFTLib.sol";
import { Errors } from "./lib/Errors.sol";

/// @title Base Workflow
/// @notice The base contract for all Story Protocol Periphery workflows.
abstract contract BaseWorkflow {
    /// @notice The address of the Access Controller.
    IAccessController public immutable ACCESS_CONTROLLER;

    /// @notice The address of the Core Metadata Module.
    ICoreMetadataModule public immutable CORE_METADATA_MODULE;

    /// @notice The address of the IP Asset Registry.
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice The address of the Licensing Module.
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice The address of the License Registry.
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice The address of the PIL License Template.
    IPILicenseTemplate public immutable PIL_TEMPLATE;

    constructor(
        address accessController,
        address coreMetadataModule,
        address ipAssetRegistry,
        address licensingModule,
        address licenseRegistry,
        address pilTemplate
    ) {
        // assumes 0 addresses are checked in the child contract
        ACCESS_CONTROLLER = IAccessController(accessController);
        CORE_METADATA_MODULE = ICoreMetadataModule(coreMetadataModule);
        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        PIL_TEMPLATE = IPILicenseTemplate(pilTemplate);
    }

    /// @notice Check that the caller has the minter role for the provided SPG NFT.
    /// @param spgNftContract The address of the SPG NFT.
    modifier onlyCallerWithMinterRole(address spgNftContract) {
        if (!ISPGNFT(spgNftContract).hasRole(SPGNFTLib.MINTER_ROLE, msg.sender))
            revert Errors.SPG__CallerNotMinterRole();
        _;
    }
}
