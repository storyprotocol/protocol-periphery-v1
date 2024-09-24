// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// contract
import { DerivativeWorkflows } from "../../../contracts/workflows/DerivativeWorkflows.sol";
import { GroupingWorkflows } from "../../../contracts/workflows/GroupingWorkflows.sol";
import { LicenseAttachmentWorkflows } from "../../../contracts/workflows/LicenseAttachmentWorkflows.sol";
import { RegistrationWorkflows } from "../../../contracts/workflows/RegistrationWorkflows.sol";
import { RoyaltyWorkflows } from "../../../contracts/workflows/RoyaltyWorkflows.sol";
import { SPGNFT } from "../../../contracts/SPGNFT.sol";

// script
import { BroadcastManager } from "../../utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "../../utils/JsonDeploymentHandler.s.sol";
import { StoryProtocolCoreAddressManager } from "../../utils/StoryProtocolCoreAddressManager.sol";
import { StoryProtocolPeripheryAddressManager } from "../../utils/StoryProtocolPeripheryAddressManager.sol";
import { StringUtil } from "../../utils/StringUtil.sol";

contract UpgradeHelper is
    Script,
    StoryProtocolCoreAddressManager,
    StoryProtocolPeripheryAddressManager,
    BroadcastManager,
    JsonDeploymentHandler
{
    using StringUtil for uint256;

    /// @dev workflow contracts
    DerivativeWorkflows internal derivativeWorkflows;
    GroupingWorkflows internal groupingWorkflows;
    LicenseAttachmentWorkflows internal licenseAttachmentWorkflows;
    RegistrationWorkflows internal registrationWorkflows;
    RoyaltyWorkflows internal royaltyWorkflows;

    /// @dev SPGNFT contracts
    SPGNFT internal spgNftImpl;
    UpgradeableBeacon internal spgNftBeacon;

    constructor() JsonDeploymentHandler("main") {}

    function run() public virtual {
        _readStoryProtocolCoreAddresses(); // StoryProtocolCoreAddressManager.s.sol
        _readStoryProtocolPeripheryAddresses(); // StoryProtocolPeripheryAddressManager.s.sol

        derivativeWorkflows = DerivativeWorkflows(derivativeWorkflowsAddr);
        groupingWorkflows = GroupingWorkflows(groupingWorkflowsAddr);
        licenseAttachmentWorkflows = LicenseAttachmentWorkflows(licenseAttachmentWorkflowsAddr);
        registrationWorkflows = RegistrationWorkflows(registrationWorkflowsAddr);
        royaltyWorkflows = RoyaltyWorkflows(royaltyWorkflowsAddr);

        spgNftImpl = SPGNFT(spgNftImplAddr);
        spgNftBeacon = UpgradeableBeacon(spgNftBeaconAddr);
    }

    function _predeploy(string memory contractKey) internal pure {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) internal {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }
}
