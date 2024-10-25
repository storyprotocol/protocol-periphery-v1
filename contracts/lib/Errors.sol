// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Errors Library
/// @notice Library for all Story Protocol periphery contract errors.
library Errors {
    /// @notice Caller is not authorized to mint.
    error Workflow__CallerNotAuthorizedToMint();

    ////////////////////////////////////////////////////////////////////////////
    //                           RegistrationWorkflows                        //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided as a param to the RegistrationWorkflows.
    error RegistrationWorkflows__ZeroAddressParam();

    ////////////////////////////////////////////////////////////////////////////
    //                         LicenseAttachmentWorkflows                     //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided as a param to the LicenseAttachmentWorkflows.
    error LicenseAttachmentWorkflows__ZeroAddressParam();

    ////////////////////////////////////////////////////////////////////////////
    //                         DerivativeWorkflows                            //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided as a param to the DerivativeWorkflows.
    error DerivativeWorkflows__ZeroAddressParam();

    /// @notice License token list is empty.
    error DerivativeWorkflows__EmptyLicenseTokens();

    /// @notice Caller is not the owner of the license token.
    error DerivativeWorkflows__CallerAndNotTokenOwner(uint256 tokenId, address caller, address actualTokenOwner);

    ////////////////////////////////////////////////////////////////////////////
    //                             Grouping Workflows                         //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided as a param to the GroupingWorkflows.
    error GroupingWorkflows__ZeroAddressParam();

    ////////////////////////////////////////////////////////////////////////////
    //                              Royalty Workflows                         //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Zero address provided as a param to the GroupingWorkflows.
    error RoyaltyWorkflows__ZeroAddressParam();

    ////////////////////////////////////////////////////////////////////////////
    //                               SPGNFT                                   //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided as a param.
    error SPGNFT__ZeroAddressParam();

    /// @notice Zero max supply provided.
    error SPGNFT__ZeroMaxSupply();

    /// @notice Max mint supply reached.
    error SPGNFT__MaxSupplyReached();

    /// @notice Minting is denied if the public minting is false (=> private) but caller does not have the minter role.
    error SPGNFT__MintingDenied();

    /// @notice Caller is not the fee recipient.
    error SPGNFT__CallerNotFeeRecipient();

    /// @notice Minting is closed.
    error SPGNFT__MintingClosed();

    /// @notice Caller is not one of the periphery contracts.
    error SPGNFT__CallerNotPeripheryContract();

    /// @notice Error thrown when attempting to mint an NFT with a metadata hash that already exists.
    /// @param spgNftContract The address of the SPGNFT collection contract where the duplicate was detected.
    /// @param tokenId The ID of the original NFT that was first minted with this metadata hash.
    /// @param nftMetadataHash The hash of the NFT metadata that caused the duplication error.
    error SPGNFT__DuplicatedNFTMetadataHash(address spgNftContract, uint256 tokenId, bytes32 nftMetadataHash);
}
