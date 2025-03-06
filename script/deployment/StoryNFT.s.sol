// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";

import { DeployHelper } from "../utils/DeployHelper.sol";

contract StoryNFT is DeployHelper {
    address internal CREATE3_DEPLOYER = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
    uint256 private constant CREATE3_DEFAULT_SEED = 1234567890;
    constructor() DeployHelper(CREATE3_DEPLOYER) {}

    function run() public {
        create3SaltSeed = CREATE3_DEFAULT_SEED;
        writeDeploys = true;

        _readStoryProtocolCoreAddresses();
        (address defaultLicenseTemplate, uint256 defaultLicenseTermsId) =
            ILicenseRegistry(licenseRegistryAddr).getDefaultLicenseTerms();
        address orgStoryNftFactorySigner = vm.envAddress("ORG_STORY_NFT_FACTORY_SIGNER");

        _deployAndConfigStoryNftContracts({
            licenseTemplate_: defaultLicenseTemplate,
            licenseTermsId_: defaultLicenseTermsId,
            orgStoryNftFactorySigner: orgStoryNftFactorySigner,
            isTest: false
        });

        _writeDeployment();
    }
}
