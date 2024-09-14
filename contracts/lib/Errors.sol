// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title Errors Library
/// @notice Library for all Story Protocol periphery contract errors.
library Errors {
    /// @notice Zero address provided as a param to SPG.
    error SPG__ZeroAddressParam();

    /// @notice Caller is not authorized to mint.
    error SPG__CallerNotAuthorizedToMint();

    /// @notice License token list is empty.
    error SPG__EmptyLicenseTokens();

    /// @notice License token is not owned by the either caller.
    error SPG__CallerAndNotTokenOwner(uint256 tokenId, address caller, address actualTokenOwner);

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

    /// @notice Zero address provided as a param to the GroupingWorkflows.
    error GroupingWorkflows__ZeroAddressParam();
}
