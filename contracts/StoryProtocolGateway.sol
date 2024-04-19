// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { AccessControlled } from "@storyprotocol/core/access/AccessControlled.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
// solhint-disable-next-line max-line-length
import { IPILicenseTemplate, PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";

import { IStoryProtocolGateway } from "./interfaces/IStoryProtocolGateway.sol";
import { ISPGNFT } from "./interfaces/ISPGNFT.sol";
import { Errors } from "./lib/Errors.sol";

contract StoryProtocolGateway is IStoryProtocolGateway, AccessControlled, AccessManagedUpgradeable, UUPSUpgradeable {
    using ERC165Checker for address;

    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    ILicensingModule public immutable LICENSING_MODULE;

    ICoreMetadataModule public immutable CORE_METADATA_MODULE;

    IPILicenseTemplate public immutable PIL_TEMPLATE;

    address public immutable NFT_CONTRACT_BEACON;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAssetRegistry,
        address licensingModule,
        address coreMetadataModule,
        address pilTemplate,
        address nftContractBeacon
    ) AccessControlled(accessController, ipAssetRegistry) {
        if (
            accessController == address(0) ||
            ipAssetRegistry == address(0) ||
            licensingModule == address(0) ||
            coreMetadataModule == address(0) ||
            nftContractBeacon == address(0)
        ) revert Errors.SPG__ZeroAddressParam();

        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        CORE_METADATA_MODULE = ICoreMetadataModule(coreMetadataModule);
        PIL_TEMPLATE = IPILicenseTemplate(pilTemplate);
        NFT_CONTRACT_BEACON = nftContractBeacon;

        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.SPG__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @dev Upgrades the NFT contract beacon. Restricted to only the protocol access manager.
    /// @param newNftContract The address of the new NFT contract implemenetation.
    function upgradeCollections(address newNftContract) public restricted {
        // UpgradeableBeacon checks for newImplementation.bytecode.length > 0, so no need to check for zero address.
        UpgradeableBeacon(NFT_CONTRACT_BEACON).upgradeTo(newNftContract);
    }

    /// @notice Creates a new NFT collection to be used by SPG.
    /// @param name The name of the collection.
    /// @param symbol The symbol of the collection.
    /// @param maxSupply The maximum supply of the collection.
    /// @param mintCost The cost to mint an NFT from the collection.
    /// @param owner The owner of the collection.
    /// @return nftContract The address of the newly created NFT collection.
    function createCollection(
        string memory name,
        string memory symbol,
        uint32 maxSupply,
        uint256 mintCost,
        address owner
    ) external returns (address nftContract) {
        nftContract = address(new BeaconProxy(NFT_CONTRACT_BEACON, ""));
        ISPGNFT(nftContract).initialize(name, symbol, maxSupply, mintCost, owner);
    }

    /// @notice Mint an NFT from a collection and register it as an IP.
    /// @param nftContract The address of the NFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @return tokenId The ID of the minted NFT.
    /// @return ipId The ID of the registered IP.
    function mintAndRegisterIp(address nftContract, address recipient) public returns (uint256 tokenId, address ipId) {
        tokenId = ISPGNFT(nftContract).mint(recipient);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
    }

    /// @notice Mint an NFT from a collection and register it with metadata as an IP.
    /// @param nftContract The address of the NFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param metadataURI The URI of the metadata for the IP.
    /// @param metadataHash The hash of the metadata for the IP.
    /// @param nftMetadataHash The hash of the metadata for the IP NFT.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function mintAndRegisterIp(
        address nftContract,
        address recipient,
        string memory metadataURI,
        bytes32 metadataHash,
        bytes32 nftMetadataHash
    ) external returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(nftContract).mint(address(this));
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);

        CORE_METADATA_MODULE.setAll(ipId, metadataURI, metadataHash, nftMetadataHash);

        ISPGNFT(nftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register Programmable IP License Terms (if unregistered) and attach it to IP.
    /// @param ipId The ID of the IP.
    /// @param terms The PIL terms to be registered.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerPILTermsAndAttach(
        address ipId,
        PILTerms memory terms
    ) external verifyPermission(ipId) returns (uint256 licenseTermsId) {
        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);
    }

    /// @notice Mint an NFT from a collection, register it as an IP, register Programmable IP License Terms (if
    /// unregistered), and attach it to the registered IP.
    /// @param nftContract The address of the NFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param terms The PIL terms to be registered.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function mintAndRegisterIpAndAttachPILTerms(
        address nftContract,
        address recipient,
        PILTerms memory terms
    ) external returns (address ipId, uint256 tokenId, uint256 licenseTermsId) {
        tokenId = ISPGNFT(nftContract).mint(address(this));
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);

        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);

        ISPGNFT(nftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Mint an NFT from a collection, register it with metadata as an IP, register Programmable IP License
    /// Terms (if unregistered), and attach it to the registered IP.
    /// @param nftContract The address of the NFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param metadataURI The URI of the metadata for the IP.
    /// @param metadataHash The hash of the metadata for the IP.
    /// @param nftMetadataHash The hash of the metadata for the IP NFT.
    /// @param terms The PIL terms to be registered.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function mintAndRegisterIpAndAttachPILTerms(
        address nftContract,
        address recipient,
        string memory metadataURI,
        bytes32 metadataHash,
        bytes32 nftMetadataHash,
        PILTerms memory terms
    ) external returns (address ipId, uint256 tokenId, uint256 licenseTermsId) {
        tokenId = ISPGNFT(nftContract).mint(address(this));
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);

        CORE_METADATA_MODULE.setAll(ipId, metadataURI, metadataHash, nftMetadataHash);

        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);

        ISPGNFT(nftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register a given NFT as an IP and attach Programmable IP License Terms.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param terms The PIL terms to be registered.
    /// @return ipId The ID of the registered IP.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerIpAndAttachPILTerms(
        address nftContract,
        uint256 tokenId,
        PILTerms memory terms
    ) external returns (address ipId, uint256 licenseTermsId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _verifyPermission(ipId);

        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);
    }

    /// @notice Register a given NFT as an IP with metadata and attach Programmable IP License Terms.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param metadataURI The URI of the metadata for the IP.
    /// @param metadataHash The hash of the metadata for the IP.
    /// @param nftMetadataHash The hash of the metadata for the IP NFT.
    /// @param terms The PIL terms to be registered.
    /// @return ipId The ID of the registered IP.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerIpAndAttachPILTerms(
        address nftContract,
        uint256 tokenId,
        string memory metadataURI,
        bytes32 metadataHash,
        bytes32 nftMetadataHash,
        PILTerms memory terms
    ) external returns (address ipId, uint256 licenseTermsId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _verifyPermission(ipId);

        CORE_METADATA_MODULE.setAll(ipId, metadataURI, metadataHash, nftMetadataHash);

        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);
    }

    /// @dev Registers PIL License Terms and attaches them to the given IP.
    /// @param ipId The ID of the IP.
    /// @param terms The PIL terms to be registered.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function _registerPILTermsAndAttach(address ipId, PILTerms memory terms) internal returns (uint256 licenseTermsId) {
        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(terms);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
    }

    //
    // Upgrade
    //

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
