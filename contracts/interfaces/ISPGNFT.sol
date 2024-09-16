// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface ISPGNFT is IAccessControl, IERC721, IERC721Metadata {
    /// @notice Struct for initializing the NFT collection.
    /// @dev If mint fee is non-zero, mint token must be set.
    /// @param name The name of the collection.
    /// @param symbol The symbol of the collection.
    /// @param baseURI The base URI for the collection. If baseURI is not empty, tokenURI will be
    /// either baseURI + token ID (if nftMetadataURI is empty) or baseURI + nftMetadataURI.
    /// @param maxSupply The maximum supply of the collection.
    /// @param mintFee The fee to mint an NFT from the collection.
    /// @param mintFeeToken The token to pay for minting.
    /// @param mintFeeRecipient The address to receive mint fees.
    /// @param owner The owner of the collection. Zero address indicates no owner.
    /// @param mintOpen Whether the collection is open for minting on creation. Configurable by the owner.
    /// @param isPublicMinting If true, anyone can mint from the collection. If false, only the addresses with the
    /// minter role can mint. Configurable by the owner.
    struct InitParams {
        string name;
        string symbol;
        string baseURI;
        uint32 maxSupply;
        uint256 mintFee;
        address mintFeeToken;
        address mintFeeRecipient;
        address owner;
        bool mintOpen;
        bool isPublicMinting;
    }

    /// @dev Initializes the NFT collection.
    /// @dev If mint fee is non-zero, mint token must be set.
    /// @param params The initialization parameters. See `InitParams`.
    function initialize(InitParams calldata params) external;

    /// @notice Returns the total minted supply of the collection.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the current mint fee of the collection.
    function mintFee() external view returns (uint256);

    /// @notice Returns the current mint token of the collection.
    function mintFeeToken() external view returns (address);

    /// @notice Returns the current mint fee recipient of the collection.
    function mintFeeRecipient() external view returns (address);

    /// @notice Returns true if the collection is open for minting.
    function mintOpen() external view returns (bool);

    /// @notice Returns true if the collection is open for public minting.
    function publicMinting() external view returns (bool);

    /// @notice Returns the base URI for the collection.
    /// @dev If baseURI is not empty, tokenURI will be either or baseURI + nftMetadataURI
    /// or baseURI + token ID (if nftMetadataURI is empty).
    function baseURI() external view returns (string memory);

    /// @notice Sets the fee to mint an NFT from the collection. Payment is in the designated currency.
    /// @dev Only callable by the admin role.
    /// @param fee The new mint fee paid in the mint token.
    function setMintFee(uint256 fee) external;

    /// @notice Sets the mint token for the collection.
    /// @dev Only callable by the admin role.
    /// @param token The new mint token for mint payment.
    function setMintFeeToken(address token) external;

    /// @notice Sets the recipient of mint fees.
    /// @dev Only callable by the fee recipient.
    /// @param newFeeRecipient The new fee recipient.
    function setMintFeeRecipient(address newFeeRecipient) external;

    /// @notice Sets the minting status.
    /// @dev Only callable by the admin role.
    /// @param mintOpen Whether minting is open or not.
    function setMintOpen(bool mintOpen) external;

    /// @notice Sets the public minting status.
    /// @dev Only callable by the admin role.
    /// @param isPublicMinting Whether the collection is open for public minting or not.
    function setPublicMinting(bool isPublicMinting) external;

    /// @notice Sets the base URI for the collection. If baseURI is not empty, tokenURI will be
    /// either baseURI + token ID (if nftMetadataURI is empty) or baseURI + nftMetadataURI.
    /// @dev Only callable by the admin role.
    /// @param baseURI The new base URI for the collection.
    function setBaseURI(string memory baseURI) external;

    /// @notice Mints an NFT from the collection. Only callable by the minter role.
    /// @param to The address of the recipient of the minted NFT.
    /// @param nftMetadataURI OPTIONAL. The desired metadata for the newly minted NFT.
    /// @return tokenId The ID of the minted NFT.
    function mint(address to, string calldata nftMetadataURI) external returns (uint256 tokenId);

    /// @notice Mints an NFT from the collection. Only callable by Periphery contracts.
    /// @param to The address of the recipient of the minted NFT.
    /// @param payer The address of the payer for the mint fee.
    /// @param nftMetadataURI OPTIONAL. The desired metadata for the newly minted NFT.
    /// @return tokenId The ID of the minted NFT.
    function mintByPeriphery(
        address to,
        address payer,
        string calldata nftMetadataURI
    ) external returns (uint256 tokenId);

    /// @dev Withdraws the contract's token balance to the fee recipient.
    /// @param token The token to withdraw.
    function withdrawToken(address token) external;
}
