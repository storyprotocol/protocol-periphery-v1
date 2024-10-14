// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { IERC7572 } from "./IERC7572.sol";

/// @title IStoryNFT
/// @notice Interface for StoryNFT contracts.
interface IStoryNFT is IERC721, IERC7572 {
    ////////////////////////////////////////////////////////////////////////////
    //                              Errors                                     //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Zero address provided as a param to StoryNFT constructor.
    error StoryNFT__ZeroAddressParam();


    ////////////////////////////////////////////////////////////////////////////
    //                              Structs                                   //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Struct for initializing StoryNFT contracts.
    /// @param owner The address of the owner of this collection.
    /// @param name The name of the collection.
    /// @param symbol The symbol of the collection.
    /// @param contractURI The contract URI of the collection (follows OpenSea contract-level metadata standard).
    /// @param baseURI The base URI of the collection (see {ERC721URIStorage-tokenURI} for how it is used).
    /// @param customInitData Custom data to initialize the StoryNFT.
    struct StoryNftInitParams {
        address owner;
        string name;
        string symbol;
        string contractURI;
        string baseURI;
        bytes customInitData;
    }

    ////////////////////////////////////////////////////////////////////////////
    //                              Functions                                  //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Initializes the StoryNFT.
    /// @param orgTokenId_ The token ID of the organization NFT.
    /// @param orgIpId_ The ID of the organization IP.
    /// @param initParams The initialization parameters for StoryNFT {see {StoryNftInitParams}}.
    function initialize(uint256 orgTokenId_, address orgIpId_, StoryNftInitParams calldata initParams) external;

    /// @notice Sets the contractURI of the collection (follows OpenSea contract-level metadata standard).
    function setContractURI(string memory contractURI) external;

    /// @notice Returns the current total supply of the collection.
    function totalSupply() external view returns (uint256);
}
