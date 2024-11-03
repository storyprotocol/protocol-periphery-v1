// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// contracts
import { StoryBadgeNFT } from "../../contracts/story-nft/StoryBadgeNFT.sol";
import { IOrgStoryNFTFactory } from "../../contracts/interfaces/story-nft/IOrgStoryNFTFactory.sol";

// script
import { UpgradeHelper } from "../utils/upgrades/UpgradeHelper.s.sol";

contract UpdateDefaultOrgStoryNFTTemplate is UpgradeHelper {
    uint256 public constant LICENSE_TERMS_ID = 1;

    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/upgrade/UpdateDefaultOrgStoryNFTTemplate.s.sol:UpdateDefaultOrgStoryNFTTemplate \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public override {
        super.run();
        _beginBroadcast();
        _updateDefaultOrgStoryNFTTemplate();
        _writeDeployment();
        _endBroadcast();
    }

    function _updateDefaultOrgStoryNFTTemplate() private {
        _predeploy("DefaultOrgStoryNFTTemplate");
        StoryBadgeNFT newDefaultOrgStoryNftTemplate = new StoryBadgeNFT(
            ipAssetRegistryAddr,
            licensingModuleAddr,
            defaultOrgStoryNftBeaconAddr,
            orgNftAddr,
            pilTemplateAddr,
            LICENSE_TERMS_ID
        );

        // Upgrade the beacon to the new template
        UpgradeableBeacon(defaultOrgStoryNftBeaconAddr).upgradeTo(address(newDefaultOrgStoryNftTemplate));

        // Set the new template as the default
        IOrgStoryNFTFactory(orgStoryNftFactoryAddr).setDefaultOrgStoryNftTemplate(address(newDefaultOrgStoryNftTemplate));
        defaultOrgStoryNftTemplateAddr = address(newDefaultOrgStoryNftTemplate);
        console2.log("DefaultOrgStoryNFTTemplate deployed to: ", defaultOrgStoryNftTemplateAddr);
        _writeAllAddresses();
    }
}
