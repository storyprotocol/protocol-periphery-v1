// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
    using SafeERC20 for IERC20;

    /// @notice The address of the Access Controller.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAccessController public immutable ACCESS_CONTROLLER;

    /// @notice The address of the Core Metadata Module.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ICoreMetadataModule public immutable CORE_METADATA_MODULE;

    /// @notice The address of the IP Asset Registry.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice The address of the Licensing Module.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice The address of the License Registry.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice The address of the PIL License Template.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IPILicenseTemplate public immutable PIL_TEMPLATE;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address coreMetadataModule,
        address ipAssetRegistry,
        address licenseRegistry,
        address licensingModule,
        address pilTemplate
    ) {
        // assumes 0 addresses are checked in the child contract
        ACCESS_CONTROLLER = IAccessController(accessController);
        CORE_METADATA_MODULE = ICoreMetadataModule(coreMetadataModule);
        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        PIL_TEMPLATE = IPILicenseTemplate(pilTemplate);
    }

    /// @notice Check that the caller is authorized to mint for the provided SPG NFT.
    /// @notice The caller must have the MINTER_ROLE for the SPG NFT or the SPG NFT must has public minting enabled.
    /// @param spgNftContract The address of the SPG NFT.
    modifier onlyMintAuthorized(address spgNftContract) {
        if (
            !ISPGNFT(spgNftContract).hasRole(SPGNFTLib.MINTER_ROLE, msg.sender) &&
            !ISPGNFT(spgNftContract).publicMinting()
        ) revert Errors.Workflow__CallerNotAuthorizedToMint();
        _;
    }

    /// @notice Collects registration fee from payer and approves IP Asset Registry to spend it.
    /// @param registrationFeePayer The address of the payer for the IP registration fee.
    function _collectRegistrationFeeAndApprove(address registrationFeePayer) internal {
        uint96 registrationFee = IP_ASSET_REGISTRY.getFeeAmount();
        if (registrationFee > 0) {
            address feeToken = IP_ASSET_REGISTRY.getFeeToken();

            IERC20(feeToken).safeTransferFrom(registrationFeePayer, address(this), uint256(registrationFee));
            IERC20(feeToken).forceApprove(address(IP_ASSET_REGISTRY), uint256(registrationFee));
        }
    }
}
