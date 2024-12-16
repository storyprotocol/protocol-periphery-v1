// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ERC20CappedUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";

import { Errors } from "../../lib/Errors.sol";
import { IOwnableERC20 } from "../../interfaces/modules/tokenizer/IOwnableERC20.sol";

/// @title OwnableERC20
/// @notice A capped ERC20 token with an owner that can mint tokens.
contract OwnableERC20 is IOwnableERC20, ERC20CappedUpgradeable, OwnableUpgradeable {
    /// @dev Storage structure for the OwnableERC20
    /// @param ipId The ip id to whom this fractionalized token belongs to
    /// @custom:storage-location erc7201:story-protocol-periphery.OwnableERC20
    struct OwnableERC20Storage {
        address ipId;
    }

    // solhint-disable-next-line max-line-length
    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.OwnableERC20")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant OwnableERC20StorageLocation =
        0xc4b74d5382372ff8ada6effed0295109822b72fe030fc4cd981ca0e25adfab00;

    /// @notice The upgradable beacon of this contract
    address public immutable UPGRADABLE_BEACON;

    constructor(address _upgradableBeacon) {
        UPGRADABLE_BEACON = _upgradableBeacon;
        _disableInitializers();
    }

    /// @notice Initializes the token
    /// @param initData The initialization data
    function initialize(address ipId, bytes memory initData) external virtual initializer {
        if (ipId == address(0)) revert Errors.OwnableERC20__ZeroIpId();

        InitData memory initData = abi.decode(initData, (InitData));

        __ERC20Capped_init(initData.cap);
        __ERC20_init(initData.name, initData.symbol);
        __Ownable_init(initData.initialOwner);

        OwnableERC20Storage storage $ = _getOwnableERC20Storage();
        $.ipId = ipId;
    }

    /// @notice Mints tokens to the specified address.
    /// @param to The address to mint tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address to, uint256 amount) external virtual onlyOwner {
        _mint(to, amount);
    }

    /// @notice Returns the upgradable beacon
    function upgradableBeacon() external view returns (address) {
        return UPGRADABLE_BEACON;
    }

    /// @notice Returns the ip id to whom this fractionalized token belongs to
    function ipId() external view returns (address) {
        return _getOwnableERC20Storage().ipId;
    }

    /// @notice Returns whether the contract supports an interface
    /// @param interfaceId The interface ID
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IOwnableERC20).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @dev Returns the storage struct of OwnableERC20.
    function _getOwnableERC20Storage() private pure returns (OwnableERC20Storage storage $) {
        assembly {
            $.slot := OwnableERC20StorageLocation
        }
    }
}
