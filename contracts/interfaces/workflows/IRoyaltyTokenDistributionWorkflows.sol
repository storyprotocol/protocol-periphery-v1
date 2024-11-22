// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { WorkflowStructs } from "../../lib/WorkflowStructs.sol";

/// @title Royalty Token Distribution Workflows Interface
/// @notice Interface for IP royalty token distribution workflows.
interface IRoyaltyTokenDistributionWorkflows {
    /// @notice Mint an NFT and register the IP, attach PIL terms, and distribute royalty tokens.
    /// @dev In order to successfully distribute royalty tokens, the license terms attached to the IP must be
    /// a commercial license.
    /// @param spgNftContract The address of the SPG NFT contract.
    /// @param recipient The address to receive the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param terms The PIL terms to attach to the IP (must be a commercial license).
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    /// @return licenseTermsId The ID of the attached PIL terms.
    function mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        PILTerms calldata terms,
        WorkflowStructs.RoyaltyShare[] calldata royaltyShares
    ) external returns (address ipId, uint256 tokenId, uint256 licenseTermsId);

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
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Register an IP, attach PIL terms, and deploy a royalty vault.
    /// @dev In order to successfully deploy a royalty vault, the license terms attached to the IP must be
    /// a commercial license.
    /// @param nftContract The address of the NFT contract.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param terms The PIL terms to attach to the IP (must be a commercial license).
    /// @param sigMetadata The signature data for the IP metadata.
    /// @param sigAttach The signature data for attaching the PIL terms.
    /// @return ipId The ID of the registered IP.
    /// @return licenseTermsId The ID of the attached PIL terms.
    /// @return ipRoyaltyVault The address of the deployed royalty vault.
    function registerIpAndAttachPILTermsAndDeployRoyaltyVault(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        PILTerms calldata terms,
        WorkflowStructs.SignatureData calldata sigMetadata,
        WorkflowStructs.SignatureData calldata sigAttach
    ) external returns (address ipId, uint256 licenseTermsId, address ipRoyaltyVault);

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
    ) external returns (address ipId, address ipRoyaltyVault);

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
    ) external;
}
