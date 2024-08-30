// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;
/* solhint-disable no-console */

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { ICreate3Deployer } from "@create3-deployer/contracts/Create3Deployer.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { StoryProtocolGateway } from "../contracts/StoryProtocolGateway.sol";
import { SPGNFT } from "../contracts/SPGNFT.sol";

import { StoryProtocolCoreAddressManager } from "./utils/StoryProtocolCoreAddressManager.sol";
import { StringUtil } from "./utils/StringUtil.sol";
import { BroadcastManager } from "./utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "./utils/JsonDeploymentHandler.s.sol";

import { TestProxyHelper } from "../test/utils/TestProxyHelper.t.sol";

contract Main is Script, StoryProtocolCoreAddressManager, BroadcastManager, JsonDeploymentHandler {
    using StringUtil for uint256;

    ICreate3Deployer private constant create3Deployer = ICreate3Deployer(0x384a891dFDE8180b054f04D66379f16B7a678Ad6);
    uint256 private constant create3SaltSeed = 12;

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

        // Transfer ownership of beacon proxy to SPG
        spgNftBeacon.transferOwnership(address(spg));
        _endBroadcast();

        // Set beacon contract via multisig.
        // spg.setNftContractBeacon(address(spgNftBeacon));
    }

    function _deployProtocolContracts(address accessControlDeployer) private {
        address impl;

        _predeploy("SPG");
        impl = address(
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
        spg = StoryProtocolGateway(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(StoryProtocolGateway).name),
                impl,
                abi.encodeCall(StoryProtocolGateway.initialize, address(protocolAccessManagerAddr))
            )
        );
        impl = address(0);
        _postdeploy("SPG", address(spg));

        _predeploy("SPGNFTImpl");
        spgNftImpl = SPGNFT(
            create3Deployer.deploy(
                _getSalt(type(SPGNFT).name),
                abi.encodePacked(type(SPGNFT).creationCode, abi.encode(address(spg)))
            )
        );
        _postdeploy("SPGNFTImpl", address(spgNftImpl));

        _predeploy("SPGNFTBeacon");
        spgNftBeacon = UpgradeableBeacon(
            create3Deployer.deploy(
                _getSalt(type(UpgradeableBeacon).name),
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(address(spgNftImpl), deployer))
            )
        );
        _postdeploy("SPGNFTBeacon", address(spgNftBeacon));
    }

    function _predeploy(string memory contractKey) private pure {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }

    function _getSalt(string memory name) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encode(name, create3SaltSeed));
    }
}
