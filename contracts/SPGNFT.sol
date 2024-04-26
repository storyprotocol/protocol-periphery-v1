// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ISPGNFT } from "./interfaces/ISPGNFT.sol";
import { Errors } from "./lib/Errors.sol";
import { SPGNFTLib } from "./lib/SPGNFTLib.sol";

contract SPGNFT is ISPGNFT, ERC721Upgradeable, AccessControlUpgradeable {
    /// @dev Storage structure for the SPGNFTSotrage.
    /// @param maxSupply The maximum supply of the collection.
    /// @param totalSupply The total minted supply of the collection.
    /// @param mintFee The fee to mint an NFT from the collection.
    /// @param mintFeeToken The token to pay for minting.
    /// @custom:storage-location erc7201:story-protocol-periphery.SPGNFT
    struct SPGNFTStorage {
        uint32 maxSupply;
        uint32 totalSupply;
        uint256 mintFee;
        address mintFeeToken;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.SPGNFT")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant SPGNFTStorageLocation = 0x66c08f80d8d0ae818983b725b864514cf274647be6eb06de58ff94d1defb6d00;

    /// @dev The address of the SPG contract.
    address public immutable SPG_ADDRESS;

    /// @notice Modifier to restrict access to the SPG contract.
    modifier onlySPG() {
        if (msg.sender != SPG_ADDRESS) revert Errors.SPGNFT__CallerNotSPG();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address spg) {
        SPG_ADDRESS = spg;

        _disableInitializers();
    }

    /// @dev Initializes the NFT collection.
    /// @dev If mint fee is non-zero, mint token must be set.
    /// @param name The name of the collection.
    /// @param symbol The symbol of the collection.
    /// @param maxSupply The maximum supply of the collection.
    /// @param mintFee The fee to mint an NFT from the collection.
    /// @param mintFeeToken The token to pay for minting.
    /// @param owner The owner of the collection.
    function initialize(
        string memory name,
        string memory symbol,
        uint32 maxSupply,
        uint256 mintFee,
        address mintFeeToken,
        address owner
    ) public initializer {
        if (owner == address(0) || (mintFee > 0 && mintFeeToken == address(0)))
            revert Errors.SPGNFT__ZeroAddressParam();
        if (maxSupply == 0) revert Errors.SPGNFT_ZeroMaxSupply();

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

        __ERC721_init(name, symbol);
    }

    /// @notice Returns the total minted supply of the collection.
    function totalSupply() public view returns (uint256) {
        return uint256(_getSPGNFTStorage().totalSupply);
    }

    /// @notice Returns the current mint token of the collection.
    function mintFeeToken() public view returns (address) {
        return _getSPGNFTStorage().mintFeeToken;
    }

    /// @notice Returns the current mint fee of the collection.
    function mintFee() public view returns (uint256) {
        return _getSPGNFTStorage().mintFee;
    }

    /// @notice Sets the mint token for the collection.
    /// @dev Only callable by the admin role.
    /// @param token The new mint token for mint payment.
    function setMintFeeToken(address token) public onlyRole(SPGNFTLib.ADMIN_ROLE) {
        _getSPGNFTStorage().mintFeeToken = token;
    }

    /// @notice Sets the fee to mint an NFT from the collection. Payment is in the designated currency.
    /// @dev Only callable by the admin role.
    /// @param fee The new mint fee paid in the mint token.
    function setMintFee(uint256 fee) public onlyRole(SPGNFTLib.ADMIN_ROLE) {
        _getSPGNFTStorage().mintFee = fee;
    }

    /// @notice Mints an NFT from the collection. Only callable by the minter role.
    /// @param to The address of the recipient of the minted NFT.
    /// @return tokenId The ID of the minted NFT.
    function mint(address to) public onlyRole(SPGNFTLib.MINTER_ROLE) returns (uint256 tokenId) {
        tokenId = _mintFeeToken({ to: to, payer: msg.sender });
    }

    /// @notice Mints an NFT from the collection. Only callable by the SPG.
    /// @param to The address of the recipient of the minted NFT.
    /// @param payer The address of the payer for the mint fee.
    /// @return tokenId The ID of the minted NFT.
    function mintBySPG(address to, address payer) public onlySPG returns (uint256 tokenId) {
        tokenId = _mintFeeToken({ to: to, payer: payer });
    }

    /// @dev Withdraws the contract's token balance to the recipient.
    /// @param recipient The token to withdraw.
    /// @param recipient The address to receive the withdrawn balance.
    function withdrawToken(address token, address recipient) public onlyRole(SPGNFTLib.ADMIN_ROLE) {
        IERC20(token).transfer(recipient, IERC20(token).balanceOf(address(this)));
    }

    /// @dev Supports ERC165 interface.
    /// @param interfaceId The interface identifier.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControlUpgradeable, ERC721Upgradeable, IERC165) returns (bool) {
        return interfaceId == type(ISPGNFT).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Mints an NFT from the collection.
    /// @param to The address of the recipient of the minted NFT.
    /// @param payer The address of the payer for the mint fee.
    /// @return tokenId The ID of the minted NFT.
    function _mintFeeToken(address to, address payer) internal returns (uint256 tokenId) {
        SPGNFTStorage storage $ = _getSPGNFTStorage();
        if ($.totalSupply + 1 > $.maxSupply) revert Errors.SPGNFT__MaxSupplyReached();

        IERC20($.mintFeeToken).transferFrom(payer, address(this), $.mintFee);

        tokenId = ++$.totalSupply;
        _mint(to, tokenId);
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
