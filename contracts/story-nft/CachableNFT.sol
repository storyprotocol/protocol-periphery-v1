// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;
// two mode passthrough and cache
// passthrough will just forward the call to the nft contract

// cache contrat has two modes
// 1. cache mode
// 2. passthrough mode
// cache mode will cache the nft data and return it
// passthrough mode will forward the call to the nft contract
import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
abstract contract CachableNFT is OwnableUpgradeable {
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    /// @dev Storage structure for the CacheableNFT
    /// @custom:storage-location erc7201:story-protocol-periphery.CacheableNFT
    struct CacheableNFTStorage {
        // tokenId => ipId
        EnumerableMap.UintToAddressMap cache;
        bool cacheMode;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.CacheableNFT")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant CacheableNFTStorageLocation =
        0xb2c28ba4bb2a3f74a63ac2785b5af0c41313804d8b65acc69c0b2736a57e5f00;

    function setCacheMode(bool useCache) external onlyOwner {
        CacheableNFTStorage storage $ = _getCacheableNFTStorage();
        $.cacheMode = useCache;
    }

    function mintToCache(uint256 amount) external onlyOwner {
        // mint NFT to cache
        for (uint256 i = 0; i < amount; i++) {
            (uint256 tokenId, address ipId) = _mintToSelf();
            // add to cache
            _getCacheableNFTStorage().cache.set(tokenId, ipId);
        }
    }

    function cacheSize() external view returns (uint256) {
        CacheableNFTStorage storage $ = _getCacheableNFTStorage();
        return $.cache.length();
    }

    function _transferFromCache(address recipient) internal returns (uint256 tokenId, address ipId) {
        CacheableNFTStorage storage $ = _getCacheableNFTStorage();
        if (!$.cacheMode || $.cache.length() == 0) {
            return (0, address(0));
        }
        (tokenId, ipId) = $.cache.at(0);
        _transferFrom(address(this), recipient, tokenId);
    }

    function _mintToSelf() internal virtual returns (uint256 tokenId, address ipId);
    function _transferFrom(address from, address to, uint256 tokenId) internal virtual;

    /// @dev Returns the storage struct of CacheableNFT.
    function _getCacheableNFTStorage() private pure returns (CacheableNFTStorage storage $) {
        assembly {
            $.slot := CacheableNFTStorageLocation
        }
    }
}
