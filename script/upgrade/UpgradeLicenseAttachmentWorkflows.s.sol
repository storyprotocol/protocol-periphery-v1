// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";

// contracts
import { LicenseAttachmentWorkflows } from "../../contracts/workflows/LicenseAttachmentWorkflows.sol";

// script
import { UpgradeHelper } from "../utils/upgrades/UpgradeHelper.s.sol";

contract UpgradeLicenseAttachmentWorkflows is UpgradeHelper {
    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/upgrade/UpgradeLicenseAttachmentWorkflows.s.sol:UpgradeLicenseAttachmentWorkflows \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public override {
        super.run();
        _beginBroadcast();
        _deployLicenseAttachmentWorkflows();

        // Upgrade via multisig (can't do here).
        // licenseAttachmentWorkflows.upgradeToAndCall(address(newLicenseAttachmentWorkflowsImpl), "");

        _writeDeployment();
        _endBroadcast();
    }

    function _deployLicenseAttachmentWorkflows() private {
        _predeploy("LicenseAttachmentWorkflows");
        address newLicenseAttachmentWorkflowsImpl = address(
            new LicenseAttachmentWorkflows(
                accessControllerAddr,
                coreMetadataModuleAddr,
                ipAssetRegistryAddr,
                licenseRegistryAddr,
                licensingModuleAddr,
                pilTemplateAddr
            )
        );
        console2.log("New LicenseAttachmentWorkflows Implementation: ", newLicenseAttachmentWorkflowsImpl);
        console2.log("LicenseAttachmentWorkflows deployed to: ", licenseAttachmentWorkflowsAddr);
        _writeAllAddresses();
    }
}
