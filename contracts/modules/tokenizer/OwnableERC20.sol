// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { ERC20CappedUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { IOwnableERC20 } from "../../interfaces/modules/tokenizer/IOwnableERC20.sol";

/// @title OwnableERC20
/// @notice A capped ERC20 token with an owner that can mint tokens.
contract OwnableERC20 is IOwnableERC20, ERC20CappedUpgradeable, OwnableUpgradeable {
    address public immutable UPGRADABLE_BEACON;

    constructor(address _upgradableBeacon) {
        UPGRADABLE_BEACON = _upgradableBeacon;
        _disableInitializers();
    }

    /// @notice Initializes the token
    /// @param initData The initialization data
    function initialize(bytes memory initData) external virtual initializer {
        InitData memory initData = abi.decode(initData, (InitData));

        __ERC20Capped_init(initData.cap);
        __ERC20_init(initData.name, initData.symbol);
        __Ownable_init(initData.initialOwner);
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

    /// @notice Returns whether the contract supports an interface
    /// @param interfaceId The interface ID
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IOwnableERC20).interfaceId;
    }
}
