// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";

import { IStoryBadgeNFT } from "../../contracts/interfaces/story-nft/IStoryBadgeNFT.sol";
import { IStoryNFT } from "../../contracts/interfaces/story-nft/IStoryNFT.sol";
import { DeployHelper } from "../utils/DeployHelper.sol";

contract StoryNFT is DeployHelper {
    address internal CREATE3_DEPLOYER = 0x384a891dFDE8180b054f04D66379f16B7a678Ad6;
    uint256 private constant CREATE3_DEFAULT_SEED = 4987979255314221321141221123132325342;
    constructor() DeployHelper(CREATE3_DEPLOYER) {}

    function run() public override {
        create3SaltSeed = CREATE3_DEFAULT_SEED;
        writeDeploys = true;

        _readStoryProtocolCoreAddresses();
        (address defaultLicenseTemplate, uint256 defaultLicenseTermsId) =
            ILicenseRegistry(licenseRegistryAddr).getDefaultLicenseTerms();
        address storyNftFactorySigner = vm.envAddress("STORY_NFT_FACTORY_SIGNER");
        address rootOrgNftRecipient = vm.envAddress("ROOT_ORG_NFT_RECIPIENT");
        address rootStoryNftOwner = vm.envAddress("ROOT_STORY_NFT_OWNER");
        address rootStoryNftSigner = vm.envAddress("ROOT_STORY_NFT_SIGNER");
        string memory rootOrgName = "Test Root Org";
        string memory rootOrgTokenURI = string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(string(
                abi.encodePacked(
                    "{",
                    '"name": "Test Badge",',
                    '"description": "Test Badge",',
                    '"external_url": "https://www.story.foundation/",',
                    '"image": "https://storage.googleapis.com/opensea-prod.appspot.com/puffs/3.png"',
                    "}"
                )
            )))
        ));

        bytes memory rootStoryNftCustomInitParams = abi.encode(IStoryBadgeNFT.CustomInitParams({
            tokenURI: rootOrgTokenURI,
            signer: rootStoryNftSigner
        }));

        IStoryNFT.StoryNftInitParams memory rootStoryNftInitParams = IStoryNFT.StoryNftInitParams({
            owner: rootStoryNftOwner,
            name: "Test Org Badge",
            symbol: "TOB",
            contractURI: "Test Contract URI",
            baseURI: "",
            customInitData: rootStoryNftCustomInitParams
        });

        _deployAndConfigStoryNftContracts({
            licenseTemplate_: defaultLicenseTemplate,
            licenseTermsId_: defaultLicenseTermsId,
            storyNftFactorySigner: storyNftFactorySigner,
            rootOrgNftRecipient: rootOrgNftRecipient,
            rootOrgName: rootOrgName,
            rootOrgTokenURI: rootOrgTokenURI,
            rootStoryNftInitParams: rootStoryNftInitParams,
            isTest: false
        });

        _writeDeployment();
    }
}
