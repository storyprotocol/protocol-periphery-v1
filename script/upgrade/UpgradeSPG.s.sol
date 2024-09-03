// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
/* solhint-disable no-console */

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { StoryProtocolGateway } from "../../contracts/StoryProtocolGateway.sol";
import { GroupingWorkflows } from "../../contracts/GroupingWorkflows.sol";
import { SPGNFT } from "../../contracts/SPGNFT.sol";

import { StoryProtocolCoreAddressManager } from "../utils/StoryProtocolCoreAddressManager.sol";
import { StoryProtocolPeripheryAddressManager } from "../utils/StoryProtocolPeripheryAddressManager.sol";
import { StringUtil } from "../utils/StringUtil.sol";
import { BroadcastManager } from "../utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "../utils/JsonDeploymentHandler.s.sol";

contract UpgradeSPG is
    Script,
    StoryProtocolCoreAddressManager,
    StoryProtocolPeripheryAddressManager,
    BroadcastManager,
    JsonDeploymentHandler
{
    using StringUtil for uint256;

    StoryProtocolGateway private spg;
    GroupingWorkflows private groupingWorkflows;
    SPGNFT private spgNftImpl;
    UpgradeableBeacon private spgNftBeacon;

    constructor() JsonDeploymentHandler("main") {}

    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/upgrade/UpgradeSPG.s.sol:UpgradeSPG \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public {
        _readStoryProtocolCoreAddresses();
        _readStoryProtocolPeripheryAddresses();

        spg = StoryProtocolGateway(spgAddr);
        groupingWorkflows = GroupingWorkflows(groupingWorkflowsAddr);
        spgNftImpl = SPGNFT(spgNftImplAddr);
        spgNftBeacon = UpgradeableBeacon(spgNftBeaconAddr);

        _beginBroadcast();
        _deploySPG();

        _writeDeployment();
        _endBroadcast();
    }

    function _deploySPG() private {
        _predeploy("SPG");
        address newSpgImpl = address(
            new StoryProtocolGateway(
                accessControllerAddr,
                ipAssetRegistryAddr,
                licensingModuleAddr,
                licenseRegistryAddr,
                royaltyModuleAddr,
                coreMetadataModuleAddr,
                pilTemplateAddr,
                licenseTokenAddr
            )
        );
        console2.log("New SPG Implementation", newSpgImpl);

        // Upgrade via multisig (can't do here).
        // spg.upgradeToAndCall(address(newSpgImpl), "");

        _postdeploy("SPG", address(spg));
        _writeAddress("GroupingWorkflows", address(groupingWorkflows));
        _writeAddress("SPGNFTBeacon", address(spgNftBeacon));
        _writeAddress("SPGNFTImpl", address(spgNftImpl));
    }

    function _predeploy(string memory contractKey) private pure {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }
}
