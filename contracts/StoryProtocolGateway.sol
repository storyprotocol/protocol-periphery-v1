// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";
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

contract StoryProtocolGateway is IStoryProtocolGateway, AccessManagedUpgradeable, UUPSUpgradeable {
    using ERC165Checker for address;

    /// @dev Storage structure for the SPG
    /// @param nftContractBeacon The address of the NFT contract beacon.
    /// @custom:storage-location erc7201:story-protocol-periphery.SPG
    struct SPGStorage {
        address nftContractBeacon;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.SPG")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant SPGStorageLocation = 0xb4cca15568cb3dbdd3e7ab1af5e15d861de93bb129f4c24bf0ef4e27377e7300;

    /// @notice The address of the Access Controller.
    IAccessController public immutable ACCESS_CONTROLLER;

    /// @notice The address of the IP Asset Registry.
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice The address of the Licensing Module.
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice The address of the Core Metadata Module.
    ICoreMetadataModule public immutable CORE_METADATA_MODULE;

    /// @notice The address of the PIL License Template.
    IPILicenseTemplate public immutable PIL_TEMPLATE;

    /// @notice The address of the License Token.
    ILicenseToken public immutable LICENSE_TOKEN;

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
        address pilTemplate,
        address licenseToken
    ) {
        if (
            accessController == address(0) ||
            ipAssetRegistry == address(0) ||
            licensingModule == address(0) ||
            coreMetadataModule == address(0) ||
            licenseToken == address(0)
        ) revert Errors.SPG__ZeroAddressParam();

        ACCESS_CONTROLLER = IAccessController(accessController);
        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        CORE_METADATA_MODULE = ICoreMetadataModule(coreMetadataModule);
        PIL_TEMPLATE = IPILicenseTemplate(pilTemplate);
        LICENSE_TOKEN = ILicenseToken(licenseToken);

        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.SPG__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @dev Sets the NFT contract beacon address.
    /// @param newNftContractBeacon The address of the new NFT contract beacon.
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
    /// @param mintFee The cost to mint an NFT from the collection.
    /// @param mintFeeToken The token to be used for mint payment.
    /// @param owner The owner of the collection.
    /// @return nftContract The address of the newly created NFT collection.
    function createCollection(
        string calldata name,
        string calldata symbol,
        uint32 maxSupply,
        uint256 mintFee,
        address mintFeeToken,
        address owner
    ) external returns (address nftContract) {
        nftContract = address(new BeaconProxy(_getSPGStorage().nftContractBeacon, ""));
        ISPGNFT(nftContract).initialize(name, symbol, maxSupply, mintFee, mintFeeToken, owner);
        emit CollectionCreated(nftContract);
    }

    /// @notice Mint an NFT from a collection and register it with metadata as an IP.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param nftContract The address of the NFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param nftMetadata OPTIONAL. The desired metadata for the newly minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function mintAndRegisterIp(
        address nftContract,
        address recipient,
        string calldata nftMetadata,
        IPMetadata calldata ipMetadata
    ) external onlyCallerWithMinterRole(nftContract) returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(nftContract).mintBySPG({ to: address(this), payer: msg.sender, nftMetadata: nftMetadata });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _setMetadata(ipMetadata, ipId);
        ISPGNFT(nftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Registers an NFT as IP with metadata.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @return ipId The ID of the registered IP.
    function registerIp(
        address nftContract,
        uint256 tokenId,
        IPMetadata calldata ipMetadata,
        SignatureData calldata sigMetadata
    ) external returns (address ipId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _setMetadataWithSig(ipMetadata, ipId, sigMetadata);
    }

    /// @notice Register Programmable IP License Terms (if unregistered) and attach it to IP.
    /// @param ipId The ID of the IP.
    /// @param terms The PIL terms to be registered.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerPILTermsAndAttach(
        address ipId,
        PILTerms calldata terms
    ) external returns (uint256 licenseTermsId) {
        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);
    }

    /// @notice Mint an NFT from a collection, register it with metadata as an IP, register Programmable IP License
    /// Terms (if unregistered), and attach it to the registered IP.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param nftContract The address of the NFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param nftMetadata OPTIONAL. The desired metadata for the newly minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param terms The PIL terms to be registered.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function mintAndRegisterIpAndAttachPILTerms(
        address nftContract,
        address recipient,
        string calldata nftMetadata,
        IPMetadata calldata ipMetadata,
        PILTerms calldata terms
    ) external onlyCallerWithMinterRole(nftContract) returns (address ipId, uint256 tokenId, uint256 licenseTermsId) {
        tokenId = ISPGNFT(nftContract).mintBySPG({ to: address(this), payer: msg.sender, nftMetadata: nftMetadata });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _setMetadata(ipMetadata, ipId);

        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);
        ISPGNFT(nftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register a given NFT as an IP and attach Programmable IP License Terms.
    /// @dev Because IP Account is created in this function, we need to set the permission via signature to allow this
    /// contract to attach PIL Terms to the newly created IP Account in the same function.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param terms The PIL terms to be registered.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigAttach Signature data for attachLicenseTerms to the IP via the Licensing Module. The nonce of this
    /// signature must be one above `sigMetadata` if the metadata is being set, ie. `sigMetadata` is non-empty.
    /// @return ipId The ID of the registered IP.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerIpAndAttachPILTerms(
        address nftContract,
        uint256 tokenId,
        IPMetadata calldata ipMetadata,
        PILTerms calldata terms,
        SignatureData calldata sigMetadata,
        SignatureData calldata sigAttach
    ) external returns (address ipId, uint256 licenseTermsId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _setMetadataWithSig(ipMetadata, ipId, sigMetadata);
        _setPermissionForModule(
            ipId,
            sigAttach,
            address(LICENSING_MODULE),
            ILicensingModule.attachLicenseTerms.selector
        );
        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);
    }

    /// @notice Mint an NFT from a collection and register it as a derivative IP without license tokens.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param nftContract The address of the NFT collection.
    /// @param derivData The derivative data to be used for registerDerivative.
    /// @param nftMetadata OPTIONAL. The desired metadata for the newly minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function mintAndRegisterIpAndMakeDerivative(
        address nftContract,
        MakeDerivative calldata derivData,
        string calldata nftMetadata,
        IPMetadata calldata ipMetadata,
        address recipient
    ) external onlyCallerWithMinterRole(nftContract) returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(nftContract).mintBySPG({ to: address(this), payer: msg.sender, nftMetadata: nftMetadata });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _setMetadata(ipMetadata, ipId);

        LICENSING_MODULE.registerDerivative({
            childIpId: ipId,
            parentIpIds: derivData.parentIpIds,
            licenseTermsIds: derivData.licenseTermsIds,
            licenseTemplate: derivData.licenseTemplate,
            royaltyContext: derivData.royaltyContext
        });

        ISPGNFT(nftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register the given NFT as a derivative IP with metadata without using license tokens.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param derivData The derivative data to be used for registerDerivative.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigRegister Signature data for registerDerivative for the IP via the Licensing Module.
    /// @return ipId The ID of the registered IP.
    function registerIpAndMakeDerivative(
        address nftContract,
        uint256 tokenId,
        MakeDerivative calldata derivData,
        IPMetadata calldata ipMetadata,
        SignatureData calldata sigMetadata,
        SignatureData calldata sigRegister
    ) external returns (address ipId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _setMetadataWithSig(ipMetadata, ipId, sigMetadata);
        _setPermissionForModule(
            ipId,
            sigRegister,
            address(LICENSING_MODULE),
            ILicensingModule.registerDerivative.selector
        );
        LICENSING_MODULE.registerDerivative({
            childIpId: ipId,
            parentIpIds: derivData.parentIpIds,
            licenseTermsIds: derivData.licenseTermsIds,
            licenseTemplate: derivData.licenseTemplate,
            royaltyContext: derivData.royaltyContext
        });
    }

    /// @notice Mint an NFT from a collection and register it as a derivative IP using license tokens.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param nftContract The address of the NFT collection.
    /// @param licenseTokenIds The IDs of the license tokens to be burned for linking the IP to parent IPs.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    /// @param nftMetadata OPTIONAL. The desired metadata for the newly minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param recipient The address to receive the minted NFT.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function mintAndRegisterIpAndMakeDerivativeWithLicenseTokens(
        address nftContract,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext,
        string calldata nftMetadata,
        IPMetadata calldata ipMetadata,
        address recipient
    ) external onlyCallerWithMinterRole(nftContract) returns (address ipId, uint256 tokenId) {
        _transferLicenseTokens(licenseTokenIds);

        tokenId = ISPGNFT(nftContract).mintBySPG({ to: address(this), payer: msg.sender, nftMetadata: nftMetadata });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _setMetadata(ipMetadata, ipId);

        LICENSING_MODULE.registerDerivativeWithLicenseTokens(ipId, licenseTokenIds, royaltyContext);

        ISPGNFT(nftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register the given NFT as a derivative IP using license tokens.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param licenseTokenIds The IDs of the license tokens to be burned for linking the IP to parent IPs.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigRegister Signature data for registerDerivativeWithLicenseTokens for the IP via the Licensing Module.
    /// @return ipId The ID of the registered IP.
    function registerIpAndMakeDerivativeWithLicenseTokens(
        address nftContract,
        uint256 tokenId,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext,
        IPMetadata calldata ipMetadata,
        SignatureData calldata sigMetadata,
        SignatureData calldata sigRegister
    ) external returns (address ipId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);
        _setMetadataWithSig(ipMetadata, ipId, sigMetadata);
        _setPermissionForModule(
            ipId,
            sigRegister,
            address(LICENSING_MODULE),
            ILicensingModule.registerDerivativeWithLicenseTokens.selector
        );
        LICENSING_MODULE.registerDerivativeWithLicenseTokens(ipId, licenseTokenIds, royaltyContext);
    }

    /// @dev Registers PIL License Terms and attaches them to the given IP.
    /// @param ipId The ID of the IP.
    /// @param terms The PIL terms to be registered.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function _registerPILTermsAndAttach(
        address ipId,
        PILTerms calldata terms
    ) internal returns (uint256 licenseTermsId) {
        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(terms);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
    }

    /// @dev Transfers the license tokens from the caller to this contract.
    /// @param licenseTokenIds The IDs of the license tokens to be transferred.
    function _transferLicenseTokens(uint256[] calldata licenseTokenIds) internal {
        if (licenseTokenIds.length == 0) revert Errors.SPG__EmptyLicenseTokens();
        for (uint256 i = 0; i < licenseTokenIds.length; i++) {
            if (LICENSE_TOKEN.ownerOf(licenseTokenIds[i]) == address(this)) continue;
            LICENSE_TOKEN.transferFrom(msg.sender, address(this), licenseTokenIds[i]);
        }
    }

    /// @dev Sets permission via signature to allow this contract to interact with the Licensing Module on behalf of the
    /// provided IP Account.
    /// @param ipId The ID of the IP.
    /// @param sigData Signature data for setting the permission.
    /// @param module The address of the module to set the permission for.
    /// @param selector The selector of the function to be permitted for execution.
    function _setPermissionForModule(
        address ipId,
        SignatureData calldata sigData,
        address module,
        bytes4 selector
    ) internal {
        IIPAccount(payable(ipId)).executeWithSig(
            address(ACCESS_CONTROLLER),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipId),
                address(this),
                address(module),
                selector,
                AccessPermission.ALLOW
            ),
            sigData.signer,
            sigData.deadline,
            sigData.signature
        );
    }

    /// @dev Sets the metadata for the given IP if metadata is non-empty.
    /// @param ipMetadata The metadata to set.
    /// @param ipId The ID of the IP.
    function _setMetadata(IPMetadata calldata ipMetadata, address ipId) internal {
        if (
            keccak256(abi.encodePacked(ipMetadata.metadataURI)) != keccak256("") ||
            ipMetadata.metadataHash != bytes32(0) ||
            ipMetadata.nftMetadataHash != bytes32(0)
        ) {
            CORE_METADATA_MODULE.setAll(
                ipId,
                ipMetadata.metadataURI,
                ipMetadata.metadataHash,
                ipMetadata.nftMetadataHash
            );
        }
    }

    /// @dev Sets the permission for SPG to set the metadata for the given IP, and the metadata for the given IP if
    /// metadata is non-empty and sets the metadata via signature.
    /// @param ipMetadata The metadata to set.
    /// @param ipId The ID of the IP.
    /// @param sigData Signature data for setAll for this IP by SPG via the Core Metadata Module.
    function _setMetadataWithSig(
        IPMetadata calldata ipMetadata,
        address ipId,
        SignatureData calldata sigData
    ) internal {
        if (sigData.signer != address(0) && sigData.deadline != 0 && sigData.signature.length != 0) {
            _setPermissionForModule(ipId, sigData, address(CORE_METADATA_MODULE), ICoreMetadataModule.setAll.selector);
        }
        _setMetadata(ipMetadata, ipId);
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
