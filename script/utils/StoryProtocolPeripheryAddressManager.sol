// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script, stdJson } from "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract StoryProtocolPeripheryAddressManager is Script {
    using stdJson for string;

    address internal spgAddr;
    address internal spgNftBeaconAddr;
    address internal spgNftImplAddr;

    function _readStoryProtocolPeripheryAddresses() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            string(abi.encodePacked("/deploy-out/deployment-", Strings.toString(block.chainid), ".json"))
        );
        string memory json = vm.readFile(path);
        spgAddr = json.readAddress(".main.SPG");
        spgNftBeaconAddr = json.readAddress(".main.SPGNFTBeacon");
        spgNftImplAddr = json.readAddress(".main.SPGNFTImpl");
    }
}
