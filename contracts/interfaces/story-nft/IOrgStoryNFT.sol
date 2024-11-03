// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IStoryNFT } from "./IStoryNFT.sol";

/// @title Organization Story NFT Interface
/// @notice Interface for StoryNFTs with Organization NFT integration.
interface IOrgStoryNFT is IStoryNFT {
    /// @notice Initializes the OrgStoryNFT.
    /// @param orgTokenId_ The token ID of the organization NFT.
    /// @param orgIpId_ The ID of the organization IP.
    /// @param initParams The initialization parameters for StoryNFT {see {StoryNftInitParams}}.
    function initialize(uint256 orgTokenId_, address orgIpId_, StoryNftInitParams calldata initParams) external;

    /// @notice Returns the upgradeable beacon address.
    function getBeacon() external view returns (address);
}
