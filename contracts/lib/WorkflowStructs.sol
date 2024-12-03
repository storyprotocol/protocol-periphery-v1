// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

/// @title Workflow Structs Library
/// @notice Library for all the structs used in periphery workflows.
library WorkflowStructs {
    /// @notice Struct for metadata for NFT minting and IP registration.
    /// @dev Leave the nftMetadataURI empty if not minting an NFT.
    /// @param ipMetadataURI The URI of the metadata for the IP.
    /// @param ipMetadataHash The hash of the metadata for the IP.
    /// @param nftMetadataURI The URI of the metadata for the NFT.
    /// @param nftMetadataHash The hash of the metadata for the IP NFT.
    struct IPMetadata {
        string ipMetadataURI;
        bytes32 ipMetadataHash;
        string nftMetadataURI;
        bytes32 nftMetadataHash;
    }

    /// @notice Struct for signature data for execution via IP Account.
    /// @param signer The address of the signer for execution with signature.
    /// @param deadline The deadline for the signature.
    /// @param signature The signature for the execution via IP Account.
    struct SignatureData {
        address signer;
        uint256 deadline;
        bytes signature;
    }

    /// @notice Struct for creating a derivative IP without license tokens.
    /// @param parentIpIds The IDs of the parent IPs to link the registered derivative IP.
    /// @param licenseTemplate The address of the license template to be used for the linking.
    /// @param licenseTermsIds The IDs of the license terms to be used for the linking.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    /// @param maxMintingFee The maximum minting fee that the caller is willing to pay. if set to 0 then no limit.
    /// @param maxRts The maximum number of royalty tokens that can be distributed to the external royalty policies.
    struct MakeDerivative {
        address[] parentIpIds;
        address licenseTemplate;
        uint256[] licenseTermsIds;
        bytes royaltyContext;
        uint256 maxMintingFee;
        uint32 maxRts;
    }

    /// @notice Struct for license data for license attachment on IP registration.
    /// @param licenseTemplate The address of the license template to be used for the licensing.
    /// @param licenseTermsId The ID of the license terms to be used for the licensing.
    /// @param licensingConfig The licensing configuration for the IP.
    struct LicenseData {
        address licenseTemplate;
        uint256 licenseTermsId;
        Licensing.LicensingConfig licensingConfig;
    }

    /// @notice Struct for PIL terms data for PIL registration and attachment on IP registration.
    /// @param terms The PIL terms to be used for the licensing.
    /// @param licenseTermsConfig The licensing configuration for the PIL terms.
    struct LicenseTermsData {
        PILTerms terms;
        Licensing.LicensingConfig licensingConfig;
    }

    /// @notice Struct for royalty shares information for royalty token distribution.
    /// @param recipient The address of the recipient of the royalty shares.
    /// @param percentage The percentage of the royalty share, 100_000_000 represents 100%.
    struct RoyaltyShare {
        address recipient;
        uint32 percentage;
    }
}
