// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { ERC721URIStorage } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import { BaseStoryNFT } from "./BaseStoryNFT.sol";
import { IStoryBadgeNFT } from "../interfaces/story-nft/IStoryBadgeNFT.sol";

/// @title Story Badge NFT
/// @notice A Story Badge is a soulbound NFT that has an unified token URI for all tokens.
contract StoryBadgeNFT is IStoryBadgeNFT, BaseStoryNFT, ERC721Holder {
    using MessageHashUtils for bytes32;

    /// @notice Story Proof-of-Creativity PILicense Template address.
    address public immutable PIL_TEMPLATE;

    /// @notice Story Proof-of-Creativity default license terms ID.
    uint256 public immutable DEFAULT_LICENSE_TERMS_ID;

    /// @notice Signer of the whitelist signatures.
    address private _signer;

    /// @notice The unified token URI for all tokens.
    string private _tokenURI;

    /// @notice Mapping of signatures to booleans indicating whether they have been used.
    mapping(bytes signature => bool used) private _usedSignatures;

    constructor(
        address ipAssetRegistry,
        address licensingModule,
        address orgNft,
        address pilTemplate,
        uint256 defaultLicenseTermsId
    ) BaseStoryNFT(ipAssetRegistry, licensingModule, orgNft) {
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
        // The given signature must not have been used
        if (_usedSignatures[signature]) revert StoryBadgeNFT__SignatureAlreadyUsed();

        // Mark the signature as used
        _usedSignatures[signature] = true;

        // The given signature must be valid
        bytes32 digest = keccak256(abi.encodePacked(msg.sender)).toEthSignedMessageHash();
        if (!SignatureChecker.isValidSignatureNow(_signer, digest, signature)) revert StoryBadgeNFT__InvalidSignature();

        // Mint the badge and register it as an IP
        (tokenId, ipId) = _mintAndRegisterIp(address(this), _tokenURI);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = orgIpId;
        licenseTermsIds[0] = DEFAULT_LICENSE_TERMS_ID;

        // Make the badge a derivative of the organization IP
        _makeDerivative(ipId, parentIpIds, PIL_TEMPLATE, licenseTermsIds, "", 0);

        // Transfer the badge to the recipient
        _safeTransfer(address(this), recipient, tokenId);

        emit StoryBadgeNFTMinted(recipient, tokenId, ipId);
    }

    /// @notice Updates the whitelist signer.
    /// @param signer_ The new whitelist signer address.
    function setSigner(address signer_) external onlyOwner {
        _signer = signer_;
        emit StoryBadgeNFTSignerUpdated(signer_);
    }

    /// @notice Updates the unified token URI for all badges.
    /// @param tokenURI_ The new token URI.
    function setTokenURI(string memory tokenURI_) external onlyOwner {
        _tokenURI = tokenURI_;
        emit BatchMetadataUpdate(0, totalSupply());
    }

    /// @notice Returns the token URI for the given token ID.
    /// @param tokenId The token ID.
    /// @return The unified token URI for all badges.
    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage, IERC721Metadata) returns (string memory) {
        return _tokenURI;
    }

    /// @notice Initializes the StoryBadgeNFT with custom data (see {IStoryBadgeNFT-CustomInitParams}).
    /// @dev This function is called by BaseStoryNFT's `initialize` function.
    /// @param customInitData The custom data to initialize the StoryBadgeNFT.
    function _customize(bytes memory customInitData) internal override {
        CustomInitParams memory customParams = abi.decode(customInitData, (CustomInitParams));
        if (customParams.signer == address(0)) revert StoryBadgeNFT__ZeroAddressParam();

        _tokenURI = customParams.tokenURI;
        _signer = customParams.signer;
    }

    /// @notice Returns the base URI
    /// @return empty string
    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    ////////////////////////////////////////////////////////////////////////////
    //                           Locked Functions                             //
    ////////////////////////////////////////////////////////////////////////////

    function approve(address to, uint256 tokenId) public pure override(ERC721, IERC721) {
        revert StoryBadgeNFT__TransferLocked();
    }

    function setApprovalForAll(address operator, bool approved) public pure override(ERC721, IERC721) {
        revert StoryBadgeNFT__TransferLocked();
    }

    function transferFrom(address from, address to, uint256 tokenId) public pure override(ERC721, IERC721) {
        revert StoryBadgeNFT__TransferLocked();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public pure override(ERC721, IERC721) {
        revert StoryBadgeNFT__TransferLocked();
    }
}
