// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

interface IStoryProtocolGateway {
    /// @notice Event emitted when a new NFT collection is created.
    /// @param nftContract The address of the newly created NFT collection.
    event CollectionCreated(address indexed nftContract);

    /// @notice Struct for metadata for an IP.
    /// @param metadataURI The URI of the metadata for the IP.
    /// @param metadataHash The hash of the metadata for the IP.
    /// @param nftMetadataHash The hash of the metadata for the IP NFT.
    struct IPMetadata {
        string metadataURI;
        bytes32 metadataHash;
        bytes32 nftMetadataHash;
    }

    /// @notice Struct for signature data for execution via IP Account.
    /// @param signer The address of the signer for execution with signature.
    /// @param deadline The deadline for the signature.
    /// @param signature The signature for the execution via IP Account.
    struct SignatureData {
        address signer;
        uint256 deadline;
        bytes signature;
    }

    /// @notice Struct for creating a derivative IP without license tokens.
    /// @param parentIpIds The IDs of the parent IPs to link the registered derivative IP.
    /// @param licenseTemplate The address of the license template to be used for the linking.
    /// @param licenseTermsIds The IDs of the license terms to be used for the linking.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    struct MakeDerivative {
        address[] parentIpIds;
        address licenseTemplate;
        uint256[] licenseTermsIds;
        bytes royaltyContext;
    }

    /// @notice Creates a new NFT collection to be used by SPG.
    /// @param name The name of the collection.
    /// @param symbol The symbol of the collection.
    /// @param maxSupply The maximum supply of the collection.
    /// @param mintFee The cost to mint an NFT from the collection.
    /// @param mintFeeToken The token to be used for mint payment.
    /// @param owner The owner of the collection.
    /// @return nftContract The address of the newly created NFT collection.
    function createCollection(
        string calldata name,
        string calldata symbol,
        uint32 maxSupply,
        uint256 mintFee,
        address mintFeeToken,
        address owner
    ) external returns (address nftContract);

    /// @notice Mint an NFT from a collection and register it with metadata as an IP.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param nftContract The address of the NFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param nftMetadata OPTIONAL. The desired metadata for the newly minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function mintAndRegisterIp(
        address nftContract,
        address recipient,
        string calldata nftMetadata,
        IPMetadata calldata ipMetadata
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Registers an NFT as IP with metadata.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @return ipId The ID of the registered IP.
    function registerIp(
        address nftContract,
        uint256 tokenId,
        IPMetadata calldata ipMetadata,
        SignatureData calldata sigMetadata
    ) external returns (address ipId);

    /// @notice Register Programmable IP License Terms (if unregistered) and attach it to IP.
    /// @param ipId The ID of the IP.
    /// @param terms The PIL terms to be registered.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerPILTermsAndAttach(address ipId, PILTerms calldata terms) external returns (uint256 licenseTermsId);

    /// @notice Mint an NFT from a collection, register it with metadata as an IP, register Programmable IP License
    /// Terms (if unregistered), and attach it to the registered IP.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param nftContract The address of the NFT collection.
    /// @param recipient The address of the recipient of the minted NFT.
    /// @param nftMetadata OPTIONAL. The desired metadata for the newly minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param terms The PIL terms to be registered.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function mintAndRegisterIpAndAttachPILTerms(
        address nftContract,
        address recipient,
        string calldata nftMetadata,
        IPMetadata calldata ipMetadata,
        PILTerms calldata terms
    ) external returns (address ipId, uint256 tokenId, uint256 licenseTermsId);

    /// @notice Register a given NFT as an IP and attach Programmable IP License Terms.
    /// @dev Because IP Account is created in this function, we need to set the permission via signature to allow this
    /// contract to attach PIL Terms to the newly created IP Account in the same function.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param terms The PIL terms to be registered.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigAttach Signature data for attachLicenseTerms to the IP via the Licensing Module.
    /// @return ipId The ID of the registered IP.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerIpAndAttachPILTerms(
        address nftContract,
        uint256 tokenId,
        IPMetadata calldata ipMetadata,
        PILTerms calldata terms,
        SignatureData calldata sigMetadata,
        SignatureData calldata sigAttach
    ) external returns (address ipId, uint256 licenseTermsId);

    /// @notice Mint an NFT from a collection and register it as a derivative IP without license tokens.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param nftContract The address of the NFT collection.
    /// @param derivData The derivative data to be used for registerDerivative.
    /// @param nftMetadata OPTIONAL. The desired metadata for the newly minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param recipient The address to receive the minted NFT.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function mintAndRegisterIpAndMakeDerivative(
        address nftContract,
        MakeDerivative calldata derivData,
        string calldata nftMetadata,
        IPMetadata calldata ipMetadata,
        address recipient
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Register the given NFT as a derivative IP with metadata without using license tokens.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param derivData The derivative data to be used for registerDerivative.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigRegister Signature data for registerDerivative for the IP via the Licensing Module.
    /// @return ipId The ID of the registered IP.
    function registerIpAndMakeDerivative(
        address nftContract,
        uint256 tokenId,
        MakeDerivative calldata derivData,
        IPMetadata calldata ipMetadata,
        SignatureData calldata sigMetadata,
        SignatureData calldata sigRegister
    ) external returns (address ipId);

    /// @notice Mint an NFT from a collection and register it as a derivative IP using license tokens.
    /// @dev Caller must have the minter role for the provided SPG NFT.
    /// @param nftContract The address of the NFT collection.
    /// @param licenseTokenIds The IDs of the license tokens to be burned for linking the IP to parent IPs.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    /// @param nftMetadata OPTIONAL. The desired metadata for the newly minted NFT.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param recipient The address to receive the minted NFT.
    /// @return ipId The ID of the registered IP.
    /// @return tokenId The ID of the minted NFT.
    function mintAndRegisterIpAndMakeDerivativeWithLicenseTokens(
        address nftContract,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext,
        string calldata nftMetadata,
        IPMetadata calldata ipMetadata,
        address recipient
    ) external returns (address ipId, uint256 tokenId);

    /// @notice Register the given NFT as a derivative IP using license tokens.
    /// @param nftContract The address of the NFT collection.
    /// @param tokenId The ID of the NFT.
    /// @param licenseTokenIds The IDs of the license tokens to be burned for linking the IP to parent IPs.
    /// @param royaltyContext The context for royalty module, should be empty for Royalty Policy LAP.
    /// @param ipMetadata OPTIONAL. The desired metadata for the newly registered IP.
    /// @param sigMetadata OPTIONAL. Signature data for setAll (metadata) for the IP via the Core Metadata Module.
    /// @param sigRegister Signature data for registerDerivativeWithLicenseTokens for the IP via the Licensing Module.
    /// @return ipId The ID of the registered IP.
    function registerIpAndMakeDerivativeWithLicenseTokens(
        address nftContract,
        uint256 tokenId,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext,
        IPMetadata calldata ipMetadata,
        SignatureData calldata sigMetadata,
        SignatureData calldata sigRegister
    ) external returns (address ipId);
}
