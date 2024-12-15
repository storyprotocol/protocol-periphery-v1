// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { BaseModule } from "@storyprotocol/core/modules/BaseModule.sol";
import { AccessControlled } from "@storyprotocol/core/access/AccessControlled.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { IPAccountStorageOps } from "@storyprotocol/core/lib/IPAccountStorageOps.sol";
import { IDisputeModule } from "@storyprotocol/core/interfaces/modules/dispute/IDisputeModule.sol";
import { ProtocolPausableUpgradeable } from "@storyprotocol/core/pause/ProtocolPausableUpgradeable.sol";

import { IOwnableERC20 } from "../../interfaces/modules/tokenizer/IOwnableERC20.sol";
import { Errors } from "../../lib/Errors.sol";
import { ITokenizerModule } from "../../interfaces/modules/tokenizer/ITokenizerModule.sol";

/// @title Tokenizer Module
/// @notice Tokenizer module is the main entry point for the IPA Tokenization and Fractionalization.
/// It is responsible for:
/// - Tokenize an IPA
/// - Whitelist ERC20 Token Templates
contract TokenizerModule is
    ITokenizerModule,
    BaseModule,
    AccessControlled,
    ProtocolPausableUpgradeable,
    UUPSUpgradeable
{
    using Strings for *;
    using ERC165Checker for address;
    using IPAccountStorageOps for IIPAccount;

    /// @dev Storage structure for the TokenizerModule
    /// @param isWhitelistedTokenTemplate Mapping of token templates to their whitelisting status
    /// @custom:storage-location erc7201:story-protocol-periphery.TokenizerModule
    struct TokenizerModuleStorage {
        mapping(address => bool) isWhitelistedTokenTemplate;
    }

    /// solhint-disable-next-line max-line-length
    /// keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.TokenizerModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant TokenizerModuleStorageLocation =
        0xef271c298b3e9574aa43cf546463b750863573b31e3d16f477ffc6f522452800;

    bytes32 public constant EXPIRATION_TIME = "EXPIRATION_TIME";

    /// @notice Returns the protocol-wide dispute module
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAssetRegistry,
        address disputeModule
    ) AccessControlled(accessController, ipAssetRegistry) {
        if (disputeModule == address(0)) revert Errors.TokenizerModule__ZeroDisputeModule();

        DISPUTE_MODULE = IDisputeModule(disputeModule);
    }

    /// @notice Whitelists a token template
    /// @param tokenTemplate The address of the token template
    /// @param allowed The whitelisting status
    function whitelistTokenTemplate(address tokenTemplate, bool allowed) external restricted {
        if (tokenTemplate == address(0)) revert Errors.TokenizerModule__ZeroTokenTemplate();
        if (!tokenTemplate.supportsInterface(type(IOwnableERC20).interfaceId))
            revert Errors.TokenizerModule__UnsupportedERC20(tokenTemplate);

        TokenizerModuleStorage storage $ = _getTokenizerModuleStorage();
        $.isWhitelistedTokenTemplate[tokenTemplate] = allowed;

        emit TokenTemplateWhitelisted(tokenTemplate, allowed);
    }

    /// @notice Tokenizes an IP
    /// @param ipId The address of the IP
    /// @param tokenTemplate The address of the token template
    /// @param initData The initialization data for the token
    /// @return token The address of the newly created token
    function tokenize(
        address ipId,
        address tokenTemplate,
        bytes calldata initData
    ) external verifyPermission(ipId) returns (address token) {
        if (DISPUTE_MODULE.isIpTagged(ipId)) revert Errors.TokenizerModule__DisputedIpId(ipId);
        if (!IP_ASSET_REGISTRY.isRegistered(ipId)) revert Errors.TokenizerModule__IpNotRegistered(ipId);
        if (_isExpiredNow(ipId)) revert Errors.TokenizerModule__IpExpired(ipId);

        TokenizerModuleStorage storage $ = _getTokenizerModuleStorage();
        if (!$.isWhitelistedTokenTemplate[tokenTemplate])
            revert Errors.TokenizerModule__TokenTemplateNotWhitelisted(tokenTemplate);

        token = address(
            new BeaconProxy(
                IOwnableERC20(tokenTemplate).upgradableBeacon(),
                abi.encodeWithSelector(IOwnableERC20.initialize.selector, initData)
            )
        );

        emit IPTokenized(ipId, token);
    }

    /// @dev Check if an IP is expired now
    /// @param ipId The address of the IP
    function _isExpiredNow(address ipId) internal view returns (bool) {
        uint256 expireTime = _getExpireTime(ipId);
        return expireTime != 0 && expireTime < block.timestamp;
    }

    /// @dev Get the expiration time of an IP
    /// @param ipId The address of the IP
    function _getExpireTime(address ipId) internal view returns (uint256) {
        return IIPAccount(payable(ipId)).getUint256(EXPIRATION_TIME);
    }

    /// @dev Returns the name of the module
    function name() external pure override returns (string memory) {
        return "TOKENIZER_MODULE";
    }

    /// @dev Returns the storage struct of TokenizerModule.
    function _getTokenizerModuleStorage() private pure returns (TokenizerModuleStorage storage $) {
        assembly {
            $.slot := TokenizerModuleStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
