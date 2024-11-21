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

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/LicenseAttachmentIntegration.t.sol:LicenseAttachmentIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();
        _setUpTest();
        _test_LicenseAttachmentIntegration_registerPILTermsAndAttach();
        _test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachPILTerms();
        _test_LicenseAttachmentIntegration_registerIpAndAttachPILTerms();
        _endBroadcast();
    }

    function _test_LicenseAttachmentIntegration_registerPILTermsAndAttach()
        private
        logTest("test_LicenseAttachmentIntegration_registerPILTermsAndAttach")
    {
        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);

        (address ipId, ) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftContract),
            recipient: testSender,
            ipMetadata: testIpMetadata
        });

        uint256 deadline = block.timestamp + 1000;
        (bytes memory signature, , ) = _getSetPermissionSigForPeriphery({
            ipId: ipId,
            to: licenseAttachmentWorkflowsAddr,
            module: licensingModuleAddr,
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(payable(ipId)).state(),
            signerSk: testSenderSk
        });

        uint256[] memory licenseTermsIds = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            terms: commTerms,
            sigAttach: WorkflowStructs.SignatureData({ signer: testSender, deadline: deadline, signature: signature })
        });

        assertEq(licenseTermsIds[0], pilTemplate.getLicenseTermsId(commTerms[0]));
        assertEq(licenseTermsIds[1], pilTemplate.getLicenseTermsId(commTerms[1]));
        assertEq(licenseTermsIds[2], pilTemplate.getLicenseTermsId(commTerms[2]));
        assertEq(licenseTermsIds[3], pilTemplate.getLicenseTermsId(commTerms[3]));
        assertEq(licenseTermsIds[4], pilTemplate.getLicenseTermsId(commTerms[4]));
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
                    terms: commTerms
                });
            assertTrue(ipAssetRegistry.isRegistered(ipId1));
            assertEq(tokenId1, spgNftContract.totalSupply());
            assertEq(licenseTermsIds1[0], pilTemplate.getLicenseTermsId(commTerms[0]));
            assertEq(licenseTermsIds1[1], pilTemplate.getLicenseTermsId(commTerms[1]));
            assertEq(licenseTermsIds1[2], pilTemplate.getLicenseTermsId(commTerms[2]));
            assertEq(licenseTermsIds1[3], pilTemplate.getLicenseTermsId(commTerms[3]));
            assertEq(licenseTermsIds1[4], pilTemplate.getLicenseTermsId(commTerms[4]));
            assertEq(spgNftContract.tokenURI(tokenId1), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId1, testIpMetadata);
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsIds1[0]);
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 1);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsIds1[1]);
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 2);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsIds1[2]);
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 3);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsIds1[3]);
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 4);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsIds1[4]);
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
                    terms: commTerms
                });
            assertTrue(ipAssetRegistry.isRegistered(ipId2));
            assertEq(tokenId2, spgNftContract.totalSupply());
            assertEq(licenseTermsIds2[0], pilTemplate.getLicenseTermsId(commTerms[0]));
            assertEq(licenseTermsIds2[1], pilTemplate.getLicenseTermsId(commTerms[1]));
            assertEq(licenseTermsIds2[2], pilTemplate.getLicenseTermsId(commTerms[2]));
            assertEq(licenseTermsIds2[3], pilTemplate.getLicenseTermsId(commTerms[3]));
            assertEq(licenseTermsIds2[4], pilTemplate.getLicenseTermsId(commTerms[4]));
            assertEq(spgNftContract.tokenURI(tokenId2), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId2, testIpMetadata);
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 0);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsIds2[0]);
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 1);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsIds2[1]);
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 2);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsIds2[2]);
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 3);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsIds2[3]);
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 4);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsIds2[4]);
        }
    }

    function _test_LicenseAttachmentIntegration_registerIpAndAttachPILTerms()
        private
        logTest("test_LicenseAttachmentIntegration_registerIpAndAttachPILTerms")
    {
        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);

        uint256 tokenId = spgNftContract.mint(testSender, "");
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadata, bytes32 sigAttachState, ) = _getSetPermissionSigForPeriphery({
            ipId: expectedIpId,
            to: licenseAttachmentWorkflowsAddr,
            module: coreMetadataModuleAddr,
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerSk: testSenderSk
        });

        (bytes memory sigAttach, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: expectedIpId,
            to: licenseAttachmentWorkflowsAddr,
            module: licensingModuleAddr,
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: sigAttachState,
            signerSk: testSenderSk
        });

        (address ipId, uint256[] memory licenseTermsIds) = licenseAttachmentWorkflows.registerIpAndAttachPILTerms({
            nftContract: address(spgNftContract),
            tokenId: tokenId,
            ipMetadata: testIpMetadata,
            terms: commTerms,
            sigMetadata: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadata
            }),
            sigAttach: WorkflowStructs.SignatureData({ signer: testSender, deadline: deadline, signature: sigAttach })
        });

        assertEq(ipId, expectedIpId);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(IIPAccount(payable(ipId)).state(), expectedState);
        assertEq(licenseTermsIds[0], pilTemplate.getLicenseTermsId(commTerms[0]));
        assertEq(licenseTermsIds[1], pilTemplate.getLicenseTermsId(commTerms[1]));
        assertEq(licenseTermsIds[2], pilTemplate.getLicenseTermsId(commTerms[2]));
        assertEq(licenseTermsIds[3], pilTemplate.getLicenseTermsId(commTerms[3]));
        assertEq(licenseTermsIds[4], pilTemplate.getLicenseTermsId(commTerms[4]));
        (address expectedLicenseTemplate, uint256 expectedLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(
            expectedIpId,
            0
        );
        assertEq(expectedLicenseTemplate, pilTemplateAddr);
        assertEq(expectedLicenseTermsId, licenseTermsIds[0]);
        (expectedLicenseTemplate, expectedLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(expectedIpId, 1);
        assertEq(expectedLicenseTemplate, pilTemplateAddr);
        assertEq(expectedLicenseTermsId, licenseTermsIds[1]);
        (expectedLicenseTemplate, expectedLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(expectedIpId, 2);
        assertEq(expectedLicenseTemplate, pilTemplateAddr);
        assertEq(expectedLicenseTermsId, licenseTermsIds[2]);
        (expectedLicenseTemplate, expectedLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(expectedIpId, 3);
        assertEq(expectedLicenseTemplate, pilTemplateAddr);
        assertEq(expectedLicenseTermsId, licenseTermsIds[3]);
        (expectedLicenseTemplate, expectedLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(expectedIpId, 4);
        assertEq(expectedLicenseTemplate, pilTemplateAddr);
        assertEq(expectedLicenseTermsId, licenseTermsIds[4]);
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

        uint32 testCommRevShare = 5 * 10 ** 6; // 5%

        commTerms.push(
            PILFlavors.commercialRemix({
                mintingFee: testMintFee,
                commercialRevShare: testCommRevShare,
                royaltyPolicy: royaltyPolicyLAPAddr,
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
        commTerms.push(
            PILFlavors.commercialRemix({
                mintingFee: testMintFee,
                commercialRevShare: testCommRevShare,
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
        commTerms.push(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: testCommRevShare,
                royaltyPolicy: royaltyPolicyLAPAddr,
                currencyToken: testMintFeeToken
            })
        );
    }
}
