// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import { IERC5192 } from "./IERC5192.sol";
import { IStoryNFT } from "./IStoryNFT.sol";

/// @title Story Badge NFT Interface
/// @notice A Story Badge NFT is a soulbound NFT that has an unified token URI for all tokens.
interface IStoryBadgeNFT is IStoryNFT, IERC721Metadata, IERC5192 {
    ////////////////////////////////////////////////////////////////////////////
    //                              Errors                                    //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Invalid whitelist signature.
    error StoryBadgeNFT__InvalidSignature();

    /// @notice The provided whitelist signature is already used.
    error StoryBadgeNFT__SignatureAlreadyUsed();

    /// @notice Badges are soulbound, cannot be transferred.
    error StoryBadgeNFT__TransferLocked();

    /// @notice Zero address provided as a param to StoryBadgeNFT functions.
    error StoryBadgeNFT__ZeroAddressParam();

    ////////////////////////////////////////////////////////////////////////////
    //                              Structs                                   //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Struct for custom data for initializing the StoryBadgeNFT contract.
    /// @param tokenURI The token URI for all the badges (follows OpenSea metadata standard).
    /// @param signer The signer of the whitelist signatures.
    struct CustomInitParams {
        string tokenURI;
        address signer;
    }

    ////////////////////////////////////////////////////////////////////////////
    //                              Events                                    //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Emitted when a badge NFT is minted.
    /// @param recipient The address of the recipient of the badge NFT.
    /// @param tokenId The token ID of the minted badge NFT.
    /// @param ipId The ID of the badge NFT IP.
    event StoryBadgeNFTMinted(address recipient, uint256 tokenId, address ipId);

    /// @notice Emitted when the signer is updated.
    /// @param signer The new signer address.
    event StoryBadgeNFTSignerUpdated(address signer);

    ////////////////////////////////////////////////////////////////////////////
    //                             Functions                                  //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Mints a badge for the given recipient, registers it as an IP,
    ///         and makes it a derivative of the organization IP.
    /// @param recipient The address of the recipient of the badge NFT.
    /// @param signature The signature from the whitelist signer. This signautre is genreated by having the whitelist
    /// signer sign the caller's address (msg.sender) for this `mint` function.
    /// @return tokenId The token ID of the minted badge NFT.
    /// @return ipId The ID of the badge NFT IP.
    function mint(address recipient, bytes calldata signature) external returns (uint256 tokenId, address ipId);

    /// @notice Updates the whitelist signer.
    /// @param signer_ The new whitelist signer address.
    function setSigner(address signer_) external;

    /// @notice Updates the unified token URI for all badges.
    /// @param tokenURI_ The new token URI.
    function setTokenURI(string memory tokenURI_) external;
}
