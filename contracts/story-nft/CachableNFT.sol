// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;
// two mode passthrough and cache
// passthrough will just forward the call to the nft contract

// cache contrat has three modes
// 1. cache mode
// 2. passthrough mode
// 3. auto mode
// cache mode will cache the nft data and return it
// passthrough mode will forward the call to the nft contract
// auto mode will cache the nft data if the basefee is greater than the threshold
import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
abstract contract CachableNFT is OwnableUpgradeable {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    /// @dev Enum for cache mode.
    enum CacheMode {
        Passthrough,
        Cache,
        Auto
    }

    /// @dev Storage structure for the CacheableNFT
    /// @custom:storage-location erc7201:story-protocol-periphery.CacheableNFT
    struct CacheableNFTStorage {
        // tokenId => ipId
        EnumerableMap.UintToAddressMap cache;
        bool DEPRECATED_cacheMode;
        CacheMode mode;
        uint256 autoCacheBaseFeeThreshold;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.CacheableNFT")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant CacheableNFTStorageLocation =
        0xb2c28ba4bb2a3f74a63ac2785b5af0c41313804d8b65acc69c0b2736a57e5f00;

    /// @notice Sets the cache mode.
    /// @param mode The new cache mode.
    function setCacheMode(CacheMode mode) external onlyOwner {
        CacheableNFTStorage storage $ = _getCacheableNFTStorage();
        $.mode = mode;
    }

    /// @notice Sets the auto cache base fee threshold.
    /// @param threshold The new auto cache base fee threshold.
    function setCacheModeAutoThreshold(uint256 threshold) external onlyOwner {
        CacheableNFTStorage storage $ = _getCacheableNFTStorage();
        $.autoCacheBaseFeeThreshold = threshold;
    }

    /// @notice Mints NFTs to the cache.
    /// @param amount The number of NFTs to mint.
    function mintToCache(uint256 amount) external onlyOwner {
        // mint NFT to cache
        for (uint256 i = 0; i < amount; i++) {
            (uint256 tokenId, address ipId) = _mintToSelf();
            // add to cache
            _getCacheableNFTStorage().cache.set(tokenId, ipId);
        }
    }

    /// @notice Returns the number of NFTs in the cache.
    /// @return The number of NFTs in the cache.
    function cacheSize() external view returns (uint256) {
        CacheableNFTStorage storage $ = _getCacheableNFTStorage();
        return $.cache.length();
    }

    /// @notice Returns the cache mode.
    /// @return The cache mode, true for cache mode, false for passthrough mode.
    function getCacheMode() external view returns (CacheMode) {
        return _getCacheableNFTStorage().mode;
    }

    /// @notice Returns the NFT at the given index in the cache.
    /// @param index The index of the NFT in the cache.
    /// @return tokenId The token ID of the NFT.
    /// @return ipId The IP ID of the NFT.
    function getCacheAtIndex(uint256 index) external view returns (uint256 tokenId, address ipId) {
        return _getCacheableNFTStorage().cache.at(index);
    }

    /// @notice Transfers the first NFT from the cache to the recipient.
    /// @param recipient The recipient of the NFT.
    /// @return tokenId The token ID of the transferred NFT.
    /// @return ipId The IP ID of the transferred NFT.
    function _transferFromCache(address recipient) internal returns (uint256 tokenId, address ipId) {
        CacheableNFTStorage storage $ = _getCacheableNFTStorage();
        if ($.mode == CacheMode.Passthrough || $.cache.length() == 0) {
            return (0, address(0));
        } else if ($.mode == CacheMode.Auto) {
            if (block.basefee <= $.autoCacheBaseFeeThreshold * 1 gwei) {
                return (0, address(0));
            }
        }

        (tokenId, ipId) = $.cache.at(0);
        $.cache.remove(tokenId);

        _transferFrom(address(this), recipient, tokenId);
    }

    /// @notice Mints an NFT to the contract itself.
    /// @return tokenId The token ID of the minted NFT.
    /// @return ipId The IP ID of the minted NFT.
    function _mintToSelf() internal virtual returns (uint256 tokenId, address ipId);

    /// @notice Transfers an NFT from one address to another.
    /// @param from The address to transfer the NFT from.
    /// @param to The address to transfer the NFT to.
    /// @param tokenId The token ID of the NFT to transfer.
    function _transferFrom(address from, address to, uint256 tokenId) internal virtual;

    /// @dev Returns the storage struct of CacheableNFT.
    function _getCacheableNFTStorage() private pure returns (CacheableNFTStorage storage $) {
        assembly {
            $.slot := CacheableNFTStorageLocation
        }
    }
}
