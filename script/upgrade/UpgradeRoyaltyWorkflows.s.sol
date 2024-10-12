// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";

// contracts
import { RoyaltyWorkflows } from "../../contracts/workflows/RoyaltyWorkflows.sol";

// script
import { UpgradeHelper } from "../utils/upgrades/UpgradeHelper.s.sol";

contract UpgradeRoyaltyWorkflows is UpgradeHelper {
    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/upgrade/UpgradeRoyaltyWorkflows.s.sol:UpgradeRoyaltyWorkflows \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public override {
        super.run();
        _beginBroadcast();
        _deployRoyaltyWorkflows();

        // Upgrade via multisig (can't do here).
        // royaltyWorkflows.upgradeToAndCall(address(newRoyaltyWorkflowsImpl), "");

        _writeDeployment();
        _endBroadcast();
    }

    function _deployRoyaltyWorkflows() private {
        _predeploy("RoyaltyWorkflows");
        address newRoyaltyWorkflowsImpl = address(new RoyaltyWorkflows(royaltyModuleAddr));
        console2.log("New RoyaltyWorkflows Implementation: ", newRoyaltyWorkflowsImpl);
        console2.log("RoyaltyWorkflows deployed to: ", royaltyWorkflowsAddr);
        _writeAllAddresses();
    }
}
