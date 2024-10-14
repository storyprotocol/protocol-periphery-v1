// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title ERC7572 interface
/// @notice Interface for supporting contract-level metadata
interface IERC7572 {
    /// @notice Emitted when the contract-level metadata is updated
    event ContractURIUpdated();

    /// @notice Returns the contract-level metadata
    function contractURI() external view returns (string memory);
}
