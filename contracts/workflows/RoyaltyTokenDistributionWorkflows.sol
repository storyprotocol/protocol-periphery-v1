// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
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
    UUPSUpgradeable
{
    using ERC165Checker for address;
    using SafeERC20 for IERC20;

    /// @dev Storage structure for the RoyaltyTokenDistributionWorkflows
    /// @param nftContractBeacon The address of the NFT contract beacon.
    /// @custom:storage-location erc7201:story-protocol-periphery.RoyaltyTokenDistributionWorkflows
    struct RoyaltyTokenDistributionWorkflowsStorage {
        address nftContractBeacon;
    }

    // solhint-disable-next-line max-line-length
    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.RoyaltyTokenDistributionWorkflows")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RoyaltyTokenDistributionWorkflowsStorageLocation =
        0x49f5a60a01a4171ac277a9cd523bb469bbf7cf89b7349fb34e8335e241d25600;

    /// @notice The address of the Royalty Module.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyModule public immutable ROYALTY_MODULE;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address coreMetadataModule,
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
            ipAssetRegistry == address(0) ||
            licenseRegistry == address(0) ||
            licensingModule == address(0) ||
            pilTemplate == address(0) ||
            royaltyModule == address(0)
        ) revert Errors.RoyaltyTokenDistributionWorkflows__ZeroAddressParam();

        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.RoyaltyTokenDistributionWorkflows__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @dev Sets the NFT contract beacon address.
    /// @param newNftContractBeacon The address of the new NFT contract beacon.
    function setNftContractBeacon(address newNftContractBeacon) external restricted {
        if (newNftContractBeacon == address(0)) revert Errors.RoyaltyTokenDistributionWorkflows__ZeroAddressParam();
        RoyaltyTokenDistributionWorkflowsStorage storage $ = _getRoyaltyTokenDistributionWorkflowsStorage();
        $.nftContractBeacon = newNftContractBeacon;
    }

    /// @notice Mint an NFT and register the IP, attach PIL terms, and distribute royalty tokens.
    /// @dev In order to successfully distribute royalty tokens, the license terms attached to the IP must be
    /// a commercial license.
    /// @param spgNftContract The address of the SPG NFT contract.
    /// @param recipient The address to receive the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param terms The PIL terms to attach to the IP (the license terms at index 0must be a commercial license).
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    /// @return licenseTermsIds The IDs of the attached PIL terms.
    function mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens(
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
            nftMetadataURI: ipMetadata.nftMetadataURI
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);
        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        licenseTermsIds = LicensingHelper.registerPILTermsAndAttach(
            ipId,
            address(PIL_TEMPLATE),
            address(LICENSING_MODULE),
            address(LICENSE_REGISTRY),
            terms
        );

        _distributeRoyaltyTokens(
            ipId,
            _deployRoyaltyVault(ipId, address(PIL_TEMPLATE), licenseTermsIds[0]),
            royaltyShares,
            WorkflowStructs.SignatureData(address(0), 0, "") // no signature required.
        );

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Mint an NFT and register the IP, make a derivative, and distribute royalty tokens.
    /// @dev In order to successfully distribute royalty tokens, the license terms attached to the IP must be
    /// a commercial license.
    /// @param spgNftContract The address of the SPG NFT contract.
    /// @param recipient The address to receive the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param derivData The data for the derivative, see {WorkflowStructs.MakeDerivative}.
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function mintAndRegisterIpAndMakeDerivativeAndDistributeRoyaltyTokens(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.MakeDerivative calldata derivData,
        WorkflowStructs.RoyaltyShare[] calldata royaltyShares
    ) external onlyMintAuthorized(spgNftContract) returns (address ipId, uint256 tokenId) {
        tokenId = ISPGNFT(spgNftContract).mintByPeriphery({
            to: address(this),
            payer: msg.sender,
            nftMetadataURI: ipMetadata.nftMetadataURI
        });
        ipId = IP_ASSET_REGISTRY.register(block.chainid, spgNftContract, tokenId);

        MetadataHelper.setMetadata(ipId, address(CORE_METADATA_MODULE), ipMetadata);

        LicensingHelper.collectMintFeesAndSetApproval(
            msg.sender,
            address(ROYALTY_MODULE),
            address(LICENSING_MODULE),
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

        _distributeRoyaltyTokens(
            ipId,
            _deployRoyaltyVault(ipId, derivData.licenseTemplate, derivData.licenseTermsIds[0]),
            royaltyShares,
            WorkflowStructs.SignatureData(address(0), 0, "") // no signature required.
        );

        ISPGNFT(spgNftContract).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @notice Register an IP, attach PIL terms, and deploy a royalty vault.
    /// @dev In order to successfully deploy a royalty vault, the license terms attached to the IP must be
    /// a commercial license.
    /// @param nftContract The address of the NFT contract.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param terms The PIL terms to attach to the IP (the license terms at index 0 must be a commercial license).
    /// @param sigMetadata The signature data for the IP metadata.
    /// @param sigAttach The signature data for attaching the PIL terms.
    /// @return ipId The ID of the registered IP.
    /// @return licenseTermsIds The IDs of the attached PIL terms.
    /// @return ipRoyaltyVault The address of the deployed royalty vault.
    function registerIpAndAttachPILTermsAndDeployRoyaltyVault(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        PILTerms[] calldata terms,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData calldata sigAttach
    ) external returns (address ipId, uint256[] memory licenseTermsIds, address ipRoyaltyVault) {
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

        licenseTermsIds = LicensingHelper.registerPILTermsAndAttach(
            ipId,
            address(PIL_TEMPLATE),
            address(LICENSING_MODULE),
            address(LICENSE_REGISTRY),
            terms
        );

        ipRoyaltyVault = _deployRoyaltyVault(ipId, address(PIL_TEMPLATE), licenseTermsIds[0]);
    }

    /// @notice Register an IP, make a derivative, and deploy a royalty vault.
    /// @dev In order to successfully deploy a royalty vault, the license terms attached to the IP must be
    /// a commercial license.
    /// @param nftContract The address of the NFT contract.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param derivData The data for the derivative, see {WorkflowStructs.MakeDerivative}.
    /// @param sigMetadata The signature data for the IP metadata.
    /// @param sigRegister The signature data for registering the derivative.
    /// @return ipId The ID of the registered IP.
    /// @return ipRoyaltyVault The address of the deployed royalty vault.
    function registerIpAndMakeDerivativeAndDeployRoyaltyVault(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.MakeDerivative calldata derivData,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData calldata sigRegister
    ) external returns (address ipId, address ipRoyaltyVault) {
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
            address(ROYALTY_MODULE),
            address(LICENSING_MODULE),
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

        ipRoyaltyVault = _deployRoyaltyVault(ipId, derivData.licenseTemplate, derivData.licenseTermsIds[0]);
    }

    /// @notice Distribute royalty tokens to the authors of the IP.
    /// @param ipId The ID of the IP.
    /// @param ipRoyaltyVault The address of the royalty vault.
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @param sigApproveRoyaltyTokens The signature data for approving the royalty tokens.
    function distributeRoyaltyTokens(
        address ipId,
        address ipRoyaltyVault,
        WorkflowStructs.RoyaltyShare[] calldata royaltyShares,
        WorkflowStructs.SignatureData calldata sigApproveRoyaltyTokens
    ) external {
        _distributeRoyaltyTokens(ipId, ipRoyaltyVault, royaltyShares, sigApproveRoyaltyTokens);
    }

    /// @dev Distributes royalty tokens to the authors of the IP.
    /// @param ipId The ID of the IP.
    /// @param ipRoyaltyVault The address of the royalty vault.
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @param sigApproveRoyaltyTokens The signature data for approving the royalty tokens.
    function _distributeRoyaltyTokens(
        address ipId,
        address ipRoyaltyVault,
        WorkflowStructs.RoyaltyShare[] memory royaltyShares,
        WorkflowStructs.SignatureData memory sigApproveRoyaltyTokens
    ) internal {
        if (ipRoyaltyVault == address(0)) revert Errors.RoyaltyTokenDistributionWorkflows__RoyaltyVaultNotDeployed();

        uint32 totalPercentages = _validateRoyaltyShares(royaltyShares);

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
            IERC20(ipRoyaltyVault).transferFrom({
                from: ipId,
                to: royaltyShares[i].author,
                value: royaltyShares[i].percentage
            });
        }
    }

    /// @dev Validates the royalty shares.
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @return totalPercentages The total percentages of the royalty shares.
    function _validateRoyaltyShares(
        WorkflowStructs.RoyaltyShare[] memory royaltyShares
    ) internal returns (uint32 totalPercentages) {
        for (uint256 i; i < royaltyShares.length; i++) {
            totalPercentages += royaltyShares[i].percentage;
            if (totalPercentages > 100_000_000)
                revert Errors.RoyaltyTokenDistributionWorkflows__TotalPercentagesExceeds100Percent();
        }

        return totalPercentages;
    }

    /// @dev Deploys a royalty vault for the IP.
    /// @param ipId The ID of the IP.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    /// @return ipRoyaltyVault The address of the deployed royalty vault.
    function _deployRoyaltyVault(
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
                royaltyContext: ""
            });
        }

        ipRoyaltyVault = ROYALTY_MODULE.ipRoyaltyVaults(ipId);
        if (ipRoyaltyVault == address(0)) revert Errors.RoyaltyTokenDistributionWorkflows__RoyaltyVaultNotDeployed();
    }

    //
    // Upgrade
    //

    /// @dev Returns the storage struct of RoyaltyTokenDistributionWorkflows.
    function _getRoyaltyTokenDistributionWorkflowsStorage()
        private
        pure
        returns (RoyaltyTokenDistributionWorkflowsStorage storage $)
    {
        assembly {
            $.slot := RoyaltyTokenDistributionWorkflowsStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
