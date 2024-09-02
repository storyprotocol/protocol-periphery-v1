// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ERC721URIStorageUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ISPGNFT } from "./interfaces/ISPGNFT.sol";
import { Errors } from "./lib/Errors.sol";
import { SPGNFTLib } from "./lib/SPGNFTLib.sol";

contract SPGNFT is ISPGNFT, ERC721URIStorageUpgradeable, AccessControlUpgradeable {
    /// @dev Storage structure for the SPGNFTSotrage.
    /// @param maxSupply The maximum supply of the collection.
    /// @param totalSupply The total minted supply of the collection.
    /// @param mintFee The fee to mint an NFT from the collection.
    /// @param mintFeeToken The token to pay for minting.
    /// @param mintFeeRecipient The address to receive mint fees.
    /// @param mintOpen The status of minting, whether it is open or not.
    /// @custom:storage-location erc7201:story-protocol-periphery.SPGNFT
    struct SPGNFTStorage {
        uint32 maxSupply;
        uint32 totalSupply;
        uint256 mintFee;
        address mintFeeToken;
        address mintFeeRecipient;
        bool mintOpen;
        bool publicMinting;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.SPGNFT")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant SPGNFTStorageLocation = 0x66c08f80d8d0ae818983b725b864514cf274647be6eb06de58ff94d1defb6d00;

    /// @dev The address of the SPG contract.
    address public immutable SPG_ADDRESS;

    ///@dev The address of the GroupingWorkflows contract.
    address public immutable GROUPING_ADDRESS;

    /// @notice Modifier to restrict access to the SPG contract.
    modifier onlyPeriphery() {
        if (msg.sender != SPG_ADDRESS && msg.sender != GROUPING_ADDRESS)
            revert Errors.SPGNFT__CallerNotPeripheryContract();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address spg, address groupingWorkflows) {
        if (spg == address(0) || groupingWorkflows == address(0)) revert Errors.SPGNFT__ZeroAddressParam();

        SPG_ADDRESS = spg;
        GROUPING_ADDRESS = groupingWorkflows;

        _disableInitializers();
    }

    /// @dev Initializes the NFT collection.
    /// @dev If mint fee is non-zero, mint token must be set.
    /// @param name The name of the collection.
    /// @param symbol The symbol of the collection.
    /// @param maxSupply The maximum supply of the collection.
    /// @param mintFee The fee to mint an NFT from the collection.
    /// @param mintFeeToken The token to pay for minting.
    /// @param mintFeeRecipient The address to receive mint fees.
    /// @param owner The owner of the collection. Zero address indicates no owner.
    /// @param mintOpen Whether the collection is open for minting on creation. Configurable by the owner.
    /// @param isPublicMinting If true, anyone can mint from the collection. If false, only the addresses with the
    /// minter role can mint. Configurable by the owner.
    function initialize(
        string memory name,
        string memory symbol,
        uint32 maxSupply,
        uint256 mintFee,
        address mintFeeToken,
        address mintFeeRecipient,
        address owner,
        bool mintOpen,
        bool isPublicMinting
    ) public initializer {
        if (mintFee > 0 && mintFeeToken == address(0)) revert Errors.SPGNFT__ZeroAddressParam();
        if (maxSupply == 0) revert Errors.SPGNFT__ZeroMaxSupply();

        _grantRole(SPGNFTLib.ADMIN_ROLE, owner);
        _grantRole(SPGNFTLib.MINTER_ROLE, owner);

        // grant roles to SPG
        if (owner != SPG_ADDRESS) {
            _grantRole(SPGNFTLib.ADMIN_ROLE, SPG_ADDRESS);
            _grantRole(SPGNFTLib.MINTER_ROLE, SPG_ADDRESS);
        }

        SPGNFTStorage storage $ = _getSPGNFTStorage();
        $.maxSupply = maxSupply;
        $.mintFee = mintFee;
        $.mintFeeToken = mintFeeToken;
        $.mintFeeRecipient = mintFeeRecipient;
        $.mintOpen = mintOpen;
        $.publicMinting = isPublicMinting;

        __ERC721_init(name, symbol);
    }

    /// @notice Returns the total minted supply of the collection.
    function totalSupply() public view returns (uint256) {
        return uint256(_getSPGNFTStorage().totalSupply);
    }

    /// @notice Returns the current mint fee of the collection.
    function mintFee() public view returns (uint256) {
        return _getSPGNFTStorage().mintFee;
    }

    /// @notice Returns the current mint token of the collection.
    function mintFeeToken() public view returns (address) {
        return _getSPGNFTStorage().mintFeeToken;
    }

    /// @notice Returns the current mint fee recipient of the collection.
    function mintFeeRecipient() public view returns (address) {
        return _getSPGNFTStorage().mintFeeRecipient;
    }

    /// @notice Returns true if the collection is open for minting.
    function mintOpen() public view returns (bool) {
        return _getSPGNFTStorage().mintOpen;
    }

    /// @notice Returns true if the collection is open for public minting.
    function publicMinting() public view returns (bool) {
        return _getSPGNFTStorage().publicMinting;
    }

    /// @notice Sets the fee to mint an NFT from the collection. Payment is in the designated currency.
    /// @dev Only callable by the admin role.
    /// @param fee The new mint fee paid in the mint token.
    function setMintFee(uint256 fee) public onlyRole(SPGNFTLib.ADMIN_ROLE) {
        _getSPGNFTStorage().mintFee = fee;
    }

    /// @notice Sets the mint token for the collection.
    /// @dev Only callable by the admin role.
    /// @param token The new mint token for mint payment.
    function setMintFeeToken(address token) public onlyRole(SPGNFTLib.ADMIN_ROLE) {
        _getSPGNFTStorage().mintFeeToken = token;
    }

    /// @notice Sets the recipient of mint fees.
    /// @dev Only callable by the fee recipient.
    /// @param newFeeRecipient The new fee recipient.
    function setMintFeeRecipient(address newFeeRecipient) public {
        if (msg.sender != _getSPGNFTStorage().mintFeeRecipient) {
            revert Errors.SPGNFT__CallerNotFeeRecipient();
        }
        _getSPGNFTStorage().mintFeeRecipient = newFeeRecipient;
    }

    /// @notice Sets the minting status.
    /// @dev Only callable by the admin role.
    /// @param mintOpen Whether minting is open or not.
    function setMintOpen(bool mintOpen) public onlyRole(SPGNFTLib.ADMIN_ROLE) {
        _getSPGNFTStorage().mintOpen = mintOpen;
    }

    /// @notice Sets the public minting status.
    /// @dev Only callable by the admin role.
    /// @param isPublicMinting Whether the collection is open for public minting or not.
    function setPublicMinting(bool isPublicMinting) public onlyRole(SPGNFTLib.ADMIN_ROLE) {
        _getSPGNFTStorage().publicMinting = isPublicMinting;
    }

    /// @notice Mints an NFT from the collection. Only callable by the minter role.
    /// @param to The address of the recipient of the minted NFT.
    /// @param nftMetadataURI OPTIONAL. The URI of the desired metadata for the newly minted NFT.
    /// @return tokenId The ID of the minted NFT.
    function mint(address to, string calldata nftMetadataURI) public virtual returns (uint256 tokenId) {
        if (!_getSPGNFTStorage().publicMinting && !hasRole(SPGNFTLib.MINTER_ROLE, msg.sender)) {
            revert Errors.SPGNFT__MintingDenied();
        }
        tokenId = _mintToken({ to: to, payer: msg.sender, nftMetadataURI: nftMetadataURI });
    }

    /// @notice Mints an NFT from the collection. Only callable by the Periphery contracts.
    /// @param to The address of the recipient of the minted NFT.
    /// @param payer The address of the payer for the mint fee.
    /// @param nftMetadataURI OPTIONAL. The URI of the desired metadata for the newly minted NFT.
    /// @return tokenId The ID of the minted NFT.
    function mintByPeriphery(
        address to,
        address payer,
        string calldata nftMetadataURI
    ) public virtual onlyPeriphery returns (uint256 tokenId) {
        tokenId = _mintToken({ to: to, payer: payer, nftMetadataURI: nftMetadataURI });
    }

    /// @dev Withdraws the contract's token balance to the fee recipient.
    /// @param token The token to withdraw.
    function withdrawToken(address token) public {
        IERC20(token).transfer(_getSPGNFTStorage().mintFeeRecipient, IERC20(token).balanceOf(address(this)));
    }

    /// @dev Supports ERC165 interface.
    /// @param interfaceId The interface identifier.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControlUpgradeable, ERC721URIStorageUpgradeable, IERC165) returns (bool) {
        return interfaceId == type(ISPGNFT).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Mints an NFT from the collection.
    /// @param to The address of the recipient of the minted NFT.
    /// @param payer The address of the payer for the mint fee.
    /// @param nftMetadataURI OPTIONAL. The URI of the desired metadata for the newly minted NFT.
    /// @return tokenId The ID of the minted NFT.
    function _mintToken(address to, address payer, string calldata nftMetadataURI) internal returns (uint256 tokenId) {
        SPGNFTStorage storage $ = _getSPGNFTStorage();
        if (!$.mintOpen) revert Errors.SPGNFT__MintingClosed();
        if ($.totalSupply + 1 > $.maxSupply) revert Errors.SPGNFT__MaxSupplyReached();

        if ($.mintFeeToken != address(0) && $.mintFee > 0) {
            IERC20($.mintFeeToken).transferFrom(payer, address(this), $.mintFee);
        }

        tokenId = ++$.totalSupply;
        _mint(to, tokenId);

        if (bytes(nftMetadataURI).length > 0) _setTokenURI(tokenId, nftMetadataURI);
    }

    //
    // Upgrade
    //

    /// @dev Returns the storage struct of SPGNFT.
    function _getSPGNFTStorage() private pure returns (SPGNFTStorage storage $) {
        assembly {
            $.slot := SPGNFTStorageLocation
        }
    }
}
