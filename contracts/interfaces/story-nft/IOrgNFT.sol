// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

/// @title Organization NFT Interface
/// @notice Each organization token represents a Story ecosystem project.
///         The root organization token represents Story.
///         Each organization token register as a IP on Story and is a derivative of the root organization IP.
interface IOrgNFT is IERC721Metadata {
    ////////////////////////////////////////////////////////////////////////////
    //                              Errors                                     //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Caller is not the StoryNFTFactory contract.
    /// @param caller The address of the caller.
    /// @param storyNftFactory The address of the `StoryNFTFactory` contract.
    error OrgNFT__CallerNotStoryNFTFactory(address caller, address storyNftFactory);

    /// @notice Root organization NFT has already been minted.
    error OrgNFT__RootOrgNftAlreadyMinted();

    /// @notice Root organization NFT has not been minted yet (`mintRootOrgNft` has not been called).
    error OrgNFT__RootOrgNftNotMinted();

    /// @notice Zero address provided as a param to OrgNFT functions.
    error OrgNFT__ZeroAddressParam();

    ////////////////////////////////////////////////////////////////////////////
    //                              Events                                    //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Emitted when a organization token minted.
    /// @param recipient The address of the recipient of the organization token.
    /// @param orgNft The address of the organization NFT.
    /// @param tokenId The ID of the minted organization token.
    /// @param orgIpId The ID of the organization IP.
    event OrgNFTMinted(address recipient, address orgNft, uint256 tokenId, address orgIpId);

    ////////////////////////////////////////////////////////////////////////////
    //                             Functions                                  //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Mints the root organization token and register it as an IP.
    /// @param recipient The address of the recipient of the root organization token.
    /// @param tokenURI The URI of the root organization token.
    /// @return rootOrgTokenId The ID of the root organization token.
    /// @return rootOrgIpId The ID of the root organization IP.
    function mintRootOrgNft(
        address recipient,
        string memory tokenURI
    ) external returns (uint256 rootOrgTokenId, address rootOrgIpId);

    /// @notice Mints a organization token, register it as an IP,
    /// and makes the IP as a derivative of the root organization IP.
    /// @param recipient The address of the recipient of the minted organization token.
    /// @param tokenURI The URI of the minted organization token.
    /// @return orgTokenId The ID of the minted organization token.
    /// @return orgIpId The ID of the organization IP.
    function mintOrgNft(
        address recipient,
        string memory tokenURI
    ) external returns (uint256 orgTokenId, address orgIpId);

    /// @notice Returns the ID of the root organization IP.
    function getRootOrgIpId() external view returns (address);

    /// @notice Returns the total supply of OrgNFT.
    function totalSupply() external view returns (uint256);
}
