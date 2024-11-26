// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { BaseWorkflow } from "../BaseWorkflow.sol";
import { Errors } from "../lib/Errors.sol";
import { ILicenseAttachmentWorkflows } from "../interfaces/workflows/ILicenseAttachmentWorkflows.sol";
import { ISPGNFT } from "../interfaces/ISPGNFT.sol";
import { LicensingHelper } from "../lib/LicensingHelper.sol";
import { MetadataHelper } from "../lib/MetadataHelper.sol";
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
    )
        external
        onlyMintAuthorized(spgNftContract)
        returns (address ipId, uint256 tokenId, uint256[] memory licenseTermsIds)
    {
        tokenId = ISPGNFT(spgNftContract).mintByPeriphery({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI,
            nftMetadataHash: ipMetadata.nftMetadataHash,
            allowDuplicates: allowDuplicates
        });

        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        licenseTermsIds = LicensingHelper.registerPILTermsAndAttach(
            ipId,
            address(PIL_TEMPLATE),
            address(LICENSING_MODULE),
            terms
        );

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

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

        for (uint256 i = 0; i < licenseTermsIds.length; i++) {
            LicensingHelper.attachLicenseTerms(
                ipId,
                address(LICENSING_MODULE),
                licenseTemplates[i],
                licenseTermsIds[i]
            );
        }

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

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
    ) external returns (address ipId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        MetadataHelper.setMetadataWithSig(ipId, address(CORE_METADATA_MODULE), ipMetadata, sigMetadata);

        for (uint256 i = 0; i < licenseTermsIds.length; i++) {
            LicensingHelper.attachLicenseTermsWithSig(
                ipId,
                address(LICENSING_MODULE),
                licenseTemplates[i],
                licenseTermsIds[i],
                sigsAttach[i]
            );
        }
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
}
