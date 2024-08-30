// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";

import { IStoryProtocolGateway } from "./interfaces/IStoryProtocolGateway.sol";
import { ISPGNFT } from "./interfaces/ISPGNFT.sol";
import { Errors } from "./lib/Errors.sol";
import { BaseWorkflow } from "./BaseWorkflow.sol";
import { MetadataHelper } from "./lib/MetadataHelper.sol";
import { LicensingHelper } from "./lib/LicensingHelper.sol";
import { PermissionHelper } from "./lib/PermissionHelper.sol";

/// @title Story Protocol Gateway
/// @notice The Story Protocol Gateway is the peripheral smart contract for interacting with
/// Story's Proof of Creativity protocol.
contract StoryProtocolGateway is
    IStoryProtocolGateway,
    BaseWorkflow,
    MulticallUpgradeable,
    ERC721Holder,
    AccessManagedUpgradeable,
    UUPSUpgradeable
{
    using ERC165Checker for address;
    using SafeERC20 for IERC20;

    /// @dev Storage structure for the SPG
    /// @param nftContractBeacon The address of the NFT contract beacon.
    /// @custom:storage-location erc7201:story-protocol-periphery.SPG
    struct SPGStorage {
        address nftContractBeacon;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.SPG")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant SPGStorageLocation = 0xb4cca15568cb3dbdd3e7ab1af5e15d861de93bb129f4c24bf0ef4e27377e7300;

    /// @notice The address of the Royalty Module.
    IRoyaltyModule public immutable ROYALTY_MODULE;

    /// @notice The address of the License Token.
    ILicenseToken public immutable LICENSE_TOKEN;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAssetRegistry,
        address licensingModule,
        address licenseRegistry,
        address royaltyModule,
        address coreMetadataModule,
        address pilTemplate,
        address licenseToken
    )
        BaseWorkflow(
            accessController,
            coreMetadataModule,
            ipAssetRegistry,
            licensingModule,
            licenseRegistry,
            pilTemplate
        )
    {
        if (
            accessController == address(0) ||
            ipAssetRegistry == address(0) ||
            licensingModule == address(0) ||
            licenseRegistry == address(0) ||
            royaltyModule == address(0) ||
            coreMetadataModule == address(0) ||
            licenseToken == address(0)
        ) revert Errors.SPG__ZeroAddressParam();

        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
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

    /// @notice Mint an NFT from a SPGNFT collection and register it with metadata as an IP.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIp(
        address spgNftContract,
        address recipient,
        IPMetadata calldata ipMetadata
    ) external onlyCallerWithMinterRole(spgNftContract) returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(spgNftContract).mintByPeriphery({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI
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
        IPMetadata calldata ipMetadata,
        SignatureData calldata sigMetadata
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

    /// @notice Register Programmable IP License Terms (if unregistered) and attach it to IP.
    /// @param ipId The ID of the IP.
    /// @param terms The PIL terms to be registered.
    /// @return licenseTermsId The ID of the newly registered PIL terms.
    function registerPILTermsAndAttach(
        address ipId,
        PILTerms calldata terms
    ) external returns (uint256 licenseTermsId) {
        licenseTermsId = LicensingHelper.registerPILTermsAndAttach(
            ipId,
            address(PIL_TEMPLATE),
            address(LICENSING_MODULE),
            address(LICENSE_REGISTRY),
            terms
        );
    }

    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP,
    /// register Programmable IP License
    /// Terms (if unregistered), and attach it to the registered IP.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param terms The PIL terms to be registered.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    /// @return licenseTermsId The ID of the newly registered PIL terms.
    function mintAndRegisterIpAndAttachPILTerms(
        address spgNftContract,
        address recipient,
        IPMetadata calldata ipMetadata,
        PILTerms calldata terms
    )
        external
        onlyCallerWithMinterRole(spgNftContract)
        returns (address ipId, uint256 tokenId, uint256 licenseTermsId)
    {
        tokenId = ISPGNFT(spgNftContract).mintByPeriphery({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        licenseTermsId = LicensingHelper.registerPILTermsAndAttach(
            ipId,
            address(PIL_TEMPLATE),
            address(LICENSING_MODULE),
            address(LICENSE_REGISTRY),
            terms
        );

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register a given NFT as an IP and attach Programmable IP License Terms.
    /// @dev Because IP Account is created in this function, we need to set the permission via signature to allow this
    /// contract to attach PIL Terms to the newly created IP Account in the same function.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param terms The PIL terms to be registered.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigAttach Signature data for attachLicenseTerms to the IP via the Licensing Module.
    /// @return ipId The ID of the newly registered IP.
    /// @return licenseTermsId The ID of the newly registered PIL terms.
    function registerIpAndAttachPILTerms(
        address nftContract,
        uint256 tokenId,
        IPMetadata calldata ipMetadata,
        PILTerms calldata terms,
        SignatureData calldata sigMetadata,
        SignatureData calldata sigAttach
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
            address(LICENSE_REGISTRY),
            terms
        );
    }

    /// @notice Mint an NFT from a SPGNFT collection and register it as a derivative IP without license tokens.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param derivData The derivative data to be used for registerDerivative.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param recipient The address to receive the minted NFT.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIpAndMakeDerivative(
        address spgNftContract,
        MakeDerivative calldata derivData,
        IPMetadata calldata ipMetadata,
        address recipient
    ) external onlyCallerWithMinterRole(spgNftContract) returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(spgNftContract).mintByPeriphery({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);

        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        LicensingHelper.collectMintFeesAndSetApproval(
            msg.sender,
            ipId,
            address(ROYALTY_MODULE),
            address(LICENSE_REGISTRY),
            derivData.licenseTemplate,
            derivData.parentIpIds,
            derivData.licenseTermsIds
        );

        LICENSING_MODULE.registerDerivative({
            childIpId: ipId,
            parentIpIds: derivData.parentIpIds,
            licenseTermsIds: derivData.licenseTermsIds,
            licenseTemplate: derivData.licenseTemplate,
            royaltyContext: derivData.royaltyContext
        });

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register the given NFT as a derivative IP with metadata without license tokens.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param derivData The derivative data to be used for registerDerivative.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigRegister Signature data for registerDerivative for the IP via the Licensing Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIpAndMakeDerivative(
        address nftContract,
        uint256 tokenId,
        MakeDerivative calldata derivData,
        IPMetadata calldata ipMetadata,
        SignatureData calldata sigMetadata,
        SignatureData calldata sigRegister
    ) external returns (address ipId) {
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
            ILicensingModule.registerDerivative.selector,
            sigRegister
        );

        LicensingHelper.collectMintFeesAndSetApproval(
            msg.sender,
            ipId,
            address(ROYALTY_MODULE),
            address(LICENSE_REGISTRY),
            derivData.licenseTemplate,
            derivData.parentIpIds,
            derivData.licenseTermsIds
        );

        LICENSING_MODULE.registerDerivative({
            childIpId: ipId,
            parentIpIds: derivData.parentIpIds,
            licenseTermsIds: derivData.licenseTermsIds,
            licenseTemplate: derivData.licenseTemplate,
            royaltyContext: derivData.royaltyContext
        });
    }

    /// @notice Mint an NFT from a collection and register it as a derivative IP using license tokens
    /// @dev Caller must have the minter role for the provided SPG NFT. Caller must own the license tokens and have
    /// approved SPG to transfer them.
    /// @param spgNftContract The address of the NFT collection.
    /// @param licenseTokenIds The IDs of the license tokens to be burned for linking the IP to parent IPs.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and newly registered IP.
    /// @param recipient The address to receive the minted NFT.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function mintAndRegisterIpAndMakeDerivativeWithLicenseTokens(
        address spgNftContract,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext,
        IPMetadata calldata ipMetadata,
        address recipient
    ) external onlyCallerWithMinterRole(spgNftContract) returns (address ipId, uint256 tokenId) {
        LicensingHelper.collectLicenseTokens(licenseTokenIds, address(LICENSE_TOKEN));

        tokenId = ISPGNFT(spgNftContract).mintByPeriphery({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        LICENSING_MODULE.registerDerivativeWithLicenseTokens(ipId, licenseTokenIds, royaltyContext);

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register the given NFT as a derivative IP using license tokens.
    /// @dev Caller must own the license tokens and have approved SPG to transfer them.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param licenseTokenIds The IDs of the license tokens to be burned for linking the IP to parent IPs.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigRegister Signature data for registerDerivativeWithLicenseTokens for the IP via the Licensing Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIpAndMakeDerivativeWithLicenseTokens(
        address nftContract,
        uint256 tokenId,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext,
        IPMetadata calldata ipMetadata,
        SignatureData calldata sigMetadata,
        SignatureData calldata sigRegister
    ) external returns (address ipId) {
        LicensingHelper.collectLicenseTokens(licenseTokenIds, address(LICENSE_TOKEN));

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
            ILicensingModule.registerDerivativeWithLicenseTokens.selector,
            sigRegister
        );
        LICENSING_MODULE.registerDerivativeWithLicenseTokens(ipId, licenseTokenIds, royaltyContext);
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
