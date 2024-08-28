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

import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { GroupNFT } from "@storyprotocol/core/GroupNFT.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { ILicensingHook } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingHook.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/ILicenseTemplate.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
// solhint-disable-next-line max-line-length
import { IPILicenseTemplate, PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { IStoryProtocolGateway } from "./interfaces/IStoryProtocolGateway.sol";
import { ISPGNFT } from "./interfaces/ISPGNFT.sol";
import { Errors } from "./lib/Errors.sol";
import { SPGNFTLib } from "./lib/SPGNFTLib.sol";

contract StoryProtocolGateway is
    IStoryProtocolGateway,
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

    /// @notice The address of the Access Controller.
    IAccessController public immutable ACCESS_CONTROLLER;

    /// @notice The address of the IP Asset Registry.
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice The address of the Licensing Module.
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice The address of the License Registry.
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice The address of the Royalty Module.
    IRoyaltyModule public immutable ROYALTY_MODULE;

    /// @notice The address of the Core Metadata Module.
    ICoreMetadataModule public immutable CORE_METADATA_MODULE;

    /// @notice The address of the PIL License Template.
    IPILicenseTemplate public immutable PIL_TEMPLATE;

    /// @notice The address of the License Token.
    ILicenseToken public immutable LICENSE_TOKEN;

    /// @notice The address of the Grouping Module.
    IGroupingModule public immutable GROUPING_MODULE;

    /// @notice The address of the Group NFT contract.
    GroupNFT public immutable GROUP_NFT;

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
        address licenseRegistry,
        address royaltyModule,
        address coreMetadataModule,
        address pilTemplate,
        address licenseToken,
        address groupingModule,
        address groupNft
    ) {
        if (
            accessController == address(0) ||
            ipAssetRegistry == address(0) ||
            licensingModule == address(0) ||
            licenseRegistry == address(0) ||
            royaltyModule == address(0) ||
            coreMetadataModule == address(0) ||
            licenseToken == address(0) ||
            groupingModule == address(0) ||
            groupNft == address(0)
        ) revert Errors.SPG__ZeroAddressParam();

        ACCESS_CONTROLLER = IAccessController(accessController);
        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        CORE_METADATA_MODULE = ICoreMetadataModule(coreMetadataModule);
        PIL_TEMPLATE = IPILicenseTemplate(pilTemplate);
        LICENSE_TOKEN = ILicenseToken(licenseToken);
        GROUPING_MODULE = IGroupingModule(groupingModule);
        GROUP_NFT = GroupNFT(groupNft);

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
        tokenId = ISPGNFT(spgNftContract).mintBySPG({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        _setMetadata(ipMetadata, ipId);
        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Registers an NFT as IP with metadata.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @return ipId The ID of the newly registered IP
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
    /// @return licenseTermsId The ID of the newly registered PIL terms.
    function registerPILTermsAndAttach(
        address ipId,
        PILTerms calldata terms
    ) external returns (uint256 licenseTermsId) {
        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);
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
        tokenId = ISPGNFT(spgNftContract).mintBySPG({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        _setMetadata(ipMetadata, ipId);

        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);
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
        _setMetadataWithSig(ipMetadata, ipId, sigMetadata);
        _setPermissionForModule(
            ipId,
            sigAttach,
            address(LICENSING_MODULE),
            ILicensingModule.attachLicenseTerms.selector
        );
        licenseTermsId = _registerPILTermsAndAttach(ipId, terms);
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
        tokenId = ISPGNFT(spgNftContract).mintBySPG({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        _setMetadata(ipMetadata, ipId);

        _collectMintFeesAndSetApproval(
            msg.sender,
            ipId,
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
        _setMetadataWithSig(ipMetadata, ipId, sigMetadata);
        _setPermissionForModule(
            ipId,
            sigRegister,
            address(LICENSING_MODULE),
            ILicensingModule.registerDerivative.selector
        );

        _collectMintFeesAndSetApproval(
            msg.sender,
            ipId,
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
        _collectLicenseTokens(licenseTokenIds);

        tokenId = ISPGNFT(spgNftContract).mintBySPG({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        _setMetadata(ipMetadata, ipId);

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
        _collectLicenseTokens(licenseTokenIds);

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

    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP, attach
    /// Programmable IP License Terms to the registered IP, and add it to a group IP.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param groupId The ID of the group IP to add the newly registered IP.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param licenseTermsId The ID of the registered PIL terms that will be attached to the newly registered IP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param sigAddToGroup Signature data for addIp to the group IP via the Grouping Module.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIpAndAttachPILTermsAndAddToGroup(
        address spgNftContract,
        address groupId,
        address recipient,
        uint256 licenseTermsId,
        IPMetadata calldata ipMetadata,
        SignatureData calldata sigAddToGroup
    ) external onlyCallerWithMinterRole(spgNftContract) returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(spgNftContract).mintBySPG({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        _setMetadata(ipMetadata, ipId);

        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);

        _setPermissionForModule(groupId, sigAddToGroup, address(GROUPING_MODULE), IGroupingModule.addIp.selector);

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId;
        GROUPING_MODULE.addIp(groupId, ipIds);

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register an NFT as IP with metadata, attach Programmable IP License Terms to the registered IP,
    /// and add it to a group IP.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param groupId The ID of the group IP to add the newly registered IP.
    /// @param licenseTermsId The ID of the registered PIL terms that will be attached to the newly registered IP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadataAndAttach Signature data for setAll (metadata) and attachLicenseTerms to the IP
    /// via the Core Metadata Module and Licensing Module.
    /// @param sigAddToGroup Signature data for addIp to the group IP via the Grouping Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIpAndAttachPILTermsAndAddToGroup(
        address nftContract,
        uint256 tokenId,
        address groupId,
        uint256 licenseTermsId,
        IPMetadata calldata ipMetadata,
        SignatureData calldata sigMetadataAndAttach,
        SignatureData calldata sigAddToGroup
    ) external returns (address ipId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);

        address[] memory modules = new address[](2);
        bytes4[] memory selectors = new bytes4[](2);
        modules[0] = address(CORE_METADATA_MODULE);
        modules[1] = address(LICENSING_MODULE);
        selectors[0] = ICoreMetadataModule.setAll.selector;
        selectors[1] = ILicensingModule.attachLicenseTerms.selector;

        _setBatchPermissionForModules(ipId, sigMetadataAndAttach, modules, selectors);

        _setMetadata(ipMetadata, ipId);

        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);

        _setPermissionForModule(groupId, sigAddToGroup, address(GROUPING_MODULE), IGroupingModule.addIp.selector);

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId;
        GROUPING_MODULE.addIp(groupId, ipIds);
    }

    /// @notice Register a group IP with a group reward pool, register Programmable IP License Terms,
    /// attach it to the group IP, and add individual IPs to the group IP.
    /// @dev ipIds must be have the same PIL terms as the group IP.
    /// @param groupPool The address of the group reward pool.
    /// @param ipIds The IDs of the IPs to add to the newly registered group IP.
    /// @param groupIpTerms The PIL terms to be registered and attached to the newly registered group IP.
    /// @return groupId The ID of the newly registered group IP.
    /// @return groupLicenseTermsId The ID of the newly registered PIL terms.
    function registerGroupAndAttachPILTermsAndAddIps(
        address groupPool,
        address[] calldata ipIds,
        PILTerms calldata groupIpTerms
    ) external returns (address groupId, uint256 groupLicenseTermsId) {
        groupId = GROUPING_MODULE.registerGroup(groupPool);

        groupLicenseTermsId = _registerPILTermsAndAttach(groupId, groupIpTerms);

        GROUPING_MODULE.addIp(groupId, ipIds);

        GROUP_NFT.safeTransferFrom(address(this), msg.sender, GROUP_NFT.totalSupply() - 1);
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

        // Returns the license terms ID if already attached.
        if (LICENSE_REGISTRY.hasIpAttachedLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId))
            return licenseTermsId;

        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
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

    /// @dev Sets batch permission via signature to allow this contract to interact with mutiple modules
    /// on behalf of the provided IP Account.
    /// @param ipId The ID of the IP.
    /// @param sigData Signature data for setting the batch permission.
    /// @param modules The addresses of the modules to set the permission for.
    /// @param selectors The selectors of the functions to be permitted for execution.
    function _setBatchPermissionForModules(
        address ipId,
        SignatureData calldata sigData,
        address[] memory modules,
        bytes4[] memory selectors
    ) internal {
        // assumes modules and selectors must have a 1:1 mapping
        AccessPermission.Permission[] memory permissionList = new AccessPermission.Permission[](modules.length);
        for (uint256 i = 0; i < modules.length; i++) {
            permissionList[i] = AccessPermission.Permission({
                ipAccount: ipId,
                signer: address(this),
                to: modules[i],
                func: selectors[i],
                permission: AccessPermission.ALLOW
            });
        }

        IIPAccount(payable(ipId)).executeWithSig(
            address(ACCESS_CONTROLLER),
            0,
            abi.encodeWithSelector(IAccessController.setBatchPermissions.selector, permissionList),
            sigData.signer,
            sigData.deadline,
            sigData.signature
        );
    }

    /// @dev Sets the metadata for the given IP if metadata is non-empty.
    /// @dev Sets the metadata for the given IP if metadata is non-empty.
    /// @param ipMetadata The metadata to set.
    /// @param ipId The ID of the IP.
    function _setMetadata(IPMetadata calldata ipMetadata, address ipId) internal {
        if (
            keccak256(abi.encodePacked(ipMetadata.ipMetadataURI)) != keccak256("") ||
            ipMetadata.ipMetadataHash != bytes32(0) ||
            ipMetadata.nftMetadataHash != bytes32(0)
        ) {
            CORE_METADATA_MODULE.setAll(
                ipId,
                ipMetadata.ipMetadataURI,
                ipMetadata.ipMetadataHash,
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

    /// @dev Collects license tokens from the caller. Assumes SPG has permission to transfer the license tokens.
    /// @param licenseTokenIds The IDs of the license tokens to be collected.
    function _collectLicenseTokens(uint256[] calldata licenseTokenIds) internal {
        if (licenseTokenIds.length == 0) revert Errors.SPG__EmptyLicenseTokens();
        for (uint256 i = 0; i < licenseTokenIds.length; i++) {
            address tokenOwner = LICENSE_TOKEN.ownerOf(licenseTokenIds[i]);

            if (tokenOwner == address(this)) continue;
            if (tokenOwner != address(msg.sender))
                revert Errors.SPG__CallerAndNotTokenOwner(licenseTokenIds[i], msg.sender, tokenOwner);

            LICENSE_TOKEN.safeTransferFrom(msg.sender, address(this), licenseTokenIds[i]);
        }
    }

    /// @dev Collect mint fees for all parent IPs from the payer and set approval for Royalty Module to spend mint fees.
    /// @param payerAddress The address of the payer for the license mint fees.
    /// @param childIpId The ID of the derivative IP.
    /// @param licenseTemplate The address of the license template.
    /// @param parentIpIds The IDs of all the parent IPs.
    /// @param licenseTermsIds The IDs of the license terms for each corresponding parent IP.
    function _collectMintFeesAndSetApproval(
        address payerAddress,
        address childIpId,
        address licenseTemplate,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds
    ) internal {
        // Get currency token and royalty policy, assumes all parent IPs have the same currency token.
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        (address royaltyPolicy, , , address mintFeeCurrencyToken) = lct.getRoyaltyPolicy(licenseTermsIds[0]);

        if (royaltyPolicy != address(0)) {
            // Get total mint fee for all parent IPs
            uint256 totalMintFee = _aggregateMintFees(parentIpIds, childIpId, licenseTemplate, licenseTermsIds);

            if (totalMintFee != 0) {
                // Transfer mint fee from payer to this contract
                IERC20(mintFeeCurrencyToken).safeTransferFrom(payerAddress, address(this), totalMintFee);

                // Approve Royalty Policy to spend mint fee
                IERC20(mintFeeCurrencyToken).forceApprove(address(ROYALTY_MODULE), totalMintFee);
            }
        }
    }

    /// @dev Aggregate license mint fees for all parent IPs.
    /// @param parentIpIds The IDs of all the parent IPs.
    /// @param childIpId The ID of the derivative IP.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsIds The IDs of the license terms for each corresponding parent IP.
    /// @return totalMintFee The sum of license mint fees across all parent IPs.
    function _aggregateMintFees(
        address[] calldata parentIpIds,
        address childIpId,
        address licenseTemplate,
        uint256[] calldata licenseTermsIds
    ) internal returns (uint256 totalMintFee) {
        totalMintFee = 0;

        for (uint256 i = 0; i < parentIpIds.length; i++) {
            totalMintFee += _getMintFeeForSingleParent(
                childIpId,
                parentIpIds[i],
                licenseTemplate,
                licenseTermsIds[i],
                1
            );
        }
    }

    /// @dev Fetch the license token mint fee from the licensing hook or license terms for the given parent IP.
    /// @param childIpId The ID of the derivative IP.
    /// @param parentIpId The ID of the parent IP.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms for the parent IP.
    /// @param amount The amount of licenses to mint.
    /// @return The mint fee for the given parent IP.
    function _getMintFeeForSingleParent(
        address childIpId,
        address parentIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount
    ) internal returns (uint256) {
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);

        // Get mint fee set by license terms
        (address royaltyPolicy, , uint256 mintFeeSetByLicenseTerms, ) = lct.getRoyaltyPolicy(licenseTermsId);

        // If no royalty policy, return 0
        if (royaltyPolicy == address(0)) return 0;

        uint256 mintFeeSetByHook = 0;

        Licensing.LicensingConfig memory licensingConfig = LICENSE_REGISTRY.getLicensingConfig(
            parentIpId,
            licenseTemplate,
            licenseTermsId
        );

        // Get mint fee from licensing hook
        if (licensingConfig.licensingHook != address(0)) {
            mintFeeSetByHook = ILicensingHook(licensingConfig.licensingHook).beforeRegisterDerivative(
                address(this),
                childIpId,
                parentIpId,
                licenseTemplate,
                licenseTermsId,
                licensingConfig.hookData
            );
        }

        if (!licensingConfig.isSet) return mintFeeSetByLicenseTerms * amount;
        if (licensingConfig.licensingHook == address(0)) return licensingConfig.mintingFee * amount;

        return mintFeeSetByHook;
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
