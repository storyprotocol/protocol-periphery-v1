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
    address internal ownableERC20BeaconAddr;
    address internal ownableERC20TemplateAddr;
    address internal tokenizerModuleAddr;
    address internal totalLicenseTokenLimitHookAddr;
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
        ownableERC20BeaconAddr = json.readAddress(".main.OwnableERC20Beacon");
        ownableERC20TemplateAddr = json.readAddress(".main.OwnableERC20Template");
        tokenizerModuleAddr = json.readAddress(".main.TokenizerModule");
        totalLicenseTokenLimitHookAddr = json.readAddress(".main.TotalLicenseTokenLimitHook");
    }
}
