// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { GroupNFT } from "@storyprotocol/core/GroupNFT.sol";
import { RoyaltyModule } from "@storyprotocol/core/modules/royalty/RoyaltyModule.sol";

import { BaseWorkflow } from "../BaseWorkflow.sol";
import { Errors } from "../lib/Errors.sol";
import { IGroupingWorkflows } from "../interfaces/workflows/IGroupingWorkflows.sol";
import { ISPGNFT } from "../interfaces/ISPGNFT.sol";
import { LicensingHelper } from "../lib/LicensingHelper.sol";
import { MetadataHelper } from "../lib/MetadataHelper.sol";
import { PermissionHelper } from "../lib/PermissionHelper.sol";
import { WorkflowStructs } from "../lib/WorkflowStructs.sol";

/// @title Grouping Workflows
/// @notice Each workflow bundles multiple core protocol operations into a single function to simplify interaction
/// with Group IP features in the Story Proof-of-Creativity Protocol.
contract GroupingWorkflows is
    IGroupingWorkflows,
    BaseWorkflow,
    MulticallUpgradeable,
    AccessManagedUpgradeable,
    UUPSUpgradeable
{
    using ERC165Checker for address;

    /// @dev Storage structure for the GroupingWorkflows
    /// @param nftContractBeacon The address of the NFT contract beacon.
    /// @custom:storage-location erc7201:story-protocol-periphery.GroupingWorkflows
    struct GroupingWorkflowsStorage {
        address nftContractBeacon;
    }

    // solhint-disable-next-line max-line-length
    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.GroupingWorkflows")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant GroupingWorkflowsStorageLocation =
        0xa8ddbb5f662015e2b3d6b4c61921979ad3d3d1d19e338b1c4ba6a196b10c6400;

    /// @notice The address of the Grouping Module.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupingModule public immutable GROUPING_MODULE;

    /// @notice The address of the Group NFT contract.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    GroupNFT public immutable GROUP_NFT;

    /// @notice The address of the Royalty Module.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    RoyaltyModule public immutable ROYALTY_MODULE;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address coreMetadataModule,
        address groupingModule,
        address groupNft,
        address ipAssetRegistry,
        address licenseRegistry,
        address licensingModule,
        address pilTemplate,
        address royaltyModule
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
            groupingModule == address(0) ||
            groupNft == address(0) ||
            ipAssetRegistry == address(0) ||
            licenseRegistry == address(0) ||
            licensingModule == address(0) ||
            pilTemplate == address(0) ||
            royaltyModule == address(0)
        ) revert Errors.GroupingWorkflows__ZeroAddressParam();

        GROUPING_MODULE = IGroupingModule(groupingModule);
        GROUP_NFT = GroupNFT(groupNft);
        ROYALTY_MODULE = RoyaltyModule(royaltyModule);
        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.GroupingWorkflows__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @dev Sets the NFT contract beacon address.
    /// @param newNftContractBeacon The address of the new NFT contract beacon.
    function setNftContractBeacon(address newNftContractBeacon) external restricted {
        if (newNftContractBeacon == address(0)) revert Errors.GroupingWorkflows__ZeroAddressParam();
        GroupingWorkflowsStorage storage $ = _getGroupingWorkflowsStorage();
        $.nftContractBeacon = newNftContractBeacon;
    }

    /// @notice Mint an NFT from a SPGNFT collection, register it with metadata as an IP, attach
    /// license terms to the registered IP, and add it to a group IP.
    /// @dev Requires caller to have the minter role or the SPG NFT to allow public minting.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param groupId The ID of the group IP to add the newly registered IP.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param licensesData The data of the licenses and their configurations to be attached to the new IP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param sigAddToGroup Signature data for addIp to the group IP via the Grouping Module.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIpAndAttachLicenseAndAddToGroup(
        address spgNftContract,
        address groupId,
        address recipient,
        WorkflowStructs.LicenseData[] calldata licensesData,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.SignatureData calldata sigAddToGroup,
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

        _attachLicensesAndSetConfigs(ipId, licensesData);

        PermissionHelper.setPermissionForModule(
            groupId,
            address(GROUPING_MODULE),
            address(ACCESS_CONTROLLER),
            IGroupingModule.addIp.selector,
            sigAddToGroup
        );

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId;
        GROUPING_MODULE.addIp(groupId, ipIds);

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register an NFT as IP with metadata, attach license terms to the registered IP,
    /// and add it to a group IP.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param groupId The ID of the group IP to add the newly registered IP.
    /// @param licensesData The data of the licenses and their configurations to be attached to the new IP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadataAndAttachAndConfig Signature data for setAll (metadata), attachLicenseTerms, and
    /// setLicensingConfig to the IP via the Core Metadata Module and Licensing Module.
    /// @param sigAddToGroup Signature data for addIp to the group IP via the Grouping Module.
    /// @return ipId The ID of the newly registered IP.
    function registerIpAndAttachLicenseAndAddToGroup(
        address nftContract,
        uint256 tokenId,
        address groupId,
        WorkflowStructs.LicenseData[] calldata licensesData,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.SignatureData calldata sigMetadataAndAttachAndConfig,
        WorkflowStructs.SignatureData calldata sigAddToGroup
    ) external returns (address ipId) {
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

        _attachLicensesAndSetConfigs(ipId, licensesData);

        PermissionHelper.setPermissionForModule(
            groupId,
            address(GROUPING_MODULE),
            address(ACCESS_CONTROLLER),
            IGroupingModule.addIp.selector,
            sigAddToGroup
        );

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId;
        GROUPING_MODULE.addIp(groupId, ipIds);
    }

    /// @notice Register a group IP with a group reward pool and attach license terms to the group IP
    /// @param groupPool The address of the group reward pool.
    /// @param licenseData The data of the license and its configuration to be attached to the new group IP.
    /// @return groupId The ID of the newly registered group IP.
    function registerGroupAndAttachLicense(
        address groupPool,
        WorkflowStructs.LicenseData calldata licenseData
    ) external returns (address groupId) {
        groupId = GROUPING_MODULE.registerGroup(groupPool);

        LicensingHelper.attachLicenseTermsAndSetConfigs(
            groupId,
            address(LICENSING_MODULE),
            licenseData.licenseTemplate,
            licenseData.licenseTermsId,
            licenseData.licensingConfig
        );

        GROUP_NFT.safeTransferFrom(address(this), msg.sender, GROUP_NFT.totalSupply() - 1);
    }

    /// @notice Register a group IP with a group reward pool, attach license terms to the group IP,
    /// and add individual IPs to the group IP.
    /// @dev ipIds must have the same PIL terms as the group IP.
    /// @param groupPool The address of the group reward pool.
    /// @param ipIds The IDs of the IPs to add to the newly registered group IP.
    /// @param licenseData The data of the license and its configuration to be attached to the new group IP.
    /// @return groupId The ID of the newly registered group IP.
    function registerGroupAndAttachLicenseAndAddIps(
        address groupPool,
        address[] calldata ipIds,
        WorkflowStructs.LicenseData calldata licenseData
    ) external returns (address groupId) {
        groupId = GROUPING_MODULE.registerGroup(groupPool);

        LicensingHelper.attachLicenseTermsAndSetConfigs(
            groupId,
            address(LICENSING_MODULE),
            licenseData.licenseTemplate,
            licenseData.licenseTermsId,
            licenseData.licensingConfig
        );

        GROUPING_MODULE.addIp(groupId, ipIds);

        GROUP_NFT.safeTransferFrom(address(this), msg.sender, GROUP_NFT.totalSupply() - 1);
    }

    /// @notice Collect royalties for the entire group and distribute the rewards to each member IP's royalty vault
    /// @param groupIpId The ID of the group IP.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim.
    /// @param memberIpIds The IDs of the member IPs to distribute the rewards to.
    /// @return collectedRoyalties The amounts of royalties collected for each currency token.
    function collectRoyaltiesAndClaimReward(
        address groupIpId,
        address[] calldata currencyTokens,
        address[] calldata memberIpIds
    ) external returns (uint256[] memory collectedRoyalties) {
        (address groupLicenseTemplate, uint256 groupLicenseTermsId) = LICENSE_REGISTRY.getAttachedLicenseTerms(
            groupIpId,
            0
        );

        for (uint256 i = 0; i < memberIpIds.length; i++) {
            // check if given member IPs already have a royalty vault
            if (ROYALTY_MODULE.ipRoyaltyVaults(memberIpIds[i]) == address(0)) {
                // mint license tokens to the member IPs if they don't have a royalty vault
                LICENSING_MODULE.mintLicenseTokens({
                    licensorIpId: memberIpIds[i],
                    licenseTemplate: groupLicenseTemplate,
                    licenseTermsId: groupLicenseTermsId,
                    amount: 1,
                    receiver: msg.sender,
                    royaltyContext: "",
                    maxMintingFee: 0
                });
            }
        }

        collectedRoyalties = new uint256[](currencyTokens.length);
        for (uint256 i = 0; i < currencyTokens.length; i++) {
            if (currencyTokens[i] == address(0)) revert Errors.GroupingWorkflows__ZeroAddressParam();
            collectedRoyalties[i] = GROUPING_MODULE.collectRoyalties(groupIpId, currencyTokens[i]);
            GROUPING_MODULE.claimReward(groupIpId, currencyTokens[i], memberIpIds);
        }
    }

    /// @dev Attaches licenses to the given IP and sets their licensing configurations.
    /// @param ipId The ID of the IP.
    /// @param licensesData The data of the licenses and their configurations to be attached to the IP.
    function _attachLicensesAndSetConfigs(address ipId, WorkflowStructs.LicenseData[] calldata licensesData) private {
        for (uint256 i; i < licensesData.length; i++) {
            LicensingHelper.attachLicenseTermsAndSetConfigs(
                ipId,
                address(LICENSING_MODULE),
                licensesData[i].licenseTemplate,
                licensesData[i].licenseTermsId,
                licensesData[i].licensingConfig
            );
        }
    }

    //
    // Upgrade
    //

    /// @dev Returns the storage struct of GroupingWorkflows.
    function _getGroupingWorkflowsStorage() private pure returns (GroupingWorkflowsStorage storage $) {
        assembly {
            $.slot := GroupingWorkflowsStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
