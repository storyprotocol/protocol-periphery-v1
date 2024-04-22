// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";

import { StoryProtocolGateway } from "../../contracts/StoryProtocolGateway.sol";
import { SPGNFT } from "../../contracts/SPGNFT.sol";
import { StoryProtocolCoreAddressManager } from "../../script/utils/StoryProtocolCoreAddressManager.sol";
import { TestProxyHelper } from "./TestProxyHelper.t.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

/// @title Base Test Contract
contract BaseTest is Test, StoryProtocolCoreAddressManager {
    StoryProtocolGateway internal spg;
    SPGNFT internal spgNftImpl;
    UpgradeableBeacon internal spgNftBeacon;

    MockERC20 internal mockToken;

    address payable internal deployer = payable(vm.addr(0xddd111));
    address payable internal alice = payable(vm.addr(0xa11ce));
    address payable internal bob = payable(vm.addr(0xb0b));
    address payable internal cal = payable(vm.addr(0xca1));

    /// @notice Sets up the base test contract.
    function setUp() public virtual {
        _readStoryProtocolCoreAddresses();

        spgNftImpl = new SPGNFT();

        spgNftBeacon = new UpgradeableBeacon(address(spgNftImpl), deployer);

        address impl = address(
            new StoryProtocolGateway(
                accessControllerAddr,
                ipAssetRegistryAddr,
                licensingModuleAddr,
                coreMetadataModuleAddr,
                pilTemplateAddr
            )
        );
        spg = StoryProtocolGateway(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(StoryProtocolGateway.initialize, (address(protocolAccessManagerAddr)))
            )
        );

        vm.prank(deployer);
        spg.setNftContractBeacon(address(spgNftBeacon));

        // bytes4[] memory selectors = new bytes4[](1);
        // selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;
        // protocolAccessManager.setTargetFunctionRole(address(spg), selectors, ProtocolAdmin.UPGRADER_ROLE);
        // protocolAccessManager.setTargetFunctionRole(address(spgNftBeacon), selectors, ProtocolAdmin.UPGRADER_ROLE);

        mockToken = new MockERC20();

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(cal, "Cal");

        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.deal(cal, 1000 ether);
    }
}
