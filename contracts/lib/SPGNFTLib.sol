// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

/// @title SPG NFT Library
/// @notice Library for SPG NFT related functions.
library SPGNFTLib {
    /// @dev The default admin role, 0x1.
    bytes32 internal constant ADMIN_ROLE = bytes32(uint256(0));

    /// @dev The default minter role, 0x1.
    bytes32 internal constant MINTER_ROLE = bytes32(uint256(1));
}
