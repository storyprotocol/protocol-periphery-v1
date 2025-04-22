// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { UpgradeExecutor } from "@storyprotocol/script/utils/upgrades/UpgradeExecutor.s.sol";
import { UpgradedImplHelper } from "@storyprotocol/script/utils/upgrades/UpgradedImplHelper.sol";
import { IModuleRegistry } from "@storyprotocol/core/interfaces/registries/IModuleRegistry.sol";

// contracts
import { RegistrationWorkflows } from "../../contracts/workflows/RegistrationWorkflows.sol";
import { ITokenizerModule } from "../../contracts/interfaces/modules/tokenizer/ITokenizerModule.sol";
import { StoryProtocolPeripheryAddressManager } from "../utils/StoryProtocolPeripheryAddressManager.sol";
import { StoryProtocolCoreAddressManager } from "../utils/StoryProtocolCoreAddressManager.sol";

/**
 * @title UpgradeExecutor
 * @dev Script for scheduling, executing, or canceling upgrades for a set of contracts
 *
 *      To use run the script with the following command:
 *      forge script script/upgrade/UpgradeExecutor.example.s.sol:UpgradeExecutorExample --rpc-url=$RPC_URL --broadcast --priority-gas-price=1 --legacy --private-key=$PRIVATEKEY --skip-simulation
 */
contract UpgradeExecutorExample is UpgradeExecutor, StoryProtocolPeripheryAddressManager, StoryProtocolCoreAddressManager {
    constructor() UpgradeExecutor(
        "v1.3.1", // From version (e.g. v1.2.3)
        "v1.3.2", // To version (e.g. v1.3.2)
        UpgradeModes.SCHEDULE, // Schedule, Cancel or Execute upgrade
        Output.BATCH_TX_JSON // Output mode
    ) {
        _readStoryProtocolPeripheryAddresses();
        _readStoryProtocolCoreAddresses();
    }

    function run() public override {
        string memory action;
        // Read deployment file for proxy addresses
        _readDeployment(fromVersion); // JsonDeploymentHandler.s.sol
        // Read upgrade proposals file
        _readProposalFile(fromVersion, toVersion); // JsonDeploymentHandler.s.sol
        accessManager = AccessManager(protocolAccessManagerAddr);
        _readProposalFile(fromVersion, toVersion); // JsonDeploymentHandler.s.sol
        _beginBroadcast(); // BroadcastManager.s.sol
        if (outputType == Output.TX_JSON) {
            console2.log(multisig);
            deployer = multisig;
            console2.log("Generating tx json...");
        }
        // Decide actions based on mode
        if (mode == UpgradeModes.SCHEDULE) {
            action = "schedule";
            _scheduleUpgrades();
        } else if (mode == UpgradeModes.EXECUTE) {
            action = "execute";
            _executeUpgrades();
        } else if (mode == UpgradeModes.CANCEL) {
            action = "cancel";
            _cancelScheduledUpgrades();
        } else {
            revert("Invalid mode");
        }
        // If output is JSON, write the batch txx to file
        if (outputType == Output.TX_JSON) {
            _writeBatchTxsOutput(string.concat(action, "-", fromVersion, "-to-", toVersion)); // JsonBatchTxHelper.s.sol
        } else if (outputType == Output.BATCH_TX_EXECUTION) {
            // If output is BATCH_TX_EXECUTION, execute the batch txs
            _executeBatchTxs();
        } else if (outputType == Output.BATCH_TX_JSON) {
            _encodeBatchTxs(action);
        }
        // If output is TX_EXECUTION, no further action is needed
        _endBroadcast(); // BroadcastManager.s.sol
    }

    /**
     * @dev Schedules upgrades for a set of contracts, only called when UpgradeModes.SCHEDULE is used
     * This is a template listing all upgradeable contracts. Remove any contracts you don't
     * want to upgrade. For example, if upgrading only IPAssetRegistry and GroupingModule,
     * keep just those two _scheduleUpgrade() calls and remove the rest.
     */
    function _scheduleUpgrades() internal virtual override {
        console2.log("Scheduling upgrades  -------------");
        _scheduleUpgrade("DerivativeWorkflows");
        _scheduleUpgrade("GroupingWorkflows");
        _scheduleUpgrade("LicenseAttachmentWorkflows");
        _scheduleUpgrade("RegistrationWorkflows");
        _scheduleUpgrade("RoyaltyTokenDistributionWorkflows");
        _scheduleUpgrade("RoyaltyWorkflows");
        _scheduleUpgrade("SPGNFTImpl");
        _scheduleUpgrade("TokenizerModule");
        _scheduleUpgrade("OwnableERC20Template");
    }

    /**
     * @dev Executes upgrades for a set of contracts, only called when UpgradeModes.EXECUTE is used
     * This is a template listing all upgradeable contracts. Remove any contracts you don't
     * want to upgrade. For example, if upgrading only IPAssetRegistry and GroupingModule,
     * keep just those two _executeUpgrade() calls and remove the rest.
     */
    function _executeUpgrades() internal virtual override {
        console2.log("Executing upgrades  -------------");
        _executeUpgrade("DerivativeWorkflows");
        _executeUpgrade("GroupingWorkflows");
        _executeUpgrade("LicenseAttachmentWorkflows");
        _executeUpgrade("RegistrationWorkflows");
        _executeUpgrade("RoyaltyTokenDistributionWorkflows");
        _executeUpgrade("RoyaltyWorkflows");
        _executeUpgrade("SPGNFTImpl");
        _executeUpgrade("TokenizerModule");
        _executeUpgrade("OwnableERC20Template");
    }


    /**
     * @dev Cancels scheduled upgrades for a set of contracts, only called when UpgradeModes.CANCEL is used
     * This is a template listing all upgradeable contracts. Remove any contracts you don't
     * want to cancel. For example, if canceling only IPAssetRegistry and GroupingModule,
     * keep just those two _cancelScheduledUpgrade() calls and remove the rest.
     */
    function _cancelScheduledUpgrades() internal virtual override {
        console2.log("Cancelling upgrades  -------------");
        _cancelScheduledUpgrade("DerivativeWorkflows");
        _cancelScheduledUpgrade("GroupingWorkflows");
        _cancelScheduledUpgrade("LicenseAttachmentWorkflows");
        _cancelScheduledUpgrade("RegistrationWorkflows");
        _cancelScheduledUpgrade("RoyaltyTokenDistributionWorkflows");
        _cancelScheduledUpgrade("RoyaltyWorkflows");
        _cancelScheduledUpgrade("SPGNFTImpl");
        _cancelScheduledUpgrade("TokenizerModule");
        _cancelScheduledUpgrade("OwnableERC20Template");
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
