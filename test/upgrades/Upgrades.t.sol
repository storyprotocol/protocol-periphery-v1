// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ProtocolAdmin } from "@storyprotocol/core/lib/ProtocolAdmin.sol";
import { VaultController } from "@storyprotocol/core/modules/royalty/policies/VaultController.sol";
import { ProtocolPausableUpgradeable } from "@storyprotocol/core/pause/ProtocolPausableUpgradeable.sol";
import { IModuleRegistry } from "@storyprotocol/core/interfaces/registries/IModuleRegistry.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";
import { IRegistrationWorkflows } from "../../contracts/interfaces/workflows/IRegistrationWorkflows.sol";
import { ITokenizerModule } from "../../contracts/interfaces/modules/tokenizer/ITokenizerModule.sol";

contract UpgradesTest is BaseTest {
    function test_deploymentSetup() public {
        IRegistrationWorkflows registrationWorkflows = IRegistrationWorkflows(address(registrationWorkflows));
        IModuleRegistry moduleRegistry = IModuleRegistry(address(moduleRegistry));
        ITokenizerModule tokenizerModule = ITokenizerModule(address(tokenizerModule));

        assertEq(ownableERC20Beacon.owner(), address(tokenizerModule));
        assertEq(spgNftBeacon.owner(), address(registrationWorkflows));
        assertTrue(tokenizerModule.isWhitelistedTokenTemplate(address(ownableERC20Template)));
        assertTrue(moduleRegistry.isRegistered(address(tokenizerModule)));
        assertTrue(moduleRegistry.isRegistered(address(lockLicenseHook)));
        assertTrue(moduleRegistry.isRegistered(address(totalLicenseTokenLimitHook)));
        // Target function role wiring
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(derivativeWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(groupingWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(licenseAttachmentWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(royaltyTokenDistributionWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(royaltyWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(tokenizerModule),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(tokenizerModule),
                tokenizerModule.upgradeWhitelistedTokenTemplate.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(registrationWorkflows),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(registrationWorkflows),
                registrationWorkflows.upgradeCollections.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(address(moduleRegistry), moduleRegistry.removeModule.selector),
            ProtocolAdmin.UPGRADER_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(moduleRegistry),
                bytes4(keccak256("registerModule(string,address)"))
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(tokenizerModule),
                ProtocolPausableUpgradeable.pause.selector
            ),
            ProtocolAdmin.PAUSE_ADMIN_ROLE
        );

        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(tokenizerModule),
                ProtocolPausableUpgradeable.unpause.selector
            ),
            ProtocolAdmin.PAUSE_ADMIN_ROLE
        );
    }
}
