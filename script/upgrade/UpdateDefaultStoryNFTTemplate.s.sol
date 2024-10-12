// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";

// contracts
import { StoryBadgeNFT } from "../../contracts/story-nft/StoryBadgeNFT.sol";
import { IStoryNFTFactory } from "../../contracts/interfaces/story-nft/IStoryNFTFactory.sol";

// script
import { UpgradeHelper } from "../utils/upgrades/UpgradeHelper.s.sol";

contract UpdateDefaultStoryNFTTemplate is UpgradeHelper {
    uint256 public constant LICENSE_TERMS_ID = 1;

    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/upgrade/UpdateDefaultStoryNFTTemplate.s.sol:UpdateDefaultStoryNFTTemplate \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public override {
        super.run();
        _beginBroadcast();
        _updateDefaultStoryNFTTemplate();
        _writeDeployment();
        _endBroadcast();
    }

    function _updateDefaultStoryNFTTemplate() private {
        _predeploy("DefaultStoryNftTemplate");
        StoryBadgeNFT newDefaultStoryNftTemplate = new StoryBadgeNFT(
            ipAssetRegistryAddr,
            licensingModuleAddr,
            orgNftAddr,
            pilTemplateAddr,
            LICENSE_TERMS_ID
        );
        IStoryNFTFactory(storyNftFactoryAddr).setDefaultStoryNftTemplate(address(newDefaultStoryNftTemplate));
        defaultStoryNftTemplateAddr = address(newDefaultStoryNftTemplate);
        console2.log("DefaultStoryNftTemplate deployed to: ", defaultStoryNftTemplateAddr);
        _writeAllAddresses();
    }
}
