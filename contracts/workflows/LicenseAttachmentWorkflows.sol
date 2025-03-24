// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { BaseWorkflow } from "../BaseWorkflow.sol";
import { Errors } from "../lib/Errors.sol";
import { ILicenseAttachmentWorkflows } from "../interfaces/workflows/ILicenseAttachmentWorkflows.sol";
import { ISPGNFT } from "../interfaces/ISPGNFT.sol";
import { LicensingHelper } from "../lib/LicensingHelper.sol";
import { MetadataHelper } from "../lib/MetadataHelper.sol";
import { PermissionHelper } from "../lib/PermissionHelper.sol";
import { WorkflowStructs } from "../lib/WorkflowStructs.sol";

/// @title License Attachment Workflows
/// @notice Each workflow bundles multiple core protocol operations into a single function to simplify
/// the license attachment process in the Story Proof-of-Creativity Protocol.
contract LicenseAttachmentWorkflows is
    ILicenseAttachmentWorkflows,
    BaseWorkflow,
    MulticallUpgradeable,
    AccessManagedUpgradeable,
    UUPSUpgradeable,
    ERC721Holder
{
    using ERC165Checker for address;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address coreMetadataModule,
        address ipAssetRegistry,
        address licenseRegistry,
        address licensingModule,
        address pilTemplate
    )
        BaseWorkflow(
            accessController,
            coreMetadataModule,
            ipAssetRegistry,
            licenseRegistry,
            licensingModule,
            pilTemplate
        )
    {
        if (
            accessController == address(0) ||
            coreMetadataModule == address(0) ||
            ipAssetRegistry == address(0) ||
            licenseRegistry == address(0) ||
            licensingModule == address(0) ||
            pilTemplate == address(0)
        ) revert Errors.LicenseAttachmentWorkflows__ZeroAddressParam();

        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.LicenseAttachmentWorkflows__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
        __Multicall_init();
    }

    /// @notice Register Programmable IP License Terms (if unregistered), attach them to an IP, and optionally sets
    /// licensing configurations.
    /// @dev This function will register new PIL terms if they don't exist, and only sets licensing configurations
    /// for each term where the corresponding licensing config has `isSet` set to true. The function also requires
    /// appropriate permissions.
    /// @param ipId The ID of the IP.
    /// @param licenseTermsData The PIL terms and licensing configuration data to be attached to the IP.
    /// @param sigAttachAndConfig Signature data for attachLicenseTerms and setLicensingConfig to the IP via the
    ///                           Licensing Module.
    /// @return licenseTermsIds The IDs of the newly registered PIL terms.
    function registerPILTermsAndAttach(
        address ipId,
        WorkflowStructs.LicenseTermsData[] calldata licenseTermsData,
        WorkflowStructs.SignatureData calldata sigAttachAndConfig
    ) external returns (uint256[] memory licenseTermsIds) {
        if (licenseTermsData.length == 0) revert Errors.LicenseAttachmentWorkflows__NoLicenseTermsData();
        if (msg.sender != sigAttachAndConfig.signer)
            revert Errors.LicenseAttachmentWorkflows__CallerNotSigner(msg.sender, sigAttachAndConfig.signer);

        address[] memory modules = new address[](2);
        bytes4[] memory selectors = new bytes4[](2);
        modules[0] = address(LICENSING_MODULE);
        modules[1] = address(LICENSING_MODULE);
        selectors[0] = ILicensingModule.attachLicenseTerms.selector;
        selectors[1] = ILicensingModule.setLicensingConfig.selector;
        PermissionHelper.setBatchTransientPermissionForModules({
            ipId: ipId,
            accessController: address(ACCESS_CONTROLLER),
            modules: modules,
            selectors: selectors,
            sigData: sigAttachAndConfig
        });

        licenseTermsIds = LicensingHelper.registerMultiplePILTermsAndAttachAndSetConfigs({
            ipId: ipId,
            pilTemplate: address(PIL_TEMPLATE),
            licensingModule: address(LICENSING_MODULE),
            licenseTermsData: licenseTermsData
        });
    }

    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP, register Programmable IP
    /// License Terms (if unregistered), attach it to the registered IP, and optionally sets licensing configurations.
    /// @dev Requires caller to have the minter role or the SPG NFT to allow public minting. This function will
    /// register new PIL terms if they don't exist, and only sets licensing configurations for each term where the
    /// corresponding licensing config has `isSet` set to true.
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
    )
        external
        onlyMintAuthorized(spgNftContract)
        returns (address ipId, uint256 tokenId, uint256[] memory licenseTermsIds)
    {
        if (licenseTermsData.length == 0) revert Errors.LicenseAttachmentWorkflows__NoLicenseTermsData();

        tokenId = ISPGNFT(spgNftContract).mintByPeriphery({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI,
            nftMetadataHash: ipMetadata.nftMetadataHash,
            allowDuplicates: allowDuplicates
        });

        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        licenseTermsIds = LicensingHelper.registerMultiplePILTermsAndAttachAndSetConfigs({
            ipId: ipId,
            pilTemplate: address(PIL_TEMPLATE),
            licensingModule: address(LICENSING_MODULE),
            licenseTermsData: licenseTermsData
        });

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register a given NFT as an IP and attach Programmable IP License Terms, and optionally sets licensing
    /// configurations.
    /// @dev Since this contract doesn't own the IP Account when IP is registered, a signature is required to grant
    /// permission for this contract to attach PIL Terms and set licensing configurations to the newly created IP
    /// Account in the same transaction. This function will also register new PIL terms if they don't exist, and only
    /// sets licensing configurations for each term where the corresponding licensing config has `isSet` set to true.
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
    ) external returns (address ipId, uint256[] memory licenseTermsIds) {
        if (licenseTermsData.length == 0) revert Errors.LicenseAttachmentWorkflows__NoLicenseTermsData();
        if (msg.sender != sigMetadataAndAttachAndConfig.signer)
            revert Errors.LicenseAttachmentWorkflows__CallerNotSigner(msg.sender, sigMetadataAndAttachAndConfig.signer);

        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);

        address[] memory modules = new address[](3);
        bytes4[] memory selectors = new bytes4[](3);
        modules[0] = address(CORE_METADATA_MODULE);
        modules[1] = address(LICENSING_MODULE);
        modules[2] = address(LICENSING_MODULE);
        selectors[0] = ICoreMetadataModule.setAll.selector;
        selectors[1] = ILicensingModule.attachLicenseTerms.selector;
        selectors[2] = ILicensingModule.setLicensingConfig.selector;
        PermissionHelper.setBatchTransientPermissionForModules({
            ipId: ipId,
            accessController: address(ACCESS_CONTROLLER),
            modules: modules,
            selectors: selectors,
            sigData: sigMetadataAndAttachAndConfig
        });

        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        licenseTermsIds = LicensingHelper.registerMultiplePILTermsAndAttachAndSetConfigs({
            ipId: ipId,
            pilTemplate: address(PIL_TEMPLATE),
            licensingModule: address(LICENSING_MODULE),
            licenseTermsData: licenseTermsData
        });
    }

    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP,
    /// and attach default license terms.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIpAndAttachDefaultTerms(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        bool allowDuplicates
    ) external onlyMintAuthorized(spgNftContract) returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(spgNftContract).mintByPeriphery({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI,
            nftMetadataHash: ipMetadata.nftMetadataHash,
            allowDuplicates: allowDuplicates
        });

        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        LICENSING_MODULE.attachDefaultLicenseTerms(ipId);

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register a given NFT as an IP and attach default license terms.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadataAndDefaultTerms Signature data for setAll (metadata) and attachDefaultLicenseTerms
    /// to the IP via the Core Metadata Module and Licensing Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIpAndAttachDefaultTerms(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.SignatureData calldata sigMetadataAndDefaultTerms
    ) external returns (address ipId) {
        if (msg.sender != sigMetadataAndDefaultTerms.signer)
            revert Errors.LicenseAttachmentWorkflows__CallerNotSigner(msg.sender, sigMetadataAndDefaultTerms.signer);

        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);

        address[] memory modules = new address[](2);
        bytes4[] memory selectors = new bytes4[](2);
        modules[0] = address(CORE_METADATA_MODULE);
        modules[1] = address(LICENSING_MODULE);
        selectors[0] = ICoreMetadataModule.setAll.selector;
        selectors[1] = ILicensingModule.attachDefaultLicenseTerms.selector;
        PermissionHelper.setBatchTransientPermissionForModules({
            ipId: ipId,
            accessController: address(ACCESS_CONTROLLER),
            modules: modules,
            selectors: selectors,
            sigData: sigMetadataAndDefaultTerms
        });

        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        LICENSING_MODULE.attachDefaultLicenseTerms(ipId);
    }

    //
    // Upgrade
    //

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
