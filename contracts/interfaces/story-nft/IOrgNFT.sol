// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { WorkflowStructs } from "../../lib/WorkflowStructs.sol";

/// @title Organization NFT Interface
/// @notice Each organization token represents a Story ecosystem project.
///         The root organization token represents Story.
///         Each organization token register as a IP on Story and is a derivative of the root organization IP.
interface IOrgNFT is IERC721Metadata {
    ////////////////////////////////////////////////////////////////////////////
    //                              Errors                                     //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Caller is not the OrgStoryNFTFactory contract.
    /// @param caller The address of the caller.
    /// @param orgStoryNftFactory The address of the `OrgStoryNFTFactory` contract.
    error OrgNFT__CallerNotOrgStoryNFTFactory(address caller, address orgStoryNftFactory);

    /// @notice Caller is not the owner of `tokenId` organization token.
    /// @param tokenId The ID of the organization token.
    /// @param caller The address of the caller.
    /// @param owner The address of the owner of `tokenId` organization token.
    error OrgNFT__CallerNotOwner(uint256 tokenId, address caller, address owner);

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
    /// @param orgIpMetadata OPTIONAL. The desired metadata for the newly minted OrgNFT and registered IP.
    /// @return rootOrgTokenId The ID of the root organization token.
    /// @return rootOrgIpId The ID of the root organization IP.
    function mintRootOrgNft(
        address recipient,
        WorkflowStructs.IPMetadata calldata orgIpMetadata
    ) external returns (uint256 rootOrgTokenId, address rootOrgIpId);

    /// @notice Mints a organization token, register it as an IP,
    /// and makes the IP as a derivative of the root organization IP.
    /// @param recipient The address of the recipient of the minted organization token.
    /// @param orgIpMetadata OPTIONAL. The desired metadata for the newly minted OrgNFT and registered IP.
    /// @return orgTokenId The ID of the minted organization token.
    /// @return orgIpId The ID of the organization IP.
    function mintOrgNft(
        address recipient,
        WorkflowStructs.IPMetadata calldata orgIpMetadata
    ) external returns (uint256 orgTokenId, address orgIpId);

    /// @notice Sets the tokenURI of `tokenId` organization token.
    /// @param tokenId The ID of the organization token.
    /// @param tokenURI The new tokenURI of the organization token.
    function setTokenURI(uint256 tokenId, string memory tokenURI) external;

    /// @notice Returns the ID of the root organization IP.
    function getRootOrgIpId() external view returns (address);

    /// @notice Returns the total supply of OrgNFT.
    function totalSupply() external view returns (uint256);
}
