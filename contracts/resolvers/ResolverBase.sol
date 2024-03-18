// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { AccessControlled } from "@storyprotocol/contracts/access/AccessControlled.sol";

import { IResolver } from "../interfaces/resolvers/IResolver.sol";

/// @notice IP Resolver Base Contract
abstract contract ResolverBase is IResolver, AccessControlled {
    constructor(address accessController, address assetRegistry) AccessControlled(accessController, assetRegistry) {}

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 id) public view virtual override(IResolver) returns (bool) {
        return id == type(IResolver).interfaceId;
    }
}
