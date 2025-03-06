// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title Ownable ERC20 Interface
/// @notice Interface for the Ownable ERC20 token
interface IOwnableERC20 is IERC20, IERC165 {
    /// @notice Struct for the initialization data
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param cap The cap of the token
    /// @param initialOwner The initial owner of the token
    struct InitData {
        string name;
        string symbol;
        uint256 cap;
        address initialOwner;
    }

    /// @notice Initializes the token
    /// @param initData The initialization data
    function initialize(address ipId, bytes memory initData) external;

    /// @notice Mints tokens
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external;

    /// @notice Returns the upgradable beacon
    function upgradableBeacon() external view returns (address);

    /// @notice Returns the ip id to which this fractionalized token belongs to
    function ipId() external view returns (address);
}
