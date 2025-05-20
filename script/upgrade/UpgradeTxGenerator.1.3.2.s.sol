// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { TxGenerator } from "@storyprotocol/script/utils/upgrades/TxGenerator.s.sol";
import { UpgradedImplHelper } from "@storyprotocol/script/utils/upgrades/UpgradedImplHelper.sol";
import { IModuleRegistry } from "@storyprotocol/core/interfaces/registries/IModuleRegistry.sol";

// contracts
import { RegistrationWorkflows } from "../../contracts/workflows/RegistrationWorkflows.sol";
import { ITokenizerModule } from "../../contracts/interfaces/modules/tokenizer/ITokenizerModule.sol";
import { StoryProtocolPeripheryAddressManager } from "../utils/StoryProtocolPeripheryAddressManager.sol";
import { StoryProtocolCoreAddressManager } from "../utils/StoryProtocolCoreAddressManager.sol";

/**
 * @title UpgradeTxGenerator
 * @dev Script for generating txs for upgrading a set of contracts
 *
 *      To use run the script with the following command:
 *      forge script script/upgrade/UpgradeTxGenerator.1.3.2.s.sol:UpgradeTxGeneratorExample --rpc-url=$STORY_RPC --private-key=$STORY_PRIVATEKEY
 */
contract UpgradeTxGeneratorExample is TxGenerator, StoryProtocolPeripheryAddressManager, StoryProtocolCoreAddressManager {
    constructor() TxGenerator(
        "v1.3.1", // From version
        "v1.3.2" // To version
    ) {
        _readStoryProtocolPeripheryAddresses();
        _readStoryProtocolCoreAddresses();
    }

    function run() public override {
        // Read deployment file for proxy addresses
        _readDeployment(fromVersion); // JsonDeploymentHandler.s.sol
        // Read upgrade proposals file
        _readProposalFile(fromVersion, toVersion); // JsonDeploymentHandler.s.sol
        accessManager = AccessManager(protocolAccessManagerAddr);
        console2.log("accessManager", address(accessManager));

        uint256 deployerPrivateKey = vm.envUint("STORY_PRIVATEKEY");
        deployer = vm.addr(deployerPrivateKey);

        _generateActions();

        _writeBatchTxsOutput(string.concat("schedule", "-", fromVersion, "-to-", toVersion)); // JsonBatchTxHelper.s.sol
        _writeBatchTxsOutput(string.concat("execute", "-", fromVersion, "-to-", toVersion)); // JsonBatchTxHelper.s.sol
        _writeBatchTxsOutput(string.concat("cancel", "-", fromVersion, "-to-", toVersion)); // JsonBatchTxHelper.s.sol
    }

    function _generateActions() internal override {
        console2.log("Generating schedule, execute, and cancel txs -------------");
        _generateAction("DerivativeWorkflows");
        _generateAction("GroupingWorkflows");
        _generateAction("LicenseAttachmentWorkflows");
        _generateAction("RegistrationWorkflows");
        _generateAction("RoyaltyTokenDistributionWorkflows");
        _generateAction("RoyaltyWorkflows");
        _generateAction("SPGNFTImpl");
        _generateAction("TokenizerModule");
        _generateAction("OwnableERC20Template");
    }

    /// @dev Returns the data for the upgrade proposal.
    /// @param key The key of the contract to upgrade.
    /// @param p The upgrade proposal see {UpgradedImplHelper.UpgradeProposal}
    /// @return data The encoded calldata for the upgrade proposal.
    function _getExecutionData(
        string memory key,
        UpgradedImplHelper.UpgradeProposal memory p
    ) internal virtual override returns (bytes memory data) {
        if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked("SPGNFTImpl"))) {
            console2.log("encoding SPGNFTImpl");
            data = abi.encodeWithSelector(
                RegistrationWorkflows.upgradeCollections.selector,
                p.newImpl
            );
        } else if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked("OwnableERC20Template"))) {
            console2.log("encoding OwnableERC20Template");
            data = abi.encodeWithSelector(
                ITokenizerModule.upgradeWhitelistedTokenTemplate.selector,
                ownableERC20TemplateAddr,
                p.newImpl
            );
        } else if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked("LockLicenseHook-remove"))) {
            console2.log("encoding LockLicenseHook-remove");
            data = abi.encodeWithSelector(
                IModuleRegistry.removeModule.selector,
                "LOCK_LICENSE_HOOK"
            );
        } else if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked("TotalLicenseTokenLimitHook-remove"))) {
            console2.log("encoding TotalLicenseTokenLimitHook-remove");
            data = abi.encodeWithSelector(
                IModuleRegistry.removeModule.selector,
                "TOTAL_LICENSE_TOKEN_LIMIT_HOOK"
            );
        } else if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked("LockLicenseHook-register"))) {
            console2.log("encoding LockLicenseHook-register");
            data = abi.encodeWithSignature(
                "registerModule(string,address)",
                "LOCK_LICENSE_HOOK",
                p.newImpl
            );
        } else if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked("TotalLicenseTokenLimitHook-register"))) {
            console2.log("encoding TotalLicenseTokenLimitHook-register");
            data = abi.encodeWithSignature(
                "registerModule(string,address)",
                "TOTAL_LICENSE_TOKEN_LIMIT_HOOK",
                p.newImpl
            );
        } else {
            console2.log("encoding upgradeUUPS");
            data = abi.encodeWithSelector(
                UUPSUpgradeable.upgradeToAndCall.selector,
                p.newImpl,
                ""
            );
        }
        return data;
    }

    /// @dev Checks if the proxy's authority matches the access manager.
    /// @param contractKey The key of the contract to upgrade.
    /// @param proxy The address of the proxy to check.
    function _checkMatchingAccessManager(string memory contractKey, address proxy) internal override {
        if (keccak256(abi.encodePacked(contractKey)) != keccak256(abi.encodePacked("SPGNFTImpl")) &&
            keccak256(abi.encodePacked(contractKey)) != keccak256(abi.encodePacked("OwnableERC20Template")) &&
            keccak256(abi.encodePacked(contractKey)) != keccak256(abi.encodePacked("LockLicenseHook-remove")) &&
            keccak256(abi.encodePacked(contractKey)) != keccak256(abi.encodePacked("LockLicenseHook-register")) &&
            keccak256(abi.encodePacked(contractKey)) != keccak256(abi.encodePacked("TotalLicenseTokenLimitHook-remove")) &&
            keccak256(abi.encodePacked(contractKey)) != keccak256(abi.encodePacked("TotalLicenseTokenLimitHook-register"))) {
            require(
                AccessManaged(proxy).authority() == address(accessManager),
                "Proxy's Authority must equal accessManager"
            );
        }
    }
}
