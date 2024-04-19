// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;
/* solhint-disable no-console */

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";

import { StoryProtocolGateway } from "../contracts/StoryProtocolGateway.sol";
import { SPGNFT } from "../contracts/SPGNFT.sol";

import { StoryProtocolCoreAddressManager } from "./utils/StoryProtocolCoreAddressManager.sol";
import { StringUtil } from "./utils/StringUtil.sol";
import { BroadcastManager } from "./utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "./utils/JsonDeploymentHandler.s.sol";

import { TestProxyHelper } from "../test/utils/TestProxyHelper.t.sol";

contract Main is Script, StoryProtocolCoreAddressManager, BroadcastManager, JsonDeploymentHandler {
    using StringUtil for uint256;

    StoryProtocolGateway private spg;
    SPGNFT private spgNftImpl;
    UpgradeableBeacon private spgNftBeacon;

    constructor() JsonDeploymentHandler("main") {}

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv
    function run() public {
        _readStoryProtocolCoreAddresses();
        _beginBroadcast();
        _deployProtocolContracts(deployer);
        _writeDeployment();
        _endBroadcast();
    }

    function _deployProtocolContracts(address accessControlDeployer) private {
        string memory contractKey;
        address impl;

        _predeploy("SPGNFTImpl");
        spgNftImpl = new SPGNFT();
        _postdeploy("SPGNFTImpl", address(spgNftImpl));

        _predeploy("SPGNFTBeacon");
        // Transfer Ownership to RoyaltyPolicyLAP later
        spgNftBeacon = new UpgradeableBeacon(address(spgNftImpl), deployer);
        _postdeploy("SPGNFTBeacon", address(spgNftBeacon));

        _predeploy("SPG");
        impl = address(
            new StoryProtocolGateway(
                accessControllerAddr,
                ipAssetRegistryAddr,
                licensingModuleAddr,
                coreMetadataModuleAddr,
                pilTemplateAddr,
                address(spgNftBeacon)
            )
        );
        spg = StoryProtocolGateway(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(StoryProtocolGateway.initialize, (address(protocolAccessManagerAddr)))
            )
        );
        impl = address(0);
        _postdeploy("SPG", address(spg));
    }

    function _predeploy(string memory contractKey) private view {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }
}
