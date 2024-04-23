// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { AccessControlled } from "@storyprotocol/core/access/AccessControlled.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
// solhint-disable-next-line max-line-length
import { IPILicenseTemplate, PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";

import { IStoryProtocolGateway } from "./interfaces/IStoryProtocolGateway.sol";
import { ISPGNFT } from "./interfaces/ISPGNFT.sol";
import { Errors } from "./lib/Errors.sol";
import { SPGNFTLib } from "./lib/SPGNFTLib.sol";

contract StoryProtocolGateway is IStoryProtocolGateway, AccessControlled, AccessManagedUpgradeable, UUPSUpgradeable {
    using ERC165Checker for address;

    /// @dev Storage structure for the SPG
    /// @param nftContractBeacon The address of the NFT contract beacon.
    /// @custom:storage-location erc7201:story-protocol-periphery.SPG
    struct SPGStorage {
        address nftContractBeacon;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.SPG")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant SPGStorageLocation = 0xb4cca15568cb3dbdd3e7ab1af5e15d861de93bb129f4c24bf0ef4e27377e7300;

    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    ILicensingModule public immutable LICENSING_MODULE;

    ICoreMetadataModule public immutable CORE_METADATA_MODULE;

    IPILicenseTemplate public immutable PIL_TEMPLATE;

    /// @notice Check that the caller has the minter role for the provided SPG NFT.
    /// @param nftContract The address of the SPG NFT.
    modifier onlyCallerWithMinterRole(address nftContract) {
        if (!ISPGNFT(nftContract).hasRole(SPGNFTLib.MINTER_ROLE, msg.sender)) revert Errors.SPG__CallerNotMinterRole();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAssetRegistry,
        address licensingModule,
        address coreMetadataModule,
        address pilTemplate
    ) AccessControlled(accessController, ipAssetRegistry) {
        if (
            accessController == address(0) ||
            ipAssetRegistry == address(0) ||
            licensingModule == address(0) ||
            coreMetadataModule == address(0)
        ) revert Errors.SPG__ZeroAddressParam();

        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        CORE_METADATA_MODULE = ICoreMetadataModule(coreMetadataModule);
        PIL_TEMPLATE = IPILicenseTemplate(pilTemplate);

        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.SPG__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    function setNftContractBeacon(address newNftContractBeacon) external restricted {
        if (newNftContractBeacon == address(0)) revert Errors.SPG__ZeroAddressParam();
        SPGStorage storage $ = _getSPGStorage();
        $.nftContractBeacon = newNftContractBeacon;
    }

    /// @dev Upgrades the NFT contract beacon. Restricted to only the protocol access manager.
    /// @param newNftContract The address of the new NFT contract implemenetation.
    function upgradeCollections(address newNftContract) public restricted {
        // UpgradeableBeacon checks for newImplementation.bytecode.length > 0, so no need to check for zero address.
        UpgradeableBeacon(_getSPGStorage().nftContractBeacon).upgradeTo(newNftContract);
    }

    /// @notice Creates a new NFT collection to be used by SPG.
    /// @param name The name of the collection.
    /// @param symbol The symbol of the collection.
    /// @param maxSupply The maximum supply of the collection.
    /// @param mintCost The cost to mint an NFT from the collection.
    /// @param mintToken The token to be used for mint payment.
    /// @param owner The owner of the collection.
    /// @return nftContract The address of the newly created NFT collection.
    function createCollection(
        string memory name,
        string memory symbol,
        uint32 maxSupply,
        uint256 mintCost,
        address mintToken,
        address owner
    ) external returns (address nftContract) {
        nftContract = address(new BeaconProxy(_getSPGStorage().nftContractBeacon, ""));
        ISPGNFT(nftContract).initialize(name, symbol, maxSupply, mintCost, mintToken, owner);
    }

    /// @notice Mint an NFT from a collection and register it as an IP.
    /// @param nftContract The address of the NFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function mintAndRegisterIp(
        address nftContract,
        address recipient
    ) external onlyCallerWithMinterRole(nftContract) returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(nftContract).mintBySPG({ to: recipient, payer: msg.sender });
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
    ) external onlyCallerWithMinterRole(nftContract) returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(nftContract).mintBySPG({ to: address(this), payer: msg.sender });
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
    ) external onlyCallerWithMinterRole(nftContract) returns (address ipId, uint256 tokenId, uint256 licenseTermsId) {
        tokenId = ISPGNFT(nftContract).mintBySPG({ to: address(this), payer: msg.sender });
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
    ) external onlyCallerWithMinterRole(nftContract) returns (address ipId, uint256 tokenId, uint256 licenseTermsId) {
        tokenId = ISPGNFT(nftContract).mintBySPG({ to: address(this), payer: msg.sender });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);

        CORE_METADATA_MODULE.setAll(ipId, metadataURI, metadataHash, nftMetadataHash);

        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);

        ISPGNFT(nftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register a given NFT as an IP and attach Programmable IP License Terms.
    /// @dev Because IP Account is created in this function, we need to set the permission via signature to allow this
    /// contract to attach PIL Terms to the newly created IP Account in the same function.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param terms The PIL terms to be registered.
    /// @param signer The address of the signer for execution with signature.
    /// @param deadline The deadline for the signature.
    /// @param signature The signature for the execution via IP Account.
    /// @return ipId The ID of the registered IP.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerIpAndAttachPILTerms(
        address nftContract,
        uint256 tokenId,
        PILTerms memory terms,
        address signer,
        uint256 deadline,
        bytes calldata signature
    ) external returns (address ipId, uint256 licenseTermsId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _setPermissionInLicensingModule(
            ipId,
            signer,
            deadline,
            signature,
            ILicensingModule.attachLicenseTerms.selector
        );
        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);
    }

    /// @notice Register a given NFT as an IP with metadata and attach Programmable IP License Terms.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param metadataURI The URI of the metadata for the IP.
    /// @param metadataHash The hash of the metadata for the IP.
    /// @param nftMetadataHash The hash of the metadata for the IP NFT.
    /// @param terms The PIL terms to be registered.
    /// @param signer The address of the signer for execution with signature.
    /// @param deadline The deadline for the signature.
    /// @param signature The signature for the execution via IP Account.
    /// @return ipId The ID of the registered IP.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerIpAndAttachPILTerms(
        address nftContract,
        uint256 tokenId,
        string memory metadataURI,
        bytes32 metadataHash,
        bytes32 nftMetadataHash,
        PILTerms memory terms,
        address signer,
        uint256 deadline,
        bytes calldata signature
    ) external returns (address ipId, uint256 licenseTermsId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        CORE_METADATA_MODULE.setAll(ipId, metadataURI, metadataHash, nftMetadataHash);
        _setPermissionInLicensingModule(
            ipId,
            signer,
            deadline,
            signature,
            ILicensingModule.attachLicenseTerms.selector
        );
        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);
    }

    /// @notice Mint an NFT from a collection and register it as a derivative IP using license tokens.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param nftContract The address of the NFT collection.
    /// @param licenseTokenIds The IDs of the license tokens to be burned for linking the IP to parent IPs.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    /// @param recipient The address to receive the minted NFT.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function registerAndMakeDerivativeWithLicenseTokens(
        address nftContract,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext,
        address recipient
    ) external onlyCallerWithMinterRole(nftContract) returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(nftContract).mintBySPG({ to: address(this), payer: msg.sender });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);

        LICENSING_MODULE.registerDerivativeWithLicenseTokens(ipId, licenseTokenIds, royaltyContext);

        ISPGNFT(nftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register the given NFT as a derivative IP using license tokens.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param licenseTokenIds The IDs of the license tokens to be burned for linking the IP to parent IPs.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    /// @param signer The address of the signer for execution with signature.
    /// @param deadline The deadline for the signature.
    /// @param signature The signature for the execution via IP Account.
    /// @return ipId The ID of the registered IP.
    function registerAndMakeDerivativeWithLicenseTokens(
        address nftContract,
        uint256 tokenId,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext,
        address signer,
        uint256 deadline,
        bytes calldata signature
    ) external returns (address ipId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _setPermissionInLicensingModule(
            ipId,
            signer,
            deadline,
            signature,
            ILicensingModule.registerDerivativeWithLicenseTokens.selector
        );
        LICENSING_MODULE.registerDerivativeWithLicenseTokens(ipId, licenseTokenIds, royaltyContext);
    }

    /// @dev Registers PIL License Terms and attaches them to the given IP.
    /// @param ipId The ID of the IP.
    /// @param terms The PIL terms to be registered.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function _registerPILTermsAndAttach(address ipId, PILTerms memory terms) internal returns (uint256 licenseTermsId) {
        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(terms);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
    }

    /// @dev Sets permission via signature to allow this contract to interact with the Licensing Module on behalf of the
    /// provided IP Account.
    /// @param ipId The ID of the IP.
    /// @param signer The address of the signer for execution with signature.
    /// @param deadline The deadline for the signature.
    /// @param signature The signature for the execution via IP Account.
    /// @param selector The selector of the function to be permitted for execution.
    function _setPermissionInLicensingModule(
        address ipId,
        address signer,
        uint256 deadline,
        bytes calldata signature,
        bytes4 selector
    ) internal {
        IIPAccount(payable(ipId)).executeWithSig(
            address(ACCESS_CONTROLLER),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipId),
                address(this),
                address(LICENSING_MODULE),
                selector,
                AccessPermission.ALLOW
            ),
            signer,
            deadline,
            signature
        );
    }

    //
    // Upgrade
    //

    /// @dev Returns the storage struct of SPG.
    function _getSPGStorage() private pure returns (SPGStorage storage $) {
        assembly {
            $.slot := SPGStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
