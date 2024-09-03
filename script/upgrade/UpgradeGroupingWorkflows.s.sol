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

contract UpgradeGroupingWorkflows is
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
    /// forge script script/upgrade/UpgradeGroupingWorkflows.s.sol:UpgradeGroupingWorkflows \
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
        _deployGroupingWorkflows();

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
                licensingModuleAddr,
                licenseRegistryAddr,
                pilTemplateAddr
            )
        );
        console2.log("New GroupingWorkflows Implementation", newGroupingWorkflowsImpl);

        // Upgrade via multisig (can't do here).
        // groupingWorkflows.upgradeToAndCall(address(newGroupingWorkflowsImpl), "");

        _postdeploy("GroupingWorkflows", address(groupingWorkflows));
        _writeAddress("SPG", address(spg));
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
