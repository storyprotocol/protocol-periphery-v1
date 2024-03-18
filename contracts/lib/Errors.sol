// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @title Errors Library
/// @notice Library for all Story Protocol periphery contract errors.
library Errors {
    ////////////////////////////////////////////////////////////////////////////
    //                                ERC-721                                 //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The maximum supply for the collection has been reached.
    error ERC721__MaxSupplyReached();

    /// @notice The owner is not valid.
    error ERC721__OwnerInvalid();

    /// @notice The receiver of the ERC721 is not valid.
    error ERC721__ReceiverInvalid();

    /// @notice The sender of the ERC721 is not authorized.
    error ERC721__SenderUnauthorized();

    /// @notice The safe transfer functionality is not supported.
    error ERC721__SafeTransferUnsupported();

    /// @notice The NFT has already been minted.
    error ERC721__TokenAlreadyMinted();

    /// @notice The provided token does not exist.
    error ERC721__TokenNonExistent();

    ////////////////////////////////////////////////////////////////////////////
    //                          ERC-721 Metadata Provider                    ///
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The provided token description is not valid.
    error ERC721MetadataProvider__DescriptionInvalid();

    /// @notice The provided token image is not valid.
    error ERC721MetadataProvider__ImageInvalid();

    /// @notice The metadata provided is not valid.
    error ERC721MetadataProvider__MetadataInvalid();

    /// @notice The provided token name is not valid.
    error ERC721MetadataProvider__NameInvalid();

    /// @notice The caller is not the token bound to the metadata provider.
    error ERC721MetadataProvider__TokenInvalid();

    /// @notice The provided token URL is not valid.
    error ERC721MetadataProvider__URLInvalid();

    ////////////////////////////////////////////////////////////////////////////
    //                            ERC-721 SP NFT                              //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The caller must be the SP NFT factory.
    error ERC721SPNFT__FactoryInvalid();

    /// @notice The caller is not an approved owner of the collection.
    error ERC721SPNFT__OwnerInvalid();

    /// @notice The caller is not an approved minter for the contract.
    error ERC721SPNFT__MinterInvalid();

    ////////////////////////////////////////////////////////////////////////////
    //                         Story Protocol Gateway                         //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Minting has already completed for the targeted collection.
    error SPG__MintingAlreadyEnded();

    /// @notice The selected IP collection has yet to be initialized.
    error SPG__CollectionNotInitialized();

    /// @notice The input IP NFT collection type is not supported.
    error SPG__CollectionTypeUnsupported();

    /// @notice The owner is not allowed to perform this registration.
    error SPG__InvalidOwner();

    /// @notice Minting has yet to start for the targeted SPG.
    error SPG__MintingNotYetStarted();

    ////////////////////////////////////////////////////////////////////////////
    //                                 IPResolver                            ///
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The targeted IP does not yet have an IP account.
    error IPResolver_InvalidIP();

    /// @notice Caller not authorized to perform the IP resolver function call.
    error IPResolver_Unauthorized();

    ////////////////////////////////////////////////////////////////////////////
    //                          Metadata Provider                            ///
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Provided hash metadata is not valid.
    error MetadataProvider__HashInvalid();

    /// @notice The caller is not the authorized IP asset owner.
    error MetadataProvider__IPAssetOwnerInvalid();

    /// @notice Provided hash metadata is not valid.
    error MetadataProvider__NameInvalid();

    /// @notice The new metadata provider is not compatible with the old provider.
    error MetadataProvider__MetadataNotCompatible();

    /// @notice Provided registrant metadata is not valid.
    error MetadataProvider__RegistrantInvalid();

    /// @notice Provided registration date is not valid.
    error MetadataProvider__RegistrationDateInvalid();

    /// @notice Caller does not access to set metadata storage for the provider.
    error MetadataProvider__Unauthorized();

    /// @notice A metadata provider upgrade is not currently available.
    error MetadataProvider__UpgradeUnavailable();

    /// @notice The upgrade provider is not valid.
    error MetadataProvider__UpgradeProviderInvalid();

    /// @notice Provided metadata URI is not valid.
    error MetadataProvider__URIInvalid();

    ////////////////////////////////////////////////////////////////////////////
    //                       Dispute Arbitration Policy                      ///
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The dispute module address is zero address.
    error ArbitrationPolicySP__ZeroDisputeModule();

    /// @notice The payment token address is zero address.
    error ArbitrationPolicySP__ZeroPaymentToken();

    /// @notice The caller is not the dispute module.
    error ArbitrationPolicySP__NotDisputeModule();

    ////////////////////////////////////////////////////////////////////////////
    //                           Royalty Policy LAP                          ///
    ////////////////////////////////////////////////////////////////////////////

    error RoyaltyPolicyLAP__ZeroRoyaltyModule();
    error RoyaltyPolicyLAP__ZeroLiquidSplitFactory();
    error RoyaltyPolicyLAP__ZeroLiquidSplitMain();
    error RoyaltyPolicyLAP__NotRoyaltyModule();
    error RoyaltyPolicyLAP__ZeroLicensingModule();
    error RoyaltyPolicyLAP__AboveParentLimit();
    error RoyaltyPolicyLAP__AboveAncestorsLimit();
    error RoyaltyPolicyLAP__AboveRoyaltyStackLimit();
    error RoyaltyPolicyLAP__InvalidParentRoyaltiesLength();
    error RoyaltyPolicyLAP__ImplementationAlreadySet();
    error RoyaltyPolicyLAP__ZeroAncestorsVaultImpl();
    error RoyaltyPolicyLAP__NotFullOwnership();
    error RoyaltyPolicyLAP__UnlinkableToParents();
    error RoyaltyPolicyLAP__LastPositionNotAbleToMintLicense();

    error AncestorsVaultLAP__ZeroRoyaltyPolicyLAP();
    error AncestorsVaultLAP__AlreadyClaimed();
    error AncestorsVaultLAP__InvalidVault();
    error AncestorsVaultLAP__ClaimerNotAnAncestor();
    error AncestorsVaultLAP__ERC20BalanceNotZero();

    ////////////////////////////////////////////////////////////////////////////
    //                         PolicyFrameworkManager                         //
    ////////////////////////////////////////////////////////////////////////////

    error PolicyFrameworkManager__GettingPolicyWrongFramework();
    error PolicyFrameworkManager__CommercializerCheckerDoesNotSupportHook(address commercializer);

    ////////////////////////////////////////////////////////////////////////////
    //                     LicensorApprovalChecker                            //
    ////////////////////////////////////////////////////////////////////////////
    error LicensorApprovalChecker__Unauthorized();
}
