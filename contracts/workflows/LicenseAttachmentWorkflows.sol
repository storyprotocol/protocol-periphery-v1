// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
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
    UUPSUpgradeable
{
    using ERC165Checker for address;

    /// @dev Storage structure for the LicenseAttachmentWorkflows
    /// @param nftContractBeacon The address of the NFT contract beacon.
    /// @custom:storage-location erc7201:story-protocol-periphery.LicenseAttachmentWorkflows
    struct LicenseAttachmentWorkflowsStorage {
        address nftContractBeacon;
    }

    // solhint-disable-next-line max-line-length
    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.LicenseAttachmentWorkflows")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant LicenseAttachmentWorkflowsStorageLocation =
        0x5dffa4259249ac7a3ead22d30b4086dd3916391710734d6dd1182f2c1fe1b200;

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
    }

    /// @dev Sets the NFT contract beacon address.
    /// @param newNftContractBeacon The address of the new NFT contract beacon.
    function setNftContractBeacon(address newNftContractBeacon) external restricted {
        if (newNftContractBeacon == address(0)) revert Errors.LicenseAttachmentWorkflows__ZeroAddressParam();
        LicenseAttachmentWorkflowsStorage storage $ = _getLicenseAttachmentWorkflowsStorage();
        $.nftContractBeacon = newNftContractBeacon;
    }

    /// @notice Register Programmable IP License Terms (if unregistered) and attach it to IP.
    /// @param ipId The ID of the IP.
    /// @param licenseTermsData The PIL terms and licensing configuration data to be attached to the IP.
    /// @param sigAttachAndConfig Signature data for attachLicenseTerms and setLicensingConfig to the IP via the Licensing Module.
    /// @return licenseTermsIds The IDs of the newly registered PIL terms.
    function registerPILTermsAndAttach(
        address ipId,
        WorkflowStructs.LicenseTermsData[] calldata licenseTermsData,
        WorkflowStructs.SignatureData calldata sigAttachAndConfig
    ) external returns (uint256[] memory licenseTermsIds) {
        if (licenseTermsData.length == 0) revert Errors.LicenseAttachmentWorkflows__NoLicenseTermsData();

        address[] memory modules = new address[](2);
        bytes4[] memory selectors = new bytes4[](2);
        modules[0] = address(LICENSING_MODULE);
        modules[1] = address(LICENSING_MODULE);
        selectors[0] = ILicensingModule.attachLicenseTerms.selector;
        selectors[1] = ILicensingModule.setLicensingConfig.selector;
        PermissionHelper.setBatchPermissionForModules({
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

    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP,
    /// register Programmable IP License Terms (if unregistered), and attach it to the registered IP.
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
    ) external returns (address ipId, uint256[] memory licenseTermsIds) {
        if (licenseTermsData.length == 0) revert Errors.LicenseAttachmentWorkflows__NoLicenseTermsData();

        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);

        address[] memory modules = new address[](3);
        bytes4[] memory selectors = new bytes4[](3);
        modules[0] = address(CORE_METADATA_MODULE);
        modules[1] = address(LICENSING_MODULE);
        modules[2] = address(LICENSING_MODULE);
        selectors[0] = ICoreMetadataModule.setAll.selector;
        selectors[1] = ILicensingModule.attachLicenseTerms.selector;
        selectors[2] = ILicensingModule.setLicensingConfig.selector;
        PermissionHelper.setBatchPermissionForModules({
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

    //
    // Upgrade
    //

    /// @dev Returns the storage struct of LicenseAttachmentWorkflows.
    function _getLicenseAttachmentWorkflowsStorage()
        private
        pure
        returns (LicenseAttachmentWorkflowsStorage storage $)
    {
        assembly {
            $.slot := LicenseAttachmentWorkflowsStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    ////////////////////////////////////////////////////////////////////////////
    //                              DEPRECATED                                //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Register Programmable IP License Terms (if unregistered) and attach it to IP.
    /// @notice THIS VERSION OF THE FUNCTION IS DEPRECATED, WILL BE REMOVED IN V1.4
    function registerPILTermsAndAttach(
        address ipId,
        PILTerms[] calldata terms,
        WorkflowStructs.SignatureData calldata sigAttach
    ) external returns (uint256[] memory licenseTermsIds) {
        if (terms.length == 0) revert Errors.LicenseAttachmentWorkflows__NoLicenseTermsData();

        PermissionHelper.setPermissionForModule(
            ipId,
            address(LICENSING_MODULE),
            address(ACCESS_CONTROLLER),
            ILicensingModule.attachLicenseTerms.selector,
            sigAttach
        );

        licenseTermsIds = _registerMultiplePILTermsAndAttach(ipId, terms);
    }

    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP,
    /// register Programmable IP License Terms (if unregistered), and attach it to the registered IP.
    /// @notice THIS VERSION OF THE FUNCTION IS DEPRECATED, WILL BE REMOVED IN V1.4
    function mintAndRegisterIpAndAttachPILTerms(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        PILTerms[] calldata terms
    )
        external
        onlyMintAuthorized(spgNftContract)
        returns (address ipId, uint256 tokenId, uint256[] memory licenseTermsIds)
    {
        if (terms.length == 0) revert Errors.LicenseAttachmentWorkflows__NoLicenseTermsData();

        tokenId = ISPGNFT(spgNftContract).mintByPeriphery({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI,
            nftMetadataHash: "",
            allowDuplicates: true
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        licenseTermsIds = _registerMultiplePILTermsAndAttach(ipId, terms);

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register a given NFT as an IP and attach Programmable IP License Terms.
    /// @notice THIS VERSION OF THE FUNCTION IS DEPRECATED, WILL BE REMOVED IN V1.4
    function registerIpAndAttachPILTerms(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        PILTerms[] calldata terms,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData calldata sigAttach
    ) external returns (address ipId, uint256[] memory licenseTermsIds) {
        if (terms.length == 0) revert Errors.LicenseAttachmentWorkflows__NoLicenseTermsData();

        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        MetadataHelper.setMetadataWithSig(
            ipId,
            address(CORE_METADATA_MODULE),
            address(ACCESS_CONTROLLER),
            ipMetadata,
            sigMetadata
        );

        PermissionHelper.setPermissionForModule(
            ipId,
            address(LICENSING_MODULE),
            address(ACCESS_CONTROLLER),
            ILicensingModule.attachLicenseTerms.selector,
            sigAttach
        );

        licenseTermsIds = _registerMultiplePILTermsAndAttach(ipId, terms);
    }

    /// @notice Register Programmable IP License Terms (if unregistered) and attach it to IP.
    /// @notice THIS VERSION OF THE FUNCTION IS DEPRECATED, WILL BE REMOVED IN V1.4
    function registerPILTermsAndAttach(
        address ipId,
        PILTerms calldata terms,
        WorkflowStructs.SignatureData calldata sigAttach
    ) external returns (uint256 licenseTermsId) {
        PermissionHelper.setPermissionForModule(
            ipId,
            address(LICENSING_MODULE),
            address(ACCESS_CONTROLLER),
            ILicensingModule.attachLicenseTerms.selector,
            sigAttach
        );

        licenseTermsId = LicensingHelper.registerPILTermsAndAttach(
            ipId,
            address(PIL_TEMPLATE),
            address(LICENSING_MODULE),
            terms
        );
    }

    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP,
    /// register Programmable IP License Terms (if unregistered), and attach it to the registered IP.
    /// @notice THIS VERSION OF THE FUNCTION IS DEPRECATED, WILL BE REMOVED IN V1.4
    function mintAndRegisterIpAndAttachPILTerms(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        PILTerms calldata terms
    ) external onlyMintAuthorized(spgNftContract) returns (address ipId, uint256 tokenId, uint256 licenseTermsId) {
        tokenId = ISPGNFT(spgNftContract).mintByPeriphery({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI,
            nftMetadataHash: "",
            allowDuplicates: true
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        licenseTermsId = LicensingHelper.registerPILTermsAndAttach(
            ipId,
            address(PIL_TEMPLATE),
            address(LICENSING_MODULE),
            terms
        );

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register a given NFT as an IP and attach Programmable IP License Terms.
    /// @notice THIS VERSION OF THE FUNCTION IS DEPRECATED, WILL BE REMOVED IN V1.4
    function registerIpAndAttachPILTerms(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        PILTerms calldata terms,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData calldata sigAttach
    ) external returns (address ipId, uint256 licenseTermsId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        MetadataHelper.setMetadataWithSig(
            ipId,
            address(CORE_METADATA_MODULE),
            address(ACCESS_CONTROLLER),
            ipMetadata,
            sigMetadata
        );

        PermissionHelper.setPermissionForModule(
            ipId,
            address(LICENSING_MODULE),
            address(ACCESS_CONTROLLER),
            ILicensingModule.attachLicenseTerms.selector,
            sigAttach
        );

        licenseTermsId = LicensingHelper.registerPILTermsAndAttach(
            ipId,
            address(PIL_TEMPLATE),
            address(LICENSING_MODULE),
            terms
        );
    }

    /// @notice THIS VERSION OF THE FUNCTION IS DEPRECATED, WILL BE REMOVED IN V1.4
    function _registerMultiplePILTermsAndAttach(
        address ipId,
        PILTerms[] calldata terms
    ) private returns (uint256[] memory licenseTermsIds) {
        licenseTermsIds = new uint256[](terms.length);
        uint256 length = terms.length;
        for (uint256 i; i < length; i++) {
            licenseTermsIds[i] = LicensingHelper.registerPILTermsAndAttach(
                ipId,
                address(PIL_TEMPLATE),
                address(LICENSING_MODULE),
                terms[i]
            );
        }
    }
}
