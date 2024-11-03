// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";

// contracts
import { OrgStoryNFTFactory } from "../../contracts/story-nft/OrgStoryNFTFactory.sol";

// script
import { UpgradeHelper } from "../utils/upgrades/UpgradeHelper.s.sol";

contract UpgradeStoryNFTFactory is UpgradeHelper {
    uint256 public constant LICENSE_TERMS_ID = 1;

    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/upgrade/UpgradeStoryNFTFactory.s.sol:UpgradeStoryNFTFactory \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public override {
        super.run();
        _beginBroadcast();
        _upgradeStoryNFTFactory();
        _writeDeployment();
        _endBroadcast();
    }

    function _upgradeStoryNFTFactory() private {
        _predeploy("OrgStoryNFTFactory");
        OrgStoryNFTFactory newOrgStoryNftFactory = new OrgStoryNFTFactory(
            ipAssetRegistryAddr,
            licensingModuleAddr,
            pilTemplateAddr,
            LICENSE_TERMS_ID,
            orgNftAddr
        );
        console2.log("New OrgStoryNFTFactory implementation: ", address(newOrgStoryNftFactory));
        console2.log("OrgStoryNFTFactory deployed to: ", orgStoryNftFactoryAddr);
        _writeAllAddresses();
    }
}
