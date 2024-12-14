// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { BaseModule } from "@storyprotocol/core/modules/BaseModule.sol";
import { AccessControlled } from "@storyprotocol/core/access/AccessControlled.sol";
import { IDisputeModule } from "@storyprotocol/core/interfaces/modules/dispute/IDisputeModule.sol";

/// @title Tokenizer Module
/// @notice Tokenizer module is the main entry point for the IPA Tokenization and Fractionalization.
/// It is responsible for:
/// - Tokenize an IPA
/// - Whitelist ERC20 Token Templates
contract TokenizerModule is BaseModule, AccessControlled {
    using ERC165Checker for address;
    using Strings for *;

    /// @notice Returns the protocol-wide dispute module
    IDisputeModule public immutable DISPUTE_MODULE;

    constructor(
        address accessController,
        address ipAssetRegistry,
        address disputeModule
    ) AccessControlled(accessController, ipAssetRegistry) {
        DISPUTE_MODULE = IDisputeModule(disputeModule);
    }

    function whitelistTokenTemplate(address tokenTemplate, bool allowed) external {}

    function tokenize(address ipId, address tokenTemplate, bytes calldata initData) external verifyPermission(ipId) {}

    function name() external pure override returns (string memory) {
        return "TOKENIZER_MODULE";
    }
}
