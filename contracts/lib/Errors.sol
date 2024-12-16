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
    /// @notice Zero address provided as a param to the RoyaltyWorkflows.
    error RoyaltyWorkflows__ZeroAddressParam();

    ////////////////////////////////////////////////////////////////////////////
    //                   Royalty Token Distribution Workflows                 //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Zero address provided as a param to the RoyaltyTokenDistributionWorkflows.
    error RoyaltyTokenDistributionWorkflows__ZeroAddressParam();

    /// @notice Total percentage exceed the current balance of the IP account.
    error RoyaltyTokenDistributionWorkflows__TotalSharesExceedsIPAccountBalance(
        uint32 totalShares,
        uint32 ipAccountBalance
    );

    /// @notice Royalty vault not deployed.
    error RoyaltyTokenDistributionWorkflows__RoyaltyVaultNotDeployed();

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

    ////////////////////////////////////////////////////////////////////////////
    //                               OwnableERC20                             //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero ip id provided.
    error OwnableERC20__ZeroIpId();

    ////////////////////////////////////////////////////////////////////////////
    //                               TokenizerModule                         //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Zero license registry provided.
    error TokenizerModule__ZeroLicenseRegistry();

    /// @notice Zero dispute module provided.
    error TokenizerModule__ZeroDisputeModule();

    /// @notice Zero token template provided.
    error TokenizerModule__ZeroTokenTemplate();

    /// @notice Zero protocol access manager provided.
    error TokenizerModule__ZeroProtocolAccessManager();

    /// @notice Token template is not supported.
    /// @param tokenTemplate The address of the token template that is not supported
    error TokenizerModule__UnsupportedOwnableERC20(address tokenTemplate);

    /// @notice IP is disputed.
    /// @param ipId The address of the disputed IP
    error TokenizerModule__DisputedIpId(address ipId);

    /// @notice Token template is not whitelisted.
    /// @param tokenTemplate The address of the token template
    error TokenizerModule__TokenTemplateNotWhitelisted(address tokenTemplate);

    /// @notice IP is expired.
    /// @param ipId The address of the expired IP
    error TokenizerModule__IpExpired(address ipId);

    /// @notice IP is already tokenized.
    /// @param ipId The address of the already tokenized IP
    /// @param token The address of the fractionalized token for the IP
    error TokenizerModule__IpAlreadyTokenized(address ipId, address token);
}
