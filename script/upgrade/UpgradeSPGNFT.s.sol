// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";

// contracts
import { SPGNFT } from "../../contracts/SPGNFT.sol";

// script
import { UpgradeHelper } from "../utils/upgrades/UpgradeHelper.s.sol";

contract UpgradeSPGNFT is UpgradeHelper {
    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/upgrade/UpgradeSPGNFT.s.sol:UpgradeSPGNFT \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public override {
        super.run();

        _beginBroadcast();
        _deploySPGNFT();

        // Upgrade the collections via multisig (can't do here).
        // registrationWorkflows.upgradeCollections(address(spgNftImpl));

        _writeDeployment();
        _endBroadcast();
    }

    function _deploySPGNFT() private {
        _writeAddress("DerivativeWorkflows", address(derivativeWorkflows));
        _writeAddress("GroupingWorkflows", address(groupingWorkflows));
        _writeAddress("LicenseAttachmentWorkflows", address(licenseAttachmentWorkflows));
        _writeAddress("RegistrationWorkflows", address(registrationWorkflows));
        _writeAddress("RoyaltyWorkflows", address(royaltyWorkflows));
        _writeAddress("SPGNFTBeacon", address(spgNftBeacon));
        _predeploy("SPGNFTImpl");
        spgNftImpl = new SPGNFT(
            address(derivativeWorkflows),
            address(groupingWorkflows),
            address(licenseAttachmentWorkflows),
            address(registrationWorkflows)
        );
        console2.log("New SPGNFT Implementation: ", address(spgNftImpl));
        _postdeploy("SPGNFTImpl", address(spgNftImpl));
    }
}
