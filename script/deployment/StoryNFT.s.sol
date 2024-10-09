// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";

import { DeployHelper } from "../utils/DeployHelper.sol";

contract StoryNFT is DeployHelper {
    address internal CREATE3_DEPLOYER = 0x384a891dFDE8180b054f04D66379f16B7a678Ad6;
    uint256 private constant CREATE3_DEFAULT_SEED = 1234567890;
    constructor() DeployHelper(CREATE3_DEPLOYER) {}

    function run() public override {
        create3SaltSeed = CREATE3_DEFAULT_SEED;
        writeDeploys = true;

        _readStoryProtocolCoreAddresses();
        (address defaultLicenseTemplate, uint256 defaultLicenseTermsId) =
            ILicenseRegistry(licenseRegistryAddr).getDefaultLicenseTerms();
        address storyNftFactorySigner = vm.envAddress("STORY_NFT_FACTORY_SIGNER");

        _deployAndConfigStoryNftContracts({
            licenseTemplate_: defaultLicenseTemplate,
            licenseTermsId_: defaultLicenseTermsId,
            storyNftFactorySigner: storyNftFactorySigner,
            isTest: false
        });

        _writeDeployment();
    }
}
