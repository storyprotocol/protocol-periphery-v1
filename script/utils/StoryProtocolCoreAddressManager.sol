// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script, stdJson } from "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract StoryProtocolCoreAddressManager is Script {
    using stdJson for string;

    address internal protocolAccessManagerAddr;
    address internal ipAssetRegistryAddr;
    address internal licensingModuleAddr;
    address internal coreMetadataModuleAddr;
    address internal accessControllerAddr;
    address internal pilTemplateAddr;
    address internal licenseTokenAddr;

    function _readStoryProtocolCoreAddresses() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            string(
                abi.encodePacked(
                    "/node_modules/@story-protocol/protocol-core/deploy-out/deployment-",
                    Strings.toString(block.chainid),
                    ".json"
                )
            )
        );
        string memory json = vm.readFile(path);
        protocolAccessManagerAddr = json.readAddress(".main.ProtocolAccessManager");
        ipAssetRegistryAddr = json.readAddress(".main.IPAssetRegistry");
        licensingModuleAddr = json.readAddress(".main.LicensingModule");
        coreMetadataModuleAddr = json.readAddress(".main.CoreMetadataModule");
        accessControllerAddr = json.readAddress(".main.AccessController");
        pilTemplateAddr = json.readAddress(".main.PILicenseTemplate");
        licenseTokenAddr = json.readAddress(".main.LicenseToken");
    }
}
