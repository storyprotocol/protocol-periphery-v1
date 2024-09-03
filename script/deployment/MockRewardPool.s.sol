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
// test
import { MockEvenSplitGroupPool } from "test/mocks/MockEvenSplitGroupPool.sol";

contract MockRewardPool is Script, BroadcastManager, JsonDeploymentHandler {
    using stdJson for string;

    constructor() JsonDeploymentHandler("main") {}

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/deployment/MockRewardPool.s.sol:MockRewardPool --rpc-url $RPC_URL --broadcast --verify -vvvv

    function run() public {
        _beginBroadcast(); // BroadcastManager.s.sol
        _deployMockRewardPool();
        _endBroadcast(); // BroadcastManager.s.sol
    }

    function _deployMockRewardPool() private {
        _predeploy("MockEvenSplitGroupPool");
        MockEvenSplitGroupPool mockEvenSplitGroupPool = new MockEvenSplitGroupPool();
        _postdeploy("MockEvenSplitGroupPool", address(mockEvenSplitGroupPool));
    }

    function _predeploy(string memory contractKey) private view {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }
}
