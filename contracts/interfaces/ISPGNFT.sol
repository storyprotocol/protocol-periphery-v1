// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface ISPGNFT is IAccessControl, IERC721, IERC721Metadata {
    /// @dev Initializes the NFT collection.
    /// @dev If mint cost is non-zero, mint token must be set.
    /// @param name The name of the collection.
    /// @param symbol The symbol of the collection.
    /// @param maxSupply The maximum supply of the collection.
    /// @param mintFee The cost to mint an NFT from the collection.
    /// @param mintFeeToken The token to pay for minting.
    /// @param owner The owner of the collection.
    function initialize(
        string memory name,
        string memory symbol,
        uint32 maxSupply,
        uint256 mintFee,
        address mintFeeToken,
        address owner
    ) external;

    /// @notice Returns the total minted supply of the collection.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the current mint token of the collection.
    function mintFeeToken() external view returns (address);

    /// @notice Returns the current mint fee of the collection.
    function mintFee() external view returns (uint256);

    /// @notice Sets the mint token for the collection.
    /// @dev Only callable by the admin role.
    /// @param token The new mint token for mint payment.
    function setMintFeeToken(address token) external;

    /// @notice Sets the fee to mint an NFT from the collection. Payment is in the designated currency.
    /// @dev Only callable by the admin role.
    /// @param fee The new mint fee paid in the mint token.
    function setMintFee(uint256 fee) external;

    /// @notice Mints an NFT from the collection. Only callable by the minter role.
    /// @param to The address of the recipient of the minted NFT.
    /// @return tokenId The ID of the minted NFT.
    function mint(address to) external returns (uint256 tokenId);

    /// @notice Mints an NFT from the collection. Only callable by the SPG.
    /// @param to The address of the recipient of the minted NFT.
    /// @param payer The address of the payer for the mint fee.
    /// @return tokenId The ID of the minted NFT.
    function mintBySPG(address to, address payer) external returns (uint256 tokenId);

    /// @dev Withdraws the contract's token balance to the recipient.
    /// @param recipient The token to withdraw.
    /// @param recipient The address to receive the withdrawn balance.
    function withdrawToken(address token, address recipient) external;
}
