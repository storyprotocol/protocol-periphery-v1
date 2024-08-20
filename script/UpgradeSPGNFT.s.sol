// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;
/* solhint-disable no-console */

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { StoryProtocolGateway } from "../contracts/StoryProtocolGateway.sol";
import { SPGNFT } from "../contracts/SPGNFT.sol";

import { StoryProtocolPeripheryAddressManager } from "./utils/StoryProtocolPeripheryAddressManager.sol";
import { StringUtil } from "./utils/StringUtil.sol";
import { BroadcastManager } from "./utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "./utils/JsonDeploymentHandler.s.sol";

contract UpgradeSPGNFT is Script, StoryProtocolPeripheryAddressManager, BroadcastManager, JsonDeploymentHandler {
    using StringUtil for uint256;

    StoryProtocolGateway private spg;
    SPGNFT private spgNftImpl;
    UpgradeableBeacon private spgNftBeacon;

    constructor() JsonDeploymentHandler("main") {}

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/UpgradeSPGNFT.s.sol:UpgradeSPGNFT --rpc-url $RPC_URL --broadcast --verify -vvvv
    function run() public {
        _readStoryProtocolPeripheryAddresses();

        spg = StoryProtocolGateway(spgAddr);
        spgNftImpl = SPGNFT(spgNftImplAddr);
        spgNftBeacon = UpgradeableBeacon(spgNftBeaconAddr);

        _beginBroadcast();
        _deploySPGNFT();

        // Upgrade the collections via multisig (can't do here).
        // spg.upgradeCollections(address(spgNftImpl));

        _writeDeployment();
        _endBroadcast();
    }

    function _deploySPGNFT() private {
        _writeAddress("SPG", address(spg));
        _writeAddress("SPGNFTBeacon", address(spgNftBeacon));

        _predeploy("SPGNFTImpl");
        spgNftImpl = new SPGNFT(address(spg));
        _postdeploy("SPGNFTImpl", address(spgNftImpl));
    }

    function _predeploy(string memory contractKey) private pure {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }
}
