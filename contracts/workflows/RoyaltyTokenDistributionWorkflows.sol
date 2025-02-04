// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { BaseWorkflow } from "../BaseWorkflow.sol";
import { Errors } from "../lib/Errors.sol";
import { IRoyaltyTokenDistributionWorkflows } from "../interfaces/workflows/IRoyaltyTokenDistributionWorkflows.sol";
import { ISPGNFT } from "../interfaces/ISPGNFT.sol";
import { LicensingHelper } from "../lib/LicensingHelper.sol";
import { MetadataHelper } from "../lib/MetadataHelper.sol";
import { PermissionHelper } from "../lib/PermissionHelper.sol";
import { WorkflowStructs } from "../lib/WorkflowStructs.sol";

/// @title Royalty Token Distribution Workflows
/// @notice Each workflow bundles multiple core protocol operations into a single function to enable
/// royalty token distribution upon IP registration in the Story Proof-of-Creativity Protocol.
contract RoyaltyTokenDistributionWorkflows is
    IRoyaltyTokenDistributionWorkflows,
    BaseWorkflow,
    MulticallUpgradeable,
    AccessManagedUpgradeable,
    UUPSUpgradeable,
    ERC721Holder
{
    using ERC165Checker for address;
    using SafeERC20 for IERC20;

    /// @notice The address of the Royalty Module.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyModule public immutable ROYALTY_MODULE;

    /// @notice The address of the Liquid Absolute Percentage (LAP) Royalty Policy.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable ROYALTY_POLICY_LAP;

    /// @notice The address of the Wrapped IP (WIP) token contract.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable WIP;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address coreMetadataModule,
        address ipAssetRegistry,
        address licenseRegistry,
        address licensingModule,
        address pilTemplate,
        address royaltyModule,
        address royaltyPolicyLAP,
        address wip
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
            pilTemplate == address(0) ||
            royaltyModule == address(0) ||
            royaltyPolicyLAP == address(0) ||
            wip == address(0)
        ) revert Errors.RoyaltyTokenDistributionWorkflows__ZeroAddressParam();

        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        ROYALTY_POLICY_LAP = royaltyPolicyLAP;
        WIP = wip;

        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.RoyaltyTokenDistributionWorkflows__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
        __Multicall_init();
    }

    /// @notice Mint an NFT and register the IP, attach PIL terms, and distribute royalty tokens.
    /// @param spgNftContract The address of the SPG NFT contract.
    /// @param recipient The address to receive the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param licenseTermsData The PIL terms and licensing configuration data to attach to the IP.
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    /// @return licenseTermsIds The IDs of the attached PIL terms.
    function mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.LicenseTermsData[] calldata licenseTermsData,
        WorkflowStructs.RoyaltyShare[] calldata royaltyShares,
        bool allowDuplicates
    )
        external
        onlyMintAuthorized(spgNftContract)
        returns (address ipId, uint256 tokenId, uint256[] memory licenseTermsIds)
    {
        if (licenseTermsData.length == 0) revert Errors.RoyaltyTokenDistributionWorkflows__NoLicenseTermsData();

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

        _deployRoyaltyVault(ipId);
        _distributeRoyaltyTokens({
            ipId: ipId,
            royaltyShares: royaltyShares,
            sigApproveRoyaltyTokens: WorkflowStructs.SignatureData(address(0), 0, "") // no signature required.
        });

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Mint an NFT and register the IP, make a derivative, and distribute royalty tokens.
    /// @param spgNftContract The address of the SPG NFT contract.
    /// @param recipient The address to receive the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param derivData The data for the derivative, see {WorkflowStructs.MakeDerivative}.
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function mintAndRegisterIpAndMakeDerivativeAndDistributeRoyaltyTokens(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.MakeDerivative calldata derivData,
        WorkflowStructs.RoyaltyShare[] calldata royaltyShares,
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

        LicensingHelper.collectMintFeesAndMakeDerivative({
            childIpId: ipId,
            royaltyModule: address(ROYALTY_MODULE),
            licensingModule: address(LICENSING_MODULE),
            derivData: derivData
        });

        _deployRoyaltyVault(ipId);
        _distributeRoyaltyTokens({
            ipId: ipId,
            royaltyShares: royaltyShares,
            sigApproveRoyaltyTokens: WorkflowStructs.SignatureData(address(0), 0, "") // no signature required.
        });

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register an IP, attach PIL terms, and deploy a royalty vault.
    /// @param nftContract The address of the NFT contract.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param licenseTermsData The PIL terms and licensing configuration data to attach to the IP.
    /// @param sigMetadataAndAttachAndConfig Signature data for setAll (metadata), attachLicenseTerms, and
    /// setLicensingConfig to the IP via the Core Metadata Module and Licensing Module.
    /// @return ipId The ID of the registered IP.
    /// @return licenseTermsIds The IDs of the attached PIL terms.
    /// @return ipRoyaltyVault The address of the deployed royalty vault.
    function registerIpAndAttachPILTermsAndDeployRoyaltyVault(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.LicenseTermsData[] calldata licenseTermsData,
        WorkflowStructs.SignatureData calldata sigMetadataAndAttachAndConfig
    ) external returns (address ipId, uint256[] memory licenseTermsIds, address ipRoyaltyVault) {
        if (licenseTermsData.length == 0) revert Errors.RoyaltyTokenDistributionWorkflows__NoLicenseTermsData();
        if (msg.sender != sigMetadataAndAttachAndConfig.signer)
            revert Errors.RoyaltyTokenDistributionWorkflows__CallerNotSigner(
                msg.sender,
                sigMetadataAndAttachAndConfig.signer
            );

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

        ipRoyaltyVault = _deployRoyaltyVault(ipId);
    }

    /// @notice Register an IP, make a derivative, and deploy a royalty vault.
    /// @param nftContract The address of the NFT contract.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param derivData The data for the derivative, see {WorkflowStructs.MakeDerivative}.
    /// @param sigMetadataAndRegister Signature data for setAll (metadata) and registerDerivative to the IP via
    /// the Core Metadata Module and Licensing Module.
    /// @return ipId The ID of the registered IP.
    /// @return ipRoyaltyVault The address of the deployed royalty vault.
    function registerIpAndMakeDerivativeAndDeployRoyaltyVault(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.MakeDerivative calldata derivData,
        WorkflowStructs.SignatureData calldata sigMetadataAndRegister
    ) external returns (address ipId, address ipRoyaltyVault) {
        if (msg.sender != sigMetadataAndRegister.signer)
            revert Errors.RoyaltyTokenDistributionWorkflows__CallerNotSigner(msg.sender, sigMetadataAndRegister.signer);

        ipId = IP_ASSET_REGISTRY.register(block.chainid, nftContract, tokenId);

        address[] memory modules = new address[](2);
        bytes4[] memory selectors = new bytes4[](2);
        modules[0] = address(CORE_METADATA_MODULE);
        modules[1] = address(LICENSING_MODULE);
        selectors[0] = ICoreMetadataModule.setAll.selector;
        selectors[1] = ILicensingModule.registerDerivative.selector;
        PermissionHelper.setBatchPermissionForModules({
            ipId: ipId,
            accessController: address(ACCESS_CONTROLLER),
            modules: modules,
            selectors: selectors,
            sigData: sigMetadataAndRegister
        });

        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        LicensingHelper.collectMintFeesAndMakeDerivative({
            childIpId: ipId,
            royaltyModule: address(ROYALTY_MODULE),
            licensingModule: address(LICENSING_MODULE),
            derivData: derivData
        });

        ipRoyaltyVault = _deployRoyaltyVault(ipId);
    }

    /// @notice Distribute royalty tokens to the authors of the IP.
    /// @param ipId The ID of the IP.
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @param sigApproveRoyaltyTokens The signature data for approving the royalty tokens.
    function distributeRoyaltyTokens(
        address ipId,
        WorkflowStructs.RoyaltyShare[] calldata royaltyShares,
        WorkflowStructs.SignatureData calldata sigApproveRoyaltyTokens
    ) external {
        if (msg.sender != sigApproveRoyaltyTokens.signer)
            revert Errors.RoyaltyTokenDistributionWorkflows__CallerNotSigner(
                msg.sender,
                sigApproveRoyaltyTokens.signer
            );

        _distributeRoyaltyTokens(ipId, royaltyShares, sigApproveRoyaltyTokens);
    }

    /// @dev Deploys a royalty vault for the IP.
    /// @param ipId The ID of the IP.
    /// @return ipRoyaltyVault The address of the deployed royalty vault.
    function _deployRoyaltyVault(address ipId) internal returns (address ipRoyaltyVault) {
        if (ROYALTY_MODULE.ipRoyaltyVaults(ipId) == address(0)) {
            // attach a temporary commercial license to the IP for the royalty vault deployment
            uint256 licenseTermsId = LicensingHelper.registerPILTermsAndAttach({
                ipId: ipId,
                pilTemplate: address(PIL_TEMPLATE),
                licensingModule: address(LICENSING_MODULE),
                terms: PILFlavors.commercialUse({
                    mintingFee: 0,
                    currencyToken: WIP,
                    royaltyPolicy: ROYALTY_POLICY_LAP
                })
            });

            uint256[] memory licenseTermsIds = new uint256[](1);
            licenseTermsIds[0] = licenseTermsId;

            // mint a license token to trigger the royalty vault deployment
            LICENSING_MODULE.mintLicenseTokens({
                licensorIpId: ipId,
                licenseTemplate: address(PIL_TEMPLATE),
                licenseTermsId: licenseTermsId,
                amount: 1,
                receiver: msg.sender,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRevenueShare: 0
            });

            // set the licensing configuration to disable the temporary license
            LICENSING_MODULE.setLicensingConfig({
                ipId: ipId,
                licenseTemplate: address(PIL_TEMPLATE),
                licenseTermsId: licenseTermsId,
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: 0,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 0,
                    disabled: true,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(0)
                })
            });
        }

        ipRoyaltyVault = ROYALTY_MODULE.ipRoyaltyVaults(ipId);
        if (ipRoyaltyVault == address(0)) revert Errors.RoyaltyTokenDistributionWorkflows__RoyaltyVaultNotDeployed();
    }

    /// @dev Distributes royalty tokens to the authors of the IP.
    /// @param ipId The ID of the IP.
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @param sigApproveRoyaltyTokens The signature data for approving the royalty tokens.
    function _distributeRoyaltyTokens(
        address ipId,
        WorkflowStructs.RoyaltyShare[] memory royaltyShares,
        WorkflowStructs.SignatureData memory sigApproveRoyaltyTokens
    ) internal {
        address ipRoyaltyVault = ROYALTY_MODULE.ipRoyaltyVaults(ipId);
        if (ipRoyaltyVault == address(0)) revert Errors.RoyaltyTokenDistributionWorkflows__RoyaltyVaultNotDeployed();

        uint32 totalPercentages = _validateRoyaltyShares(ipId, ipRoyaltyVault, royaltyShares);

        if (sigApproveRoyaltyTokens.signature.length > 0) {
            IIPAccount(payable(ipId)).executeWithSig({
                to: ipRoyaltyVault,
                value: 0,
                data: abi.encodeWithSelector(IERC20.approve.selector, address(this), uint256(totalPercentages)),
                signer: sigApproveRoyaltyTokens.signer,
                deadline: sigApproveRoyaltyTokens.deadline,
                signature: sigApproveRoyaltyTokens.signature
            });
        } else {
            IIPAccount(payable(ipId)).execute({
                to: ipRoyaltyVault,
                value: 0,
                data: abi.encodeWithSelector(IERC20.approve.selector, address(this), uint256(totalPercentages))
            });
        }

        // distribute the royalty tokens
        for (uint256 i; i < royaltyShares.length; i++) {
            IERC20(ipRoyaltyVault).safeTransferFrom({
                from: ipId,
                to: royaltyShares[i].recipient,
                value: royaltyShares[i].percentage
            });
        }
    }

    /// @dev Validates the royalty shares.
    /// @param ipId The ID of the IP.
    /// @param ipRoyaltyVault The address of the royalty vault.
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @return totalPercentages The total percentages of the royalty shares.
    function _validateRoyaltyShares(
        address ipId,
        address ipRoyaltyVault,
        WorkflowStructs.RoyaltyShare[] memory royaltyShares
    ) internal returns (uint32 totalPercentages) {
        for (uint256 i; i < royaltyShares.length; i++) {
            totalPercentages += royaltyShares[i].percentage;
        }

        uint32 ipRoyaltyVaultBalance = uint32(IERC20(ipRoyaltyVault).balanceOf(ipId));
        if (totalPercentages > ipRoyaltyVaultBalance)
            revert Errors.RoyaltyTokenDistributionWorkflows__TotalSharesExceedsIPAccountBalance(
                totalPercentages,
                ipRoyaltyVaultBalance
            );

        return totalPercentages;
    }

    //
    // Upgrade
    //

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    ////////////////////////////////////////////////////////////////////////////
    //                   DEPRECATED, WILL BE REMOVED IN V1.4                  //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Mint an NFT and register the IP, attach PIL terms, and distribute royalty tokens.
    /// @dev THIS VERSION OF THE FUNCTION IS DEPRECATED, WILL BE REMOVED IN V1.4
    function mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens_deprecated(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        PILTerms[] calldata terms,
        WorkflowStructs.RoyaltyShare[] calldata royaltyShares
    )
        external
        onlyMintAuthorized(spgNftContract)
        returns (address ipId, uint256 tokenId, uint256[] memory licenseTermsIds)
    {
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

        _deployRoyaltyVaultDEPR(ipId, address(PIL_TEMPLATE), licenseTermsIds[0]);
        _distributeRoyaltyTokens(
            ipId,
            royaltyShares,
            WorkflowStructs.SignatureData(address(0), 0, "") // no signature required.
        );

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register an IP, attach PIL terms, and deploy a royalty vault.
    /// @dev THIS VERSION OF THE FUNCTION IS DEPRECATED, WILL BE REMOVED IN V1.4
    function registerIpAndAttachPILTermsAndDeployRoyaltyVault_deprecated(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        PILTerms[] calldata terms,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData calldata sigAttach
    ) external returns (address ipId, uint256[] memory licenseTermsIds, address ipRoyaltyVault) {
        if (msg.sender != sigMetadata.signer)
            revert Errors.RoyaltyTokenDistributionWorkflows__CallerNotSigner(msg.sender, sigMetadata.signer);
        if (msg.sender != sigAttach.signer)
            revert Errors.RoyaltyTokenDistributionWorkflows__CallerNotSigner(msg.sender, sigAttach.signer);

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

        ipRoyaltyVault = _deployRoyaltyVaultDEPR(ipId, address(PIL_TEMPLATE), licenseTermsIds[0]);
    }

    /// @dev Deploys a royalty vault for the IP.
    /// @dev THIS FUNCTION IS DEPRECATED, WILL BE REMOVED IN V1.4
    function _deployRoyaltyVaultDEPR(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal returns (address ipRoyaltyVault) {
        // if no royalty vault, mint a license token to trigger the vault deployment
        if (ROYALTY_MODULE.ipRoyaltyVaults(ipId) == address(0)) {
            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ipId;
            licenseTermsIds[0] = licenseTermsId;

            LicensingHelper.collectMintFeesAndSetApproval({
                payerAddress: msg.sender,
                royaltyModule: address(ROYALTY_MODULE),
                licensingModule: address(LICENSING_MODULE),
                licenseTemplate: licenseTemplate,
                parentIpIds: parentIpIds,
                licenseTermsIds: licenseTermsIds
            });

            LICENSING_MODULE.mintLicenseTokens({
                licensorIpId: ipId,
                licenseTemplate: licenseTemplate,
                licenseTermsId: licenseTermsId,
                amount: 1,
                receiver: msg.sender,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRevenueShare: 0
            });
        }

        ipRoyaltyVault = ROYALTY_MODULE.ipRoyaltyVaults(ipId);
        if (ipRoyaltyVault == address(0)) revert Errors.RoyaltyTokenDistributionWorkflows__RoyaltyVaultNotDeployed();
    }

    /// @notice THIS FUNCTION IS DEPRECATED, WILL BE REMOVED IN V1.4
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
