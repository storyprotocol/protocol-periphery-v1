// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { WorkflowStructs } from "../../lib/WorkflowStructs.sol";

/// @title Royalty Token Distribution Workflows Interface
/// @notice Interface for IP royalty token distribution workflows.
interface IRoyaltyTokenDistributionWorkflows {
    /// @notice Mint an NFT and register the IP, attach PIL terms, and distribute royalty tokens.
    /// @param spgNftContract The address of the SPG NFT contract.
    /// @param recipient The address to receive the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param licenseTermsData The PIL terms and licensing configuration data to attach to the IP.
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @param allowDuplicates Set to true to allow minting an NFT with a duplicate metadata hash.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    /// @return licenseTermsId The ID of the attached PIL terms.
    function mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens(
        address spgNftContract,
        address recipient,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.LicenseTermsData calldata licenseTermsData,
        WorkflowStructs.RoyaltyShare[] calldata royaltyShares,
        bool allowDuplicates
    ) external returns (address ipId, uint256 tokenId, uint256 licenseTermsId);

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
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Register an IP, attach PIL terms, and deploy a royalty vault.
    /// @param nftContract The address of the NFT contract.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata The metadata for the IP.
    /// @param licenseTermsData The PIL terms and licensing configuration data to attach to the IP.
    /// @param sigMetadataAndAttachAndConfig Signature data for setAll (metadata), attachLicenseTerms, and
    /// setLicensingConfig to the IP via the Core Metadata Module and Licensing Module.
    /// @return ipId The ID of the registered IP.
    /// @return licenseTermsId The ID of the attached PIL terms.
    /// @return ipRoyaltyVault The address of the deployed royalty vault.
    function registerIpAndAttachPILTermsAndDeployRoyaltyVault(
        address nftContract,
        uint256 tokenId,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        WorkflowStructs.LicenseTermsData calldata licenseTermsData,
        WorkflowStructs.SignatureData calldata sigMetadataAndAttachAndConfig
    ) external returns (address ipId, uint256 licenseTermsId, address ipRoyaltyVault);

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
    ) external returns (address ipId, address ipRoyaltyVault);

    /// @notice Distribute royalty tokens to the authors of the IP.
    /// @param ipId The ID of the IP.
    /// @param royaltyShares Authors of the IP and their shares of the royalty tokens, see {WorkflowStructs.RoyaltyShare}.
    /// @param sigApproveRoyaltyTokens The signature data for approving the royalty tokens.
    function distributeRoyaltyTokens(
        address ipId,
        WorkflowStructs.RoyaltyShare[] calldata royaltyShares,
        WorkflowStructs.SignatureData calldata sigApproveRoyaltyTokens
    ) external;
}
