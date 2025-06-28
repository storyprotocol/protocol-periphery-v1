// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ProtocolAdmin } from "@storyprotocol/core/lib/ProtocolAdmin.sol";
import { VaultController } from "@storyprotocol/core/modules/royalty/policies/VaultController.sol";
import { ProtocolPausableUpgradeable } from "@storyprotocol/core/pause/ProtocolPausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";

contract UpgradesTest is BaseTest {
    function test_deploymentSetup() public {
        // Target function role wiring

        (bool immediate, uint32 delay) = protocolAccessManager.canCall(
            deployer,
            address(derivativeWorkflows),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(derivativeWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(groupingWorkflows),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(groupingWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(licenseAttachmentWorkflows),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(licenseAttachmentWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(royaltyTokenDistributionWorkflows),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(royaltyTokenDistributionWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(royaltyWorkflows),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(royaltyWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(tokenizerModule),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(tokenizerModule),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(tokenizerModule),
            tokenizerModule.upgradeWhitelistedTokenTemplate.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(tokenizerModule),
                tokenizerModule.upgradeWhitelistedTokenTemplate.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(registrationWorkflows),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(registrationWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(registrationWorkflows),
            registrationWorkflows.upgradeCollections.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(registrationWorkflows),
                registrationWorkflows.upgradeCollections.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(moduleRegistry),
            moduleRegistry.removeModule.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(address(moduleRegistry), moduleRegistry.removeModule.selector),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(moduleRegistry),
            bytes4(keccak256("registerModule(string,address)"))
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(moduleRegistry),
                bytes4(keccak256("registerModule(string,address)"))
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(tokenizerModule),
            ProtocolPausableUpgradeable.pause.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(tokenizerModule),
                ProtocolPausableUpgradeable.pause.selector
            ),
            ProtocolAdmin.PAUSE_ADMIN_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            deployer,
            address(tokenizerModule),
            ProtocolPausableUpgradeable.unpause.selector
        );
        assertTrue(immediate);
        assertEq(delay, 0);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(tokenizerModule),
                ProtocolPausableUpgradeable.unpause.selector
            ),
            ProtocolAdmin.PAUSE_ADMIN_ROLE
        );
    }
}
