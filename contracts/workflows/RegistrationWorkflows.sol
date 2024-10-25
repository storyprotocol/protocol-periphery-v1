// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { BaseWorkflow } from "../BaseWorkflow.sol";
import { Errors } from "../lib/Errors.sol";
import { IRegistrationWorkflows } from "../interfaces/workflows/IRegistrationWorkflows.sol";
import { ISPGNFT } from "../interfaces/ISPGNFT.sol";
import { MetadataHelper } from "../lib/MetadataHelper.sol";
import { WorkflowStructs } from "../lib/WorkflowStructs.sol";

/// @title IP Registration Workflows
/// @notice Each workflow bundles multiple core protocol operations into a single function to simplify
/// the IP registration process in the Story Proof-of-Creativity Protocol.
contract RegistrationWorkflows is
    IRegistrationWorkflows,
    BaseWorkflow,
    MulticallUpgradeable,
    AccessManagedUpgradeable,
    UUPSUpgradeable
{
    using ERC165Checker for address;

    /// @dev Storage structure for the RegistrationWorkflows
    /// @param nftContractBeacon The address of the NFT contract beacon.
    /// @custom:storage-location erc7201:story-protocol-periphery.RegistrationWorkflows
    struct RegistrationWorkflowsStorage {
        address nftContractBeacon;
    }

    // solhint-disable-next-line max-line-length
    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.RegistrationWorkflows")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RegistrationWorkflowsStorageLocation =
        0xc7b66cfa1bcdb9c30d9d3196622195473767c295d0a4fc11c6f9f5882f528900;

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
        ) revert Errors.RegistrationWorkflows__ZeroAddressParam();

        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.RegistrationWorkflows__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @dev Sets the NFT contract beacon address.
    /// @param newNftContractBeacon The address of the new NFT contract beacon.
    function setNftContractBeacon(address newNftContractBeacon) external restricted {
        if (newNftContractBeacon == address(0)) revert Errors.RegistrationWorkflows__ZeroAddressParam();
        RegistrationWorkflowsStorage storage $ = _getRegistrationWorkflowsStorage();
        $.nftContractBeacon = newNftContractBeacon;
    }

    /// @dev Upgrades the NFT contract beacon. Restricted to only the protocol access manager.
    /// @param newNftContract The address of the new NFT contract implemenetation.
    function upgradeCollections(address newNftContract) public restricted {
        // UpgradeableBeacon checks for newImplementation.bytecode.length > 0, so no need to check for zero address.
        UpgradeableBeacon(_getRegistrationWorkflowsStorage().nftContractBeacon).upgradeTo(newNftContract);
    }

    /// @notice Creates a new SPGNFT collection to be used by SPG.
    /// @param spgNftInitParams The initialization parameters for the SPGNFT collection. See {ISPGNFT-InitParams}.
    /// @return spgNftContract The address of the newly created SPGNFT collection.
    function createCollection(ISPGNFT.InitParams calldata spgNftInitParams) external returns (address spgNftContract) {
        spgNftContract = address(new BeaconProxy(_getRegistrationWorkflowsStorage().nftContractBeacon, ""));
        ISPGNFT(spgNftContract).initialize(spgNftInitParams);
        emit CollectionCreated(spgNftContract);
    }

    /// @notice Mint an NFT from a SPGNFT collection and register it with metadata as an IP.
    /// @dev Requires caller to have the minter role or the SPG NFT to allow public minting.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIp(
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
        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Registers an NFT as IP with metadata.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIp(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.SignatureData calldata sigMetadata
    ) external returns (address ipId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        MetadataHelper.setMetadataWithSig(
            ipId,
            address(CORE_METADATA_MODULE),
            address(ACCESS_CONTROLLER),
            ipMetadata,
            sigMetadata
        );
    }

    //
    // Upgrade
    //

    /// @dev Returns the storage struct of RegistrationWorkflows.
    function _getRegistrationWorkflowsStorage() private pure returns (RegistrationWorkflowsStorage storage $) {
        assembly {
            $.slot := RegistrationWorkflowsStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
