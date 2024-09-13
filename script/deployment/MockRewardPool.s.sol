// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";

// script
import { BroadcastManager } from "../utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "../utils/JsonDeploymentHandler.s.sol";
import { StoryProtocolCoreAddressManager } from "../utils/StoryProtocolCoreAddressManager.sol";

// test
import { MockEvenSplitGroupPool } from "@storyprotocol/test/mocks/grouping/MockEvenSplitGroupPool.sol";

contract MockRewardPool is Script, BroadcastManager, JsonDeploymentHandler, StoryProtocolCoreAddressManager{
    using stdJson for string;

    constructor() JsonDeploymentHandler("main") {}

    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/deployment/MockRewardPool.s.sol:MockRewardPool --rpc-url=$TESTNET_URL \
    /// -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public {
        _beginBroadcast(); // BroadcastManager.s.sol
        _deployMockRewardPool();
        _endBroadcast(); // BroadcastManager.s.sol
    }

    function _deployMockRewardPool() private {
        _predeploy("MockEvenSplitGroupPool");
        MockEvenSplitGroupPool mockEvenSplitGroupPool = new MockEvenSplitGroupPool(royaltyModuleAddr);
        _postdeploy("MockEvenSplitGroupPool", address(mockEvenSplitGroupPool));
    }

    function _predeploy(string memory contractKey) private view {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }
}
