// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script, stdJson } from "forge-std/Script.sol";

contract StoryProtocolCoreAddressManager is Script {
    using stdJson for string;

    address internal protocolAccessManagerAddr;
    address internal ipAssetRegistryAddr;
    address internal licensingModuleAddr;
    address internal coreMetadataModuleAddr;
    address internal accessControllerAddr;
    address internal pilTemplateAddr;

    function _readStoryProtocolCoreAddresses() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            "/node_modules/@story-protocol/protocol-core/deploy-out/deployment-11155111.json"
        );
        string memory json = vm.readFile(path);
        protocolAccessManagerAddr = json.readAddress(".main.ProtocolAccessManager");
        ipAssetRegistryAddr = json.readAddress(".main.IPAssetRegistry");
        licensingModuleAddr = json.readAddress(".main.LicensingModule");
        coreMetadataModuleAddr = json.readAddress(".main.CoreMetadataModule");
        accessControllerAddr = json.readAddress(".main.AccessController");
        pilTemplateAddr = json.readAddress(".main.PILicenseTemplate");
    }
}
