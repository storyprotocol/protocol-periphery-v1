// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { BaseModule } from "@storyprotocol/core/modules/BaseModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { AccessControlled } from "@storyprotocol/core/access/AccessControlled.sol";
import { IPAccountStorageOps } from "@storyprotocol/core/lib/IPAccountStorageOps.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
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
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using Strings for *;
    using ERC165Checker for address;
    using IPAccountStorageOps for IIPAccount;

    /// @dev Storage structure for the TokenizerModule
    /// @param isWhitelistedTokenTemplate Mapping of token templates to their whitelisting status
    /// @param fractionalizedTokens Mapping of IP IDs to their fractionalized tokens
    /// @custom:storage-location erc7201:story-protocol-periphery.TokenizerModule
    struct TokenizerModuleStorage {
        mapping(address => bool) isWhitelistedTokenTemplate;
        mapping(address ipId => address token) fractionalizedTokens;
    }

    /// solhint-disable-next-line max-line-length
    /// keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.TokenizerModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant TokenizerModuleStorageLocation =
        0xef271c298b3e9574aa43cf546463b750863573b31e3d16f477ffc6f522452800;

    /// @notice Returns the protocol-wide license registry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice Returns the protocol-wide dispute module
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAssetRegistry,
        address licenseRegistry,
        address disputeModule
    ) AccessControlled(accessController, ipAssetRegistry) {
        if (licenseRegistry == address(0)) revert Errors.TokenizerModule__ZeroLicenseRegistry();
        if (disputeModule == address(0)) revert Errors.TokenizerModule__ZeroDisputeModule();

        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        DISPUTE_MODULE = IDisputeModule(disputeModule);
        _disableInitializers();
    }

    /// @notice Initializes the TokenizerModule
    /// @param protocolAccessManager The address of the protocol access manager
    function initialize(address protocolAccessManager) external initializer {
        if (protocolAccessManager == address(0)) revert Errors.TokenizerModule__ZeroProtocolAccessManager();

        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __ProtocolPausable_init(protocolAccessManager);
    }

    /// @notice Whitelists a token template
    /// @param tokenTemplate The address of the token template
    /// @param allowed The whitelisting status
    function whitelistTokenTemplate(address tokenTemplate, bool allowed) external restricted {
        if (tokenTemplate == address(0)) revert Errors.TokenizerModule__ZeroTokenTemplate();
        if (!tokenTemplate.supportsInterface(type(IOwnableERC20).interfaceId))
            revert Errors.TokenizerModule__UnsupportedOwnableERC20(tokenTemplate);

        TokenizerModuleStorage storage $ = _getTokenizerModuleStorage();
        $.isWhitelistedTokenTemplate[tokenTemplate] = allowed;

        emit TokenTemplateWhitelisted(tokenTemplate, allowed);
    }

    /// @notice Tokenizes (fractionalizes) an IP
    /// @param ipId The address of the IP
    /// @param tokenTemplate The address of the token template
    /// @param initData The initialization data for the token
    /// @return token The address of the newly created token
    function tokenize(
        address ipId,
        address tokenTemplate,
        bytes calldata initData
    ) external nonReentrant verifyPermission(ipId) returns (address token) {
        if (DISPUTE_MODULE.isIpTagged(ipId)) revert Errors.TokenizerModule__DisputedIpId(ipId);
        if (LICENSE_REGISTRY.isExpiredNow(ipId)) revert Errors.TokenizerModule__IpExpired(ipId);

        TokenizerModuleStorage storage $ = _getTokenizerModuleStorage();
        address existingToken = $.fractionalizedTokens[ipId];
        if (existingToken != address(0)) revert Errors.TokenizerModule__IpAlreadyTokenized(ipId, existingToken);
        if (!$.isWhitelistedTokenTemplate[tokenTemplate])
            revert Errors.TokenizerModule__TokenTemplateNotWhitelisted(tokenTemplate);

        token = address(
            new BeaconProxy(
                IOwnableERC20(tokenTemplate).upgradableBeacon(),
                abi.encodeWithSelector(IOwnableERC20.initialize.selector, ipId, initData)
            )
        );

        $.fractionalizedTokens[ipId] = token;

        emit IPTokenized(ipId, token);
    }

    /// @dev Upgrades a whitelisted token template
    /// @dev Enforced to be only callable by the upgrader admin
    /// @param tokenTemplate The address of the token template to upgrade
    /// @param newTokenImplementation The address of the new token implementation
    function upgradeWhitelistedTokenTemplate(address tokenTemplate, address newTokenImplementation) external restricted {
        if (tokenTemplate == address(0)) revert Errors.TokenizerModule__ZeroTokenTemplate();
        if (newTokenImplementation == address(0)) revert Errors.TokenizerModule__ZeroTokenTemplateImplementation();
        if (!_getTokenizerModuleStorage().isWhitelistedTokenTemplate[tokenTemplate])
            revert Errors.TokenizerModule__TokenTemplateNotWhitelisted(tokenTemplate);

        UpgradeableBeacon(IOwnableERC20(tokenTemplate).upgradableBeacon()).upgradeTo(newTokenImplementation);
    }

    /// @notice Returns the fractionalized token for an IP
    /// @param ipId The address of the IP
    /// @return token The address of the token (0 address if IP has not been tokenized)
    function getFractionalizedToken(address ipId) external view returns (address token) {
        return _getTokenizerModuleStorage().fractionalizedTokens[ipId];
    }

    /// @notice Checks if a token template is whitelisted
    /// @param tokenTemplate The address of the token template
    /// @return allowed The whitelisting status (true if whitelisted, false if not)
    function isWhitelistedTokenTemplate(address tokenTemplate) external view returns (bool allowed) {
        return _getTokenizerModuleStorage().isWhitelistedTokenTemplate[tokenTemplate];
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
