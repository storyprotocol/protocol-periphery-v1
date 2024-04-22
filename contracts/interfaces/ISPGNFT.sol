// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface ISPGNFT is IAccessControl, IERC721, IERC721Metadata {
    /// @dev Initializes the NFT collection.
    /// @param name The name of the collection.
    /// @param symbol The symbol of the collection.
    /// @param maxSupply The maximum supply of the collection.
    /// @param mintCost The cost to mint an NFT from the collection.
    /// @param owner The owner of the collection.
    function initialize(
        string memory name,
        string memory symbol,
        uint32 maxSupply,
        uint256 mintCost,
        address owner
    ) external;

    /// @dev Sets the cost to mint an NFT from the collection. Payment is in native currency of the chain. Only callable
    /// by the admin role.
    /// @param cost The new mint cost in native currency of the chain.
    function setMintCost(uint256 cost) external;

    /// @notice Mints an NFT from the collection. Only callable by the minter role.
    /// @param to The address of the recipient of the minted NFT.
    function mint(address to) external payable returns (uint256 tokenId);
}
