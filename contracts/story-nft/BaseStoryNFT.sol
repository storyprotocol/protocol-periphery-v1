// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721URIStorage } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IIPAssetRegistry } from "@story-protocol/protocol-core/contracts/interfaces/registries/IIPAssetRegistry.sol";
/*solhint-disable-next-line max-line-length*/
import { ILicensingModule } from "@story-protocol/protocol-core/contracts/interfaces/modules/licensing/ILicensingModule.sol";

import { IStoryNFT } from "../interfaces/story-nft/IStoryNFT.sol";

/// @title Base Story NFT
/// @notice Base StoryNFT that implements the core functionality needed for a StoryNFT.
///         To create a new custom StoryNFT, inherit from this contract and override the required functions.
///         Note: the new StoryNFT must be whitelisted in `StoryNFTFactory` by the Story governance in order
///         to use the Story NFT Factory features.
abstract contract BaseStoryNFT is IStoryNFT, ERC721URIStorage, Ownable, Initializable {
    /// @notice Story Proof-of-Creativity IP Asset Registry address.
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice Story Proof-of-Creativity Licensing Module address.
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice Organization NFT address (see {OrgNFT}).
    address public immutable ORG_NFT;

    /// @notice Associated Organization NFT token ID.
    uint256 public orgTokenId;

    /// @notice Associated Organization IP ID.
    address public orgIpId;

    /// @dev Name of the collection.
    string private _name;

    /// @dev Symbol of the collection.
    string private _symbol;

    /// @dev Contract URI of the collection (follows OpenSea contract-level metadata standard).
    string private _contractURI;

    /// @dev Base URI of the collection (see {ERC721URIStorage-tokenURI} for how it is used).
    string private _baseURI_;

    /// @dev Current total supply of the collection.
    uint256 private _totalSupply;

    constructor(address ipAssetRegistry, address licensingModule, address orgNft) ERC721("", "") Ownable(msg.sender) {
        if (ipAssetRegistry == address(0) || licensingModule == address(0) || orgNft == address(0))
            revert StoryNFT__ZeroAddressParam();
        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        ORG_NFT = orgNft;
    }

    /// @notice Initializes the StoryNFT
    /// @param orgTokenId_ The token ID of the organization NFT.
    /// @param orgIpId_ The ID of the organization IP.
    /// @param initParams The initialization parameters for StoryNFT {see {IStoryNFT-StoryNftInitParams}}.
    function initialize(
        uint256 orgTokenId_,
        address orgIpId_,
        StoryNftInitParams calldata initParams
    ) public virtual initializer {
        if (initParams.owner == address(0) || orgIpId_ == address(0)) revert StoryNFT__ZeroAddressParam();

        orgTokenId = orgTokenId_;
        orgIpId = orgIpId_;

        _name = initParams.name;
        _symbol = initParams.symbol;
        _contractURI = initParams.contractURI;
        _baseURI_ = initParams.baseURI;

        _transferOwnership(initParams.owner);
        _customize(initParams.customInitData);
    }

    /// @notice Sets the contractURI of the collection (follows OpenSea contract-level metadata standard).
    /// @param contractURI_ The new contractURI of the collection.
    function setContractURI(string memory contractURI_) external onlyOwner {
        _contractURI = contractURI_;

        emit ContractMetadataUpdated(contractURI_);
    }

    /// @notice Mints a new token and registers as an IP asset without specifying a tokenURI.
    /// @param recipient The address to mint the token to.
    /// @return tokenId The ID of the minted token.
    /// @return ipId The ID of the newly created IP.
    function _mintAndRegisterIp(address recipient) internal virtual returns (uint256 tokenId, address ipId) {
        (tokenId, ipId) = _mintAndRegisterIp(recipient, "");
    }

    /// @notice Mints a new token and registers as an IP asset.
    /// @param recipient The address to mint the token to.
    /// @param tokenURI_ The token URI of the token (see {ERC721URIStorage-tokenURI} for how it is used).
    /// @return tokenId The ID of the minted token.
    /// @return ipId The ID of the newly created IP.
    function _mintAndRegisterIp(
        address recipient,
        string memory tokenURI_
    ) internal virtual returns (uint256 tokenId, address ipId) {
        tokenId = _totalSupply++;
        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI_);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(this), tokenId);
    }

    /// @notice Register `ipId` as a derivative of `parentIpIds` under `licenseTemplate` with `licenseTermsIds`.
    /// @param ipId The ID of the IP to be registered as a derivative.
    /// @param parentIpIds The IDs of the parent IPs.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @param royaltyContext The royalty context, should be empty for Royalty Policy LAP.
    function _makeDerivative(
        address ipId,
        address[] memory parentIpIds,
        address licenseTemplate,
        uint256[] memory licenseTermsIds,
        bytes memory royaltyContext
    ) internal virtual {
        LICENSING_MODULE.registerDerivative({
            childIpId: ipId,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: licenseTemplate,
            royaltyContext: royaltyContext
        });
    }

    /// @notice IERC165 interface support.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721URIStorage, IERC165) returns (bool) {
        return interfaceId == type(IStoryNFT).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Returns the name of the collection.
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the collection.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @notice Returns the current total supply of the collection.
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /// @notice Returns the contract URI of the collection (follows OpenSea contract-level metadata standard).
    function contractURI() external view virtual returns (string memory) {
        return _contractURI;
    }

    /// @notice Initializes the StoryNFT with custom data, required to be overridden by the inheriting contracts.
    /// @dev This function is called by `initialize` function.
    /// @param customInitData The custom data to initialize the StoryNFT.
    function _customize(bytes memory customInitData) internal virtual;

    /// @notice Returns the base URI of the collection (see {ERC721URIStorage-tokenURI} for how it is used).
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURI_;
    }
}
