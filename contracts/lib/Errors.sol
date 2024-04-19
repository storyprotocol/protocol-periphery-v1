// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

/// @title Errors Library
/// @notice Library for all Story Protocol periphery contract errors.
library Errors {
    /// @notice Zero address provided as a param.
    error SPG__ZeroAddressParam();

    /// @notice Insufficient amount for minting cost.
    error SPGNFT__InsufficientMintCost();

    /// @notice Max mint supply reached.
    error SPGNFT__MaxSupplyReached();
}
