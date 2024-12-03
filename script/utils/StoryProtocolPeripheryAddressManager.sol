// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script, stdJson } from "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract StoryProtocolPeripheryAddressManager is Script {
    using stdJson for string;

    address internal derivativeWorkflowsAddr;
    address internal groupingWorkflowsAddr;
    address internal licenseAttachmentWorkflowsAddr;
    address internal registrationWorkflowsAddr;
    address internal royaltyWorkflowsAddr;
    address internal royaltyTokenDistributionWorkflowsAddr;
    address internal spgNftBeaconAddr;
    address internal spgNftImplAddr;
    address internal defaultOrgStoryNftTemplateAddr;
    address internal defaultOrgStoryNftBeaconAddr;
    address internal orgNftAddr;
    address internal orgStoryNftFactoryAddr;

    function _readStoryProtocolPeripheryAddresses() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            string(abi.encodePacked("/deploy-out/deployment-", Strings.toString(block.chainid), ".json"))
        );
        string memory json = vm.readFile(path);
        derivativeWorkflowsAddr = json.readAddress(".main.DerivativeWorkflows");
        groupingWorkflowsAddr = json.readAddress(".main.GroupingWorkflows");
        licenseAttachmentWorkflowsAddr = json.readAddress(".main.LicenseAttachmentWorkflows");
        registrationWorkflowsAddr = json.readAddress(".main.RegistrationWorkflows");
        royaltyWorkflowsAddr = json.readAddress(".main.RoyaltyWorkflows");
        royaltyTokenDistributionWorkflowsAddr = json.readAddress(".main.RoyaltyTokenDistributionWorkflows");
        spgNftBeaconAddr = json.readAddress(".main.SPGNFTBeacon");
        spgNftImplAddr = json.readAddress(".main.SPGNFTImpl");
        defaultOrgStoryNftTemplateAddr = json.readAddress(".main.DefaultOrgStoryNFTTemplate");
        defaultOrgStoryNftBeaconAddr = json.readAddress(".main.DefaultOrgStoryNFTBeacon");
        orgNftAddr = json.readAddress(".main.OrgNFT");
        orgStoryNftFactoryAddr = json.readAddress(".main.OrgStoryNFTFactory");
    }
}
