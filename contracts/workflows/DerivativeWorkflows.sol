// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/ILicenseTemplate.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { ILicensingHook } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingHook.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";

import { BaseWorkflow } from "../BaseWorkflow.sol";
import { Errors } from "../lib/Errors.sol";
import { IDerivativeWorkflows } from "../interfaces/IDerivativeWorkflows.sol";
import { ISPGNFT } from "../interfaces/ISPGNFT.sol";
import { MetadataHelper } from "../lib/MetadataHelper.sol";
import { PermissionHelper } from "../lib/PermissionHelper.sol";
import { WorkflowStructs } from "../lib/WorkflowStructs.sol";

/// @title Derivative Workflows
/// @notice Each workflow bundles multiple core protocol operations into a single function to simplify
/// the IP derivative registration process in the Story Proof-of-Creativity Protocol.
contract DerivativeWorkflows is
    IDerivativeWorkflows,
    BaseWorkflow,
    MulticallUpgradeable,
    AccessManagedUpgradeable,
    UUPSUpgradeable,
    ERC721Holder
{
    using ERC165Checker for address;
    using SafeERC20 for IERC20;

    /// @dev Storage structure for the DerivativeWorkflows
    /// @param nftContractBeacon The address of the NFT contract beacon.
    /// @custom:storage-location erc7201:story-protocol-periphery.DerivativeWorkflows
    struct DerivativeWorkflowsStorage {
        address nftContractBeacon;
    }

    // solhint-disable-next-line max-line-length
    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.DerivativeWorkflows")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant DerivativeWorkflowsStorageLocation =
        0xd52de5238bdb22c2473ee7a9de2482cc2f392e6aae2d3cca6798fa8abd456f00;

    /// @notice The address of the Royalty Module.
    IRoyaltyModule public immutable ROYALTY_MODULE;

    /// @notice The address of the License Token.
    ILicenseToken public immutable LICENSE_TOKEN;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address coreMetadataModule,
        address ipAssetRegistry,
        address licenseRegistry,
        address licenseToken,
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
            ipAssetRegistry == address(0) ||
            licenseRegistry == address(0) ||
            licenseToken == address(0) ||
            licensingModule == address(0) ||
            pilTemplate == address(0) ||
            royaltyModule == address(0)
        ) revert Errors.DerivativeWorkflows__ZeroAddressParam();

        LICENSE_TOKEN = ILicenseToken(licenseToken);
        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);

        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.DerivativeWorkflows__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @dev Sets the NFT contract beacon address.
    /// @param newNftContractBeacon The address of the new NFT contract beacon.
    function setNftContractBeacon(address newNftContractBeacon) external restricted {
        if (newNftContractBeacon == address(0)) revert Errors.DerivativeWorkflows__ZeroAddressParam();
        DerivativeWorkflowsStorage storage $ = _getDerivativeWorkflowsStorage();
        $.nftContractBeacon = newNftContractBeacon;
    }

    /// @notice Mint an NFT from a SPGNFT collection and register it as a derivative IP without license tokens.
    /// @dev Caller must have the minter role for the provided SPGNFT.
    /// @param spgNftContract The address of the SPGNFT collection.
    /// @param derivData The derivative data to be used for registerDerivative.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly minted NFT and registered IP.
    /// @param recipient The address to receive the minted NFT.
    /// @return ipId The ID of the newly registered IP.
    /// @return tokenId The ID of the newly minted NFT.
    function mintAndRegisterIpAndMakeDerivative(
        address spgNftContract,
        WorkflowStructs.MakeDerivative calldata derivData,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        address recipient
    ) external onlyCallerWithMinterRole(spgNftContract) returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(spgNftContract).mintByPeriphery({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);

        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        _collectMintFeesAndSetApproval(
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
        WorkflowStructs.MakeDerivative calldata derivData,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData calldata sigRegister
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

        _collectMintFeesAndSetApproval(
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
    /// @dev Caller must have the minter role for the provided SPGNFT. Caller must own the license tokens and have
    /// approved DerivativeWorkflows to transfer them.
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
        WorkflowStructs.IPMetadata calldata ipMetadata,
        address recipient
    ) external onlyCallerWithMinterRole(spgNftContract) returns (address ipId, uint256 tokenId) {
        _collectLicenseTokens(licenseTokenIds, address(LICENSE_TOKEN));

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
    /// @dev Caller must own the license tokens and have approved DerivativeWorkflows to transfer them.
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
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData calldata sigRegister
    ) external returns (address ipId) {
        _collectLicenseTokens(licenseTokenIds, address(LICENSE_TOKEN));

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

    /// @dev Collects license tokens from the caller. Assumes the periphery contract has permission
    /// to transfer the license tokens.
    /// @param licenseTokenIds The IDs of the license tokens to be collected.
    /// @param licenseToken The address of the license token contract.
    function _collectLicenseTokens(uint256[] calldata licenseTokenIds, address licenseToken) internal {
        if (licenseTokenIds.length == 0) revert Errors.DerivativeWorkflows__EmptyLicenseTokens();
        for (uint256 i = 0; i < licenseTokenIds.length; i++) {
            address tokenOwner = ILicenseToken(licenseToken).ownerOf(licenseTokenIds[i]);

            if (tokenOwner == address(this)) continue;
            if (tokenOwner != address(msg.sender))
                revert Errors.DerivativeWorkflows__CallerAndNotTokenOwner(licenseTokenIds[i], msg.sender, tokenOwner);

            ILicenseToken(licenseToken).safeTransferFrom(msg.sender, address(this), licenseTokenIds[i]);
        }
    }

    /// @dev Collect mint fees for all parent IPs from the payer and set approval for Royalty Module to spend mint fees.
    /// @param payerAddress The address of the payer for the license mint fees.
    /// @param childIpId The ID of the derivative IP.
    /// @param royaltyModule The address of the Royalty Module.
    /// @param licenseRegistry The address of the License Registry.
    /// @param licenseTemplate The address of the license template.
    /// @param parentIpIds The IDs of all the parent IPs.
    /// @param licenseTermsIds The IDs of the license terms for each corresponding parent IP.
    function _collectMintFeesAndSetApproval(
        address payerAddress,
        address childIpId,
        address royaltyModule,
        address licenseRegistry,
        address licenseTemplate,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds
    ) internal {
        // Get currency token and royalty policy, assumes all parent IPs have the same currency token.
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        (address royaltyPolicy, , , address mintFeeCurrencyToken) = lct.getRoyaltyPolicy(licenseTermsIds[0]);

        if (royaltyPolicy != address(0)) {
            // Get total mint fee for all parent IPs
            uint256 totalMintFee = _aggregateMintFees({
                childIpId: childIpId,
                licenseTemplate: licenseTemplate,
                licenseRegistry: licenseRegistry,
                parentIpIds: parentIpIds,
                licenseTermsIds: licenseTermsIds
            });

            if (totalMintFee != 0) {
                // Transfer mint fee from payer to this contract
                IERC20(mintFeeCurrencyToken).safeTransferFrom(payerAddress, address(this), totalMintFee);

                // Approve Royalty Policy to spend mint fee
                IERC20(mintFeeCurrencyToken).forceApprove(royaltyModule, totalMintFee);
            }
        }
    }

    /// @dev Aggregate license mint fees for all parent IPs.
    /// @param childIpId The ID of the derivative IP.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseRegistry The address of the License Registry.
    /// @param parentIpIds The IDs of all the parent IPs.
    /// @param licenseTermsIds The IDs of the license terms for each corresponding parent IP.
    /// @return totalMintFee The sum of license mint fees across all parent IPs.
    function _aggregateMintFees(
        address childIpId,
        address licenseTemplate,
        address licenseRegistry,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds
    ) internal returns (uint256 totalMintFee) {
        totalMintFee = 0;

        for (uint256 i = 0; i < parentIpIds.length; i++) {
            totalMintFee += _getMintFeeForSingleParent({
                childIpId: childIpId,
                parentIpId: parentIpIds[i],
                licenseTemplate: licenseTemplate,
                licenseRegistry: licenseRegistry,
                amount: 1,
                licenseTermsId: licenseTermsIds[i]
            });
        }
    }

    /// @dev Fetch the license token mint fee from the licensing hook or license terms for the given parent IP.
    /// @param childIpId The ID of the derivative IP.
    /// @param parentIpId The ID of the parent IP.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseRegistry The address of the License Registry.
    /// @param amount The amount of licenses to mint.
    /// @param licenseTermsId The ID of the license terms for the parent IP.
    /// @return The mint fee for the given parent IP.
    function _getMintFeeForSingleParent(
        address childIpId,
        address parentIpId,
        address licenseTemplate,
        address licenseRegistry,
        uint256 amount,
        uint256 licenseTermsId
    ) internal returns (uint256) {
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);

        // Get mint fee set by license terms
        (address royaltyPolicy, , uint256 mintFeeSetByLicenseTerms, ) = lct.getRoyaltyPolicy(licenseTermsId);

        // If no royalty policy, return 0
        if (royaltyPolicy == address(0)) return 0;

        uint256 mintFeeSetByHook = 0;

        Licensing.LicensingConfig memory licensingConfig = ILicenseRegistry(licenseRegistry).getLicensingConfig({
            ipId: parentIpId,
            licenseTemplate: licenseTemplate,
            licenseTermsId: licenseTermsId
        });

        // Get mint fee from licensing hook
        if (licensingConfig.licensingHook != address(0)) {
            mintFeeSetByHook = ILicensingHook(licensingConfig.licensingHook).beforeRegisterDerivative({
                caller: address(this),
                childIpId: childIpId,
                parentIpId: parentIpId,
                licenseTemplate: licenseTemplate,
                licenseTermsId: licenseTermsId,
                hookData: licensingConfig.hookData
            });
        }

        if (!licensingConfig.isSet) return mintFeeSetByLicenseTerms * amount;
        if (licensingConfig.licensingHook == address(0)) return licensingConfig.mintingFee * amount;

        return mintFeeSetByHook;
    }

    //
    // Upgrade
    //

    /// @dev Returns the storage struct of DerivativeWorkflows.
    function _getDerivativeWorkflowsStorage() private pure returns (DerivativeWorkflowsStorage storage $) {
        assembly {
            $.slot := DerivativeWorkflowsStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
