// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
/* solhint-disable-next-line max-line-length */
import { ERC721URIStorageUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import { BaseOrgStoryNFT } from "./BaseOrgStoryNFT.sol";
import { CachableNFT } from "./CachableNFT.sol";
import { IStoryBadgeNFT } from "../interfaces/story-nft/IStoryBadgeNFT.sol";

/// @title Story Badge NFT
/// @notice A Story Badge is a soulbound NFT that has an unified token URI for all tokens.
contract StoryBadgeNFT is IStoryBadgeNFT, BaseOrgStoryNFT, CachableNFT, ERC721Holder {
    using MessageHashUtils for bytes32;

    /// @notice Story Proof-of-Creativity PILicense Template address.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable PIL_TEMPLATE;

    /// @notice Story Proof-of-Creativity default license terms ID.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint256 public immutable DEFAULT_LICENSE_TERMS_ID;

    /// @dev Storage structure for the StoryBadgeNFT
    /// @param signer The signer of the whitelist signatures.
    /// @param tokenURI The unified token URI for all tokens.
    /// @param ipMetadataURI The URI of the metadata for all IP from this collection.
    /// @param ipMetadataHash The hash of the metadata for all IP from this collection.
    /// @param nftMetadataHash The hash of the metadata for all IP NFTs from this collection.
    /// @param usedSignatures Mapping of signatures to booleans indicating whether they have been used.
    /// @custom:storage-location erc7201:story-protocol-periphery.StoryBadgeNFT
    struct StoryBadgeNFTStorage {
        address signer;
        string tokenURI;
        string ipMetadataURI;
        bytes32 ipMetadataHash;
        bytes32 nftMetadataHash;
        mapping(bytes signature => bool used) usedSignatures;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.StoryBadgeNFT")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant StoryBadgeNFTStorageLocation =
        0x00c5d7dc46f601fb1120e8b9ebb4fdf899cffbfddad19ced3e4dad5853224400;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address ipAssetRegistry,
        address licensingModule,
        address coreMetadataModule,
        address upgradeableBeacon,
        address orgNft,
        address pilTemplate,
        uint256 defaultLicenseTermsId
    ) BaseOrgStoryNFT(ipAssetRegistry, licensingModule, coreMetadataModule, upgradeableBeacon, orgNft) {
        if (
            ipAssetRegistry == address(0) ||
            licensingModule == address(0) ||
            pilTemplate == address(0) ||
            orgNft == address(0)
        ) revert StoryBadgeNFT__ZeroAddressParam();

        PIL_TEMPLATE = pilTemplate;
        DEFAULT_LICENSE_TERMS_ID = defaultLicenseTermsId;

        _disableInitializers();
    }

    /// @notice Returns true if the token is locked.
    /// @dev This is a placeholder function to satisfy the ERC5192 interface.
    /// @return bool Always true.
    function locked(uint256 tokenId) external pure returns (bool) {
        return true;
    }

    /// @notice Mints a badge for the given recipient, registers it as an IP,
    ///         and makes it a derivative of the organization IP.
    /// @param recipient The address of the recipient of the badge.
    /// @param signature The signature from the whitelist signer. This signautre is genreated by having the whitelist
    /// signer sign the caller's address (msg.sender) for this `mint` function.
    /// @return tokenId The token ID of the minted badge NFT.
    /// @return ipId The ID of the badge NFT IP.
    function mint(address recipient, bytes calldata signature) external returns (uint256 tokenId, address ipId) {
        StoryBadgeNFTStorage storage $ = _getStoryBadgeNFTStorage();

        // The given signature must not have been used
        if ($.usedSignatures[signature]) revert StoryBadgeNFT__SignatureAlreadyUsed();

        // Mark the signature as used
        $.usedSignatures[signature] = true;

        // The given signature must be valid
        bytes32 digest = keccak256(abi.encodePacked(msg.sender)).toEthSignedMessageHash();
        if (!SignatureChecker.isValidSignatureNow($.signer, digest, signature))
            revert StoryBadgeNFT__InvalidSignature();

        // Try to transfer from cache first
        (tokenId, ipId) = _transferFromCache(recipient);

        if (ipId == address(0)) {
            // cache miss or cache mode is disabled, mint directly
            (tokenId, ipId) = _mintToSelf();

            // Transfer the badge to the recipient
            _transfer(address(this), recipient, tokenId);
        }

        emit StoryBadgeNFTMinted(recipient, tokenId, ipId);
    }

    /// @notice Updates the whitelist signer.
    /// @param signer_ The new whitelist signer address.
    function setSigner(address signer_) external onlyOwner {
        _getStoryBadgeNFTStorage().signer = signer_;
        emit StoryBadgeNFTSignerUpdated(signer_);
    }

    /// @notice Updates the unified token URI for all badges.
    /// @param tokenURI_ The new token URI.
    function setTokenURI(string memory tokenURI_) external onlyOwner {
        _getStoryBadgeNFTStorage().tokenURI = tokenURI_;
        emit BatchMetadataUpdate(0, totalSupply());
    }

    /// @notice Returns the token URI for the given token ID.
    /// @param tokenId The token ID.
    /// @return The unified token URI for all badges.
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721URIStorageUpgradeable, IERC721Metadata) returns (string memory) {
        return _getStoryBadgeNFTStorage().tokenURI;
    }

    /// @notice Initializes the StoryBadgeNFT with custom data (see {IStoryBadgeNFT-CustomInitParams}).
    /// @dev This function is called by BaseStoryNFT's `initialize` function.
    /// @param customInitData The custom data to initialize the StoryBadgeNFT.
    function _customize(bytes memory customInitData) internal override onlyInitializing {
        CustomInitParams memory customParams = abi.decode(customInitData, (CustomInitParams));
        if (customParams.signer == address(0)) revert StoryBadgeNFT__ZeroAddressParam();

        StoryBadgeNFTStorage storage $ = _getStoryBadgeNFTStorage();
        $.tokenURI = customParams.tokenURI;
        $.signer = customParams.signer;
        $.ipMetadataURI = customParams.ipMetadataURI;
        $.ipMetadataHash = customParams.ipMetadataHash;
        $.nftMetadataHash = customParams.nftMetadataHash;
    }

    /// @notice Returns the base URI
    /// @return empty string
    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    /// @notice Mints an NFT to the contract itself.
    /// @return tokenId The token ID of the minted NFT.
    /// @return ipId The IP ID of the minted NFT.
    function _mintToSelf() internal override returns (uint256 tokenId, address ipId) {
        StoryBadgeNFTStorage storage $ = _getStoryBadgeNFTStorage();

        // Mint the badge and register it as an IP
        (tokenId, ipId) = _mintAndRegisterIp(
            address(this),
            $.tokenURI,
            $.ipMetadataURI,
            $.ipMetadataHash,
            $.nftMetadataHash
        );

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = orgIpId();
        licenseTermsIds[0] = DEFAULT_LICENSE_TERMS_ID;

        // Make the badge a derivative of the organization IP
        _makeDerivative(ipId, parentIpIds, PIL_TEMPLATE, licenseTermsIds, "", 0, 0);
    }

    /// @notice Transfers an NFT from one address to another.
    /// @param from The address to transfer the NFT from.
    /// @param to The address to transfer the NFT to.
    /// @param tokenId The token ID of the NFT to transfer.
    function _transferFrom(address from, address to, uint256 tokenId) internal override {
        _transfer(from, to, tokenId);
    }

    /// @dev Returns the storage struct of StoryBadgeNFT.
    function _getStoryBadgeNFTStorage() private pure returns (StoryBadgeNFTStorage storage $) {
        assembly {
            $.slot := StoryBadgeNFTStorageLocation
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    //                           Locked Functions                             //
    ////////////////////////////////////////////////////////////////////////////

    function approve(address to, uint256 tokenId) public pure override(ERC721Upgradeable, IERC721) {
        revert StoryBadgeNFT__TransferLocked();
    }

    function setApprovalForAll(address operator, bool approved) public pure override(ERC721Upgradeable, IERC721) {
        revert StoryBadgeNFT__TransferLocked();
    }

    function transferFrom(address from, address to, uint256 tokenId) public pure override(ERC721Upgradeable, IERC721) {
        revert StoryBadgeNFT__TransferLocked();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public pure override(ERC721Upgradeable, IERC721) {
        revert StoryBadgeNFT__TransferLocked();
    }
}
