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

    function _writeAllAddresses() internal {
        string[] memory contractKeys = new string[](10);
        contractKeys[0] = "DerivativeWorkflows";
        contractKeys[1] = "GroupingWorkflows";
        contractKeys[2] = "LicenseAttachmentWorkflows";
        contractKeys[3] = "RegistrationWorkflows";
        contractKeys[4] = "RoyaltyWorkflows";
        contractKeys[5] = "SPGNFTBeacon";
        contractKeys[6] = "SPGNFTImpl";
        contractKeys[7] = "DefaultStoryNftTemplate";
        contractKeys[8] = "OrgNFT";
        contractKeys[9] = "StoryNFTFactory";

        address[] memory addresses = new address[](10);
        addresses[0] = derivativeWorkflowsAddr;
        addresses[1] = groupingWorkflowsAddr;
        addresses[2] = licenseAttachmentWorkflowsAddr;
        addresses[3] = registrationWorkflowsAddr;
        addresses[4] = royaltyWorkflowsAddr;
        addresses[5] = spgNftBeaconAddr;
        addresses[6] = spgNftImplAddr;
        addresses[7] = defaultStoryNftTemplateAddr;
        addresses[8] = orgNftAddr;
        addresses[9] = storyNftFactoryAddr;

        for (uint256 i = 0; i < contractKeys.length; i++) {
            _writeAddress(contractKeys[i], addresses[i]);
        }
    }
}
