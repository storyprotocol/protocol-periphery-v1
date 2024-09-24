// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";

// contracts
import { GroupingWorkflows } from "../../contracts/workflows/GroupingWorkflows.sol";

// script
import { UpgradeHelper } from "../utils/upgrades/UpgradeHelper.s.sol";

contract UpgradeGroupingWorkflows is UpgradeHelper {
    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/upgrade/UpgradeGroupingWorkflows.s.sol:UpgradeGroupingWorkflows \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public override {
        _beginBroadcast();
        _deployGroupingWorkflows();

        // Upgrade via multisig (can't do here).
        // groupingWorkflows.upgradeToAndCall(address(newGroupingWorkflowsImpl), "");

        _writeDeployment();
        _endBroadcast();
    }

    function _deployGroupingWorkflows() private {
        _writeAddress("DerivativeWorkflows", address(derivativeWorkflows));
        _predeploy("GroupingWorkflows");
        address newGroupingWorkflowsImpl = address(
            new GroupingWorkflows(
                accessControllerAddr,
                coreMetadataModuleAddr,
                groupingModuleAddr,
                groupNFTAddr,
                ipAssetRegistryAddr,
                licenseRegistryAddr,
                licensingModuleAddr,
                pilTemplateAddr
            )
        );
        console2.log("New GroupingWorkflows Implementation: ", newGroupingWorkflowsImpl);
        _postdeploy("GroupingWorkflows", address(groupingWorkflows));
        _writeAddress("LicenseAttachmentWorkflows", address(licenseAttachmentWorkflows));
        _writeAddress("RegistrationWorkflows", address(registrationWorkflows));
        _writeAddress("RoyaltyWorkflows", address(royaltyWorkflows));
        _writeAddress("SPGNFTBeacon", address(spgNftBeacon));
        _writeAddress("SPGNFTImpl", address(spgNftImpl));
    }
}
