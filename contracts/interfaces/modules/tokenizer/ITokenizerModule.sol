// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IModule } from "@storyprotocol/core/interfaces/modules/base/IModule.sol";

/// @title Tokenizer Module Interface
/// @notice Interface for the Tokenizer Module
interface ITokenizerModule is IModule {
    /// @notice Event emitted when a token template is whitelisted
    /// @param tokenTemplate The address of the token template
    /// @param allowed The whitelisting status
    event TokenTemplateWhitelisted(address tokenTemplate, bool allowed);

    /// @notice Event emitted when an IP is tokenized
    /// @param ipId The address of the IP
    /// @param token The address of the token
    event IPTokenized(address ipId, address token);

    /// @notice Whitelists a token template
    /// @param tokenTemplate The address of the token template
    /// @param allowed The whitelisting status
    function whitelistTokenTemplate(address tokenTemplate, bool allowed) external;

    /// @notice Tokenizes an IP
    /// @param ipId The address of the IP
    /// @param tokenTemplate The address of the token template
    /// @param initData The initialization data for the token
    /// @return token The address of the newly created token
    function tokenize(address ipId, address tokenTemplate, bytes calldata initData) external returns (address token);

    /// @dev Upgrades a whitelisted token template
    /// @dev Enforced to be only callable by the upgrader admin
    /// @param tokenTemplate The address of the token template to upgrade
    /// @param newTokenImplementation The address of the new token implementation
    function upgradeWhitelistedTokenTemplate(address tokenTemplate, address newTokenImplementation) external;

    /// @notice Returns the fractionalized token for an IP
    /// @param ipId The address of the IP
    /// @return token The address of the token
    function getFractionalizedToken(address ipId) external view returns (address token);

    /// @notice Checks if a token template is whitelisted
    /// @param tokenTemplate The address of the token template
    /// @return allowed The whitelisting status (true if whitelisted, false if not)
    function isWhitelistedTokenTemplate(address tokenTemplate) external view returns (bool allowed);
}
