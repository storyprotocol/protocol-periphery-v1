// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ISPGNFT } from "./interfaces/ISPGNFT.sol";
import { Errors } from "./lib/Errors.sol";

contract SPGNFT is ISPGNFT, ERC721Upgradeable, AccessControlUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @custom:storage-location erc7201:story-protocol-periphery.SPGNFT
    struct SPGNFTStorage {
        uint32 maxSupply;
        uint32 totalSupply;
        uint256 mintCost;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.SPGNFT")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant SPGNFTStorageLocation = 0x66c08f80d8d0ae818983b725b864514cf274647be6eb06de58ff94d1defb6d00;

    bytes32 public constant DEFAULT_MINTER_ROLE = bytes32(uint256(1));

    function initialize(
        string memory name,
        string memory symbol,
        uint32 maxSupply,
        uint256 mintCost,
        address owner
    ) public {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(DEFAULT_MINTER_ROLE, owner);

        SPGNFTStorage storage $ = _getSPGNFTStorage();
        $.maxSupply = maxSupply;
        $.mintCost = mintCost;

        __ERC721_init(name, symbol);
    }

    function setMintCost(uint256 cost) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _getSPGNFTStorage().mintCost = cost;
    }

    function mint(address to) public payable onlyRole(DEFAULT_MINTER_ROLE) returns (uint256 tokenId) {
        if (msg.value < _getSPGNFTStorage().mintCost) revert Errors.SPGNFT__InsufficientMintCost();

        SPGNFTStorage storage $ = _getSPGNFTStorage();
        if ($.totalSupply < $.maxSupply) revert Errors.SPGNFT__MaxSupplyReached();

        tokenId = ++$.totalSupply;
        _mint(to, tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControlUpgradeable, ERC721Upgradeable, IERC165) returns (bool) {
        return interfaceId == type(ISPGNFT).interfaceId || super.supportsInterface(interfaceId);
    }

    //
    // Upgrade
    //

    function _getSPGNFTStorage() private pure returns (SPGNFTStorage storage $) {
        assembly {
            $.slot := SPGNFTStorageLocation
        }
    }
}
