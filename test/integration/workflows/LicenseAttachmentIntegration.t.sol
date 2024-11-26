// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

contract LicenseAttachmentIntegration is BaseIntegration {
    using Strings for uint256;

    ISPGNFT private spgNftContract;
    PILTerms[] private commTerms;
    address[] private licenseTemplates;
    uint256[] private commTermsId;

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/LicenseAttachmentIntegration.t.sol:LicenseAttachmentIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();
        _setUpTest();
        _test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachPILTerms();
        _test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachLicenseTerms();
        _test_LicenseAttachmentIntegration_registerIpAndAttachLicenseTerms();
        _endBroadcast();
    }

    function _test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachPILTerms()
        private
        logTest("test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachPILTerms")
    {
        // IP 1
        {
            StoryUSD.mint(testSender, testMintFee);
            StoryUSD.approve(address(spgNftContract), testMintFee);

            (address ipId1, uint256 tokenId1, uint256[] memory licenseTermsIds1) = licenseAttachmentWorkflows
                .mintAndRegisterIpAndAttachPILTerms({
                    spgNftContract: address(spgNftContract),
                    recipient: testSender,
                    ipMetadata: testIpMetadata,
                    terms: commTerms,
                    allowDuplicates: true
                });
            assertTrue(ipAssetRegistry.isRegistered(ipId1));
            assertEq(tokenId1, spgNftContract.totalSupply());
            assertEq(spgNftContract.tokenURI(tokenId1), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId1, testIpMetadata);
            for (uint256 i = 0; i < licenseTermsIds1.length; i++) {
                assertEq(licenseTermsIds1[i], commTermsId[i]);
                (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, i);
                assertEq(licenseTemplate, pilTemplateAddr);
                assertEq(licenseTermsId, licenseTermsIds1[i]);
            }
        }

        // IP 2
        {
            StoryUSD.mint(testSender, testMintFee);
            StoryUSD.approve(address(spgNftContract), testMintFee);

            (address ipId2, uint256 tokenId2, uint256[] memory licenseTermsIds2) = licenseAttachmentWorkflows
                .mintAndRegisterIpAndAttachPILTerms({
                    spgNftContract: address(spgNftContract),
                    recipient: testSender,
                    ipMetadata: testIpMetadata,
                    terms: commTerms,
                    allowDuplicates: true
                });
            assertTrue(ipAssetRegistry.isRegistered(ipId2));
            assertEq(tokenId2, spgNftContract.totalSupply());
            assertEq(spgNftContract.tokenURI(tokenId2), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId2, testIpMetadata);
            for (uint256 i = 0; i < licenseTermsIds2.length; i++) {
                assertEq(licenseTermsIds2[i], commTermsId[i]);
                (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, i);
                assertEq(licenseTemplate, pilTemplateAddr);
                assertEq(licenseTermsId, licenseTermsIds2[i]);
            }
        }
    }

    function _test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachLicenseTerms()
        private
        logTest("test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachLicenseTerms")
    {
        // IP 1
        {
            StoryUSD.mint(testSender, testMintFee);
            StoryUSD.approve(address(spgNftContract), testMintFee);

            (address ipId1, uint256 tokenId1) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachLicenseTerms({
                spgNftContract: address(spgNftContract),
                recipient: testSender,
                ipMetadata: testIpMetadata,
                licenseTemplates: licenseTemplates,
                licenseTermsIds: commTermsId,
                allowDuplicates: true
            });
            assertTrue(ipAssetRegistry.isRegistered(ipId1));
            assertEq(tokenId1, spgNftContract.totalSupply());
            assertEq(spgNftContract.tokenURI(tokenId1), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId1, testIpMetadata);
            for (uint256 i = 0; i < commTermsId.length; i++) {
                (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, i);
                assertEq(licenseTemplate, licenseTemplates[i]);
                assertEq(licenseTermsId, commTermsId[i]);
            }
        }

        // IP 2
        {
            StoryUSD.mint(testSender, testMintFee);
            StoryUSD.approve(address(spgNftContract), testMintFee);

            (address ipId2, uint256 tokenId2) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachLicenseTerms({
                spgNftContract: address(spgNftContract),
                recipient: testSender,
                ipMetadata: testIpMetadata,
                licenseTemplates: licenseTemplates,
                licenseTermsIds: commTermsId,
                allowDuplicates: true
            });
            assertTrue(ipAssetRegistry.isRegistered(ipId2));
            assertEq(tokenId2, spgNftContract.totalSupply());
            assertEq(spgNftContract.tokenURI(tokenId2), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId2, testIpMetadata);
            for (uint256 i = 0; i < commTermsId.length; i++) {
                (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, i);
                assertEq(licenseTemplate, licenseTemplates[i]);
                assertEq(licenseTermsId, commTermsId[i]);
            }
        }
    }

    function _test_LicenseAttachmentIntegration_registerIpAndAttachLicenseTerms()
        private
        logTest("test_LicenseAttachmentIntegration_registerIpAndAttachLicenseTerms")
    {
        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);

        uint256 tokenId = spgNftContract.mint({
            to: testSender,
            nftMetadataURI: "",
            nftMetadataHash: bytes32(0),
            allowDuplicates: true
        });
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadata, bytes32 sigAttachState) = _getSigForExecuteWithSig({
            ipId: expectedIpId,
            to: coreMetadataModuleAddr,
            deadline: deadline,
            state: bytes32(0),
            data: abi.encodeWithSelector(
                ICoreMetadataModule.setAll.selector,
                expectedIpId,
                testIpMetadata.ipMetadataURI,
                testIpMetadata.ipMetadataHash,
                testIpMetadata.nftMetadataHash
            ),
            signerSk: testSenderSk
        });

        bytes[] memory sigsAttach = new bytes[](commTermsId.length);
        bytes32 expectedState = sigAttachState;
        for (uint256 i = 0; i < commTermsId.length; i++) {
            (sigsAttach[i], expectedState) = _getSigForExecuteWithSig({
                ipId: expectedIpId,
                to: licensingModuleAddr,
                deadline: deadline,
                state: expectedState,
                data: abi.encodeWithSelector(
                    ILicensingModule.attachLicenseTerms.selector,
                    expectedIpId,
                    licenseTemplates[i],
                    commTermsId[i]
                ),
                signerSk: testSenderSk
            });
        }

        WorkflowStructs.SignatureData[] memory sigsAttachData = new WorkflowStructs.SignatureData[](commTermsId.length);
        for (uint256 i = 0; i < commTermsId.length; i++) {
            sigsAttachData[i] = WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigsAttach[i]
            });
        }

        address ipId = licenseAttachmentWorkflows.registerIpAndAttachLicenseTerms({
            nftContract: address(spgNftContract),
            tokenId: tokenId,
            ipMetadata: testIpMetadata,
            licenseTemplates: licenseTemplates,
            licenseTermsIds: commTermsId,
            sigMetadata: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadata
            }),
            sigsAttach: sigsAttachData
        });

        assertEq(ipId, expectedIpId);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(IIPAccount(payable(ipId)).state(), expectedState);
        address expectedLicenseTemplate;
        uint256 expectedLicenseTermsId;
        for (uint256 i = 0; i < commTermsId.length; i++) {
            (expectedLicenseTemplate, expectedLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(
                expectedIpId,
                i
            );
            assertEq(expectedLicenseTemplate, licenseTemplates[i]);
            assertEq(expectedLicenseTermsId, commTermsId[i]);
        }
    }

    function _setUpTest() private {
        spgNftContract = ISPGNFT(
            registrationWorkflows.createCollection(
                ISPGNFT.InitParams({
                    name: testCollectionName,
                    symbol: testCollectionSymbol,
                    baseURI: testBaseURI,
                    contractURI: testContractURI,
                    maxSupply: testMaxSupply,
                    mintFee: testMintFee,
                    mintFeeToken: testMintFeeToken,
                    mintFeeRecipient: testSender,
                    owner: testSender,
                    mintOpen: true,
                    isPublicMinting: true
                })
            )
        );

        commTerms.push(
            PILFlavors.commercialRemix({
                mintingFee: testMintFee,
                commercialRevShare: 10 * 10 ** 6, // 10%
                royaltyPolicy: royaltyPolicyLRPAddr,
                currencyToken: testMintFeeToken
            })
        );
        commTerms.push(
            PILFlavors.commercialUse({
                mintingFee: testMintFee,
                currencyToken: testMintFeeToken,
                royaltyPolicy: royaltyPolicyLRPAddr
            })
        );

        licenseTemplates.push(pilTemplateAddr);
        licenseTemplates.push(pilTemplateAddr);

        commTermsId.push(pilTemplate.registerLicenseTerms(commTerms[0]));
        commTermsId.push(pilTemplate.registerLicenseTerms(commTerms[1]));
    }
}
