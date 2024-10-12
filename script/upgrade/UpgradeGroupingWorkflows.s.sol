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
        super.run();
        _beginBroadcast();
        _deployGroupingWorkflows();

        // Upgrade via multisig (can't do here).
        // groupingWorkflows.upgradeToAndCall(address(newGroupingWorkflowsImpl), "");

        _writeDeployment();
        _endBroadcast();
    }

    function _deployGroupingWorkflows() private {
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
        console2.log("GroupingWorkflows deployed to: ", groupingWorkflowsAddr);
        _writeAllAddresses();
    }
}
