// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";

// contracts
import { RegistrationWorkflows } from "../../contracts/workflows/RegistrationWorkflows.sol";

// script
import { UpgradeHelper } from "../utils/upgrades/UpgradeHelper.s.sol";

contract UpgradeRegistrationWorkflows is UpgradeHelper {
    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/upgrade/UpgradeRegistrationWorkflows.s.sol:UpgradeRegistrationWorkflows \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public override {
        _beginBroadcast();
        _deployRegistrationWorkflows();

        // Upgrade via multisig (can't do here).
        // registrationWorkflows.upgradeToAndCall(address(newRegistrationWorkflowsImpl), "");

        _writeDeployment();
        _endBroadcast();
    }

    function _deployRegistrationWorkflows() private {
        _writeAddress("DerivativeWorkflows", address(derivativeWorkflows));
        _writeAddress("GroupingWorkflows", address(groupingWorkflows));
        _writeAddress("LicenseAttachmentWorkflows", address(licenseAttachmentWorkflows));
        _predeploy("RegistrationWorkflows");
        address newRegistrationWorkflowsImpl = address(
            new RegistrationWorkflows(
                accessControllerAddr,
                coreMetadataModuleAddr,
                ipAssetRegistryAddr,
                licenseRegistryAddr,
                licensingModuleAddr,
                pilTemplateAddr
            )
        );
        console2.log("New RegistrationWorkflows Implementation: ", newRegistrationWorkflowsImpl);
        _postdeploy("RegistrationWorkflows", address(registrationWorkflows));
        _writeAddress("RoyaltyWorkflows", address(royaltyWorkflows));
        _writeAddress("SPGNFTBeacon", address(spgNftBeacon));
        _writeAddress("SPGNFTImpl", address(spgNftImpl));
    }
}
