// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

/// @title Errors Library
/// @notice Library for all Story Protocol periphery contract errors.
library Errors {
    /// @notice Zero address provided as a param.
    error SPG__ZeroAddressParam();

    /// @notice Caller does not have the minter role.
    error SPG__CallerNotMinterRole();

    /// @notice License token list is empty.
    error SPG__EmptyLicenseTokens();

    /// @notice Zero address provided as a param.
    error SPGNFT__ZeroAddressParam();

    /// @notice Zero max supply provided.
    error SPGNFT__ZeroMaxSupply();

    /// @notice Max mint supply reached.
    error SPGNFT__MaxSupplyReached();

    /// @notice Minting is denied if the public minting is false (=> private) but caller does not have the minter role.
    error SPGNFT__MintingDenied();

    /// @notice Caller is not the StoryProtocolGateway.
    error SPGNFT__CallerNotSPG();

    /// @notice Caller is not the fee recipient.
    error SPGNFT__CallerNotFeeRecipient();

    /// @notice Minting is closed.
    error SPGNFT__MintingClosed();
}
