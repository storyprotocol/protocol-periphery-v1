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

    /// @notice License token is not owned by the either caller.
    error SPG__CallerAndNotTokenOwner(uint256 tokenId, address caller, address actualTokenOwner);

    /// @notice Zero address provided as a param.
    error SPGNFT__ZeroAddressParam();

    /// @notice Zero max supply provided.
    error SPGNFT_ZeroMaxSupply();

    /// @notice Max mint supply reached.
    error SPGNFT__MaxSupplyReached();

    /// @notice Caller is not the StoryProtocolGateway.
    error SPGNFT__CallerNotSPG();
}
