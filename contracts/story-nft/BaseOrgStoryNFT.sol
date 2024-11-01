// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

import { IOrgStoryNFT } from "../interfaces/story-nft/IOrgStoryNFT.sol";
import { BaseStoryNFT } from "./BaseStoryNFT.sol";

/// @title Base Story NFT with OrgNFT integration
/// @notice Base Story NFT which integrates with the OrgNFT and StoryNFTFactory.
abstract contract BaseOrgStoryNFT is IOrgStoryNFT, BaseStoryNFT {
    /// @notice Organization NFT address (see {OrgNFT}).
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable ORG_NFT;

    /// @dev Storage structure for the BaseOrgStoryNFT
    /// @param orgTokenId Associated Organization NFT token ID.
    /// @param orgIpId Associated Organization IP ID.
    /// @custom:storage-location erc7201:story-protocol-periphery.BaseOrgStoryNFT
    struct BaseOrgStoryNFTStorage {
        uint256 orgTokenId;
        address orgIpId;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.BaseOrgStoryNFT")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant BaseOrgStoryNFTStorageLocation =
        0x52eea8b3c549d1bd8b986d98314c387ab153ca0f32b6949d51f32dbd11b07900;

    constructor(
        address ipAssetRegistry,
        address licensingModule,
        address orgNft
    ) BaseStoryNFT(ipAssetRegistry, licensingModule) {
        if (orgNft == address(0)) revert StoryNFT__ZeroAddressParam();
        ORG_NFT = orgNft;
        _disableInitializers();
    }

    /// @dev External initializer function, to be overridden by the inheriting contracts.
    /// @param orgTokenId_ The token ID of the organization NFT.
    /// @param orgIpId_ The ID of the organization IP.
    /// @param initParams The initialization parameters for StoryNFT {see {IStoryNFT-StoryNftInitParams}}.
    function initialize(
        uint256 orgTokenId_,
        address orgIpId_,
        StoryNftInitParams calldata initParams
    ) external virtual initializer {
        __BaseOrgStoryNFT_init(orgTokenId_, orgIpId_, initParams);
    }

    /// @dev Initialize the BaseOrgStoryNFT
    /// @param orgTokenId_ The token ID of the organization NFT.
    /// @param orgIpId_ The ID of the organization IP.
    /// @param initParams The initialization parameters for StoryNFT {see {IStoryNFT-StoryNftInitParams}}.
    function __BaseOrgStoryNFT_init(
        uint256 orgTokenId_,
        address orgIpId_,
        StoryNftInitParams calldata initParams
    ) internal onlyInitializing {
        if (orgIpId_ == address(0)) revert StoryNFT__ZeroAddressParam();
        __BaseStoryNFT_init(initParams);

        BaseOrgStoryNFTStorage storage $ = _getBaseOrgStoryNFTStorage();
        $.orgTokenId = orgTokenId_;
        $.orgIpId = orgIpId_;
    }

    /// @notice Returns the token ID of the associated Organization NFT.
    function orgTokenId() public view returns (uint256) {
        return _getBaseOrgStoryNFTStorage().orgTokenId;
    }

    /// @notice Returns the ID of the associated Organization IP.
    function orgIpId() public view returns (address) {
        return _getBaseOrgStoryNFTStorage().orgIpId;
    }

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseStoryNFT, IERC165) returns (bool) {
        return interfaceId == type(IOrgStoryNFT).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Returns the storage struct of BaseOrgStoryNFT.
    function _getBaseOrgStoryNFTStorage() private pure returns (BaseOrgStoryNFTStorage storage $) {
        assembly {
            $.slot := BaseOrgStoryNFTStorageLocation
        }
    }
}
