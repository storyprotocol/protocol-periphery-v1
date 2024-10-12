// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";

// contracts
import { OrgNFT } from "../../contracts/story-nft/OrgNFT.sol";

// script
import { UpgradeHelper } from "../utils/upgrades/UpgradeHelper.s.sol";

contract UpgradeOrgNFT is UpgradeHelper {
    uint256 public constant LICENSE_TERMS_ID = 1;

    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/upgrade/UpgradeOrgNFT.s.sol:UpgradeOrgNFT \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public override {
        super.run();
        _beginBroadcast();
        _upgradeOrgNFT();
        _writeDeployment();
        _endBroadcast();
    }

    function _upgradeOrgNFT() private {
        _predeploy("OrgNFT");
        OrgNFT newOrgNft = new OrgNFT(
            ipAssetRegistryAddr,
            licensingModuleAddr,
            storyNftFactoryAddr,
            pilTemplateAddr,
            LICENSE_TERMS_ID
        );
        console2.log("New OrgNFT implementation: ", address(newOrgNft));
        console2.log("OrgNFT deployed to: ", orgNftAddr);
        _writeAllAddresses();
    }
}
