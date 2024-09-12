// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";

// contracts
import { DerivativeWorkflows } from "../../contracts/workflows/DerivativeWorkflows.sol";

// script
import { UpgradeHelper } from "../utils/upgrades/UpgradeHelper.s.sol";

contract UpgradeDerivativeWorkflows is UpgradeHelper {
    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/upgrade/UpgradeDerivativeWorkflows.s.sol:UpgradeDerivativeWorkflows \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public override {
        _beginBroadcast();
        _deployDerivativeWorkflows();

        // Upgrade via multisig (can't do here).
        // derivativeWorkflows.upgradeToAndCall(address(newDerivativeWorkflowsImpl), "");

        _writeDeployment();
        _endBroadcast();
    }

    function _deployDerivativeWorkflows() private {
        _predeploy("DerivativeWorkflows");
        address newDerivativeWorkflowsImpl = address(
            new DerivativeWorkflows(
                accessControllerAddr,
                coreMetadataModuleAddr,
                ipAssetRegistryAddr,
                licenseRegistryAddr,
                licenseTokenAddr,
                licensingModuleAddr,
                pilTemplateAddr,
                royaltyModuleAddr
            )
        );
        console2.log("New DerivativeWorkflows Implementation: ", newDerivativeWorkflowsImpl);
        _postdeploy("DerivativeWorkflows", address(derivativeWorkflows));
        _writeAddress("LicenseAttachmentWorkflows", address(licenseAttachmentWorkflows));
        _writeAddress("RegistrationWorkflows", address(registrationWorkflows));
        _writeAddress("SPGNFTBeacon", address(spgNftBeacon));
        _writeAddress("SPGNFTImpl", address(spgNftImpl));
    }
}