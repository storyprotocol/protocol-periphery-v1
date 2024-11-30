// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

contract LicenseAttachmentIntegration is BaseIntegration {
    using Strings for uint256;

    ISPGNFT private spgNftContract;
    WorkflowStructs.LicenseTermsData[] private commTermsData;

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
            ipMetadata: testIpMetadata,
            allowDuplicates: true
        });

        uint256 deadline = block.timestamp + 1000;
        (bytes memory signature, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getAttachTermsAndConfigPermissionList(ipId, licenseAttachmentWorkflowsAddr),
            deadline: deadline,
            state: IIPAccount(payable(ipId)).state(),
            signerSk: testSenderSk
        });

        uint256[] memory licenseTermsIds = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: signature
            })
        });

        for (uint256 i = 0; i < licenseTermsIds.length; i++) {
            assertEq(licenseTermsIds[i], pilTemplate.getLicenseTermsId(commTermsData[i].terms));
        }
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
                    licenseTermsData: commTermsData,
                    allowDuplicates: true
                });
            assertTrue(ipAssetRegistry.isRegistered(ipId1));
            assertEq(tokenId1, spgNftContract.totalSupply());
            assertEq(spgNftContract.tokenURI(tokenId1), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId1, testIpMetadata);
            for (uint256 i = 0; i < licenseTermsIds1.length; i++) {
                (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, i);
                assertEq(licenseTemplate, pilTemplateAddr);
                assertEq(licenseTermsId, licenseTermsIds1[i]);
                assertEq(licenseTermsId, pilTemplate.getLicenseTermsId(commTermsData[i].terms));
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
                    licenseTermsData: commTermsData,
                    allowDuplicates: true
                });
            assertTrue(ipAssetRegistry.isRegistered(ipId2));
            assertEq(tokenId2, spgNftContract.totalSupply());
            assertEq(spgNftContract.tokenURI(tokenId2), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId2, testIpMetadata);
            for (uint256 i = 0; i < licenseTermsIds2.length; i++) {
                (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, i);
                assertEq(licenseTemplate, pilTemplateAddr);
                assertEq(licenseTermsIds2[i], licenseTermsId);
                assertEq(licenseTermsId, pilTemplate.getLicenseTermsId(commTermsData[i].terms));
            }
        }
    }

    function _test_LicenseAttachmentIntegration_registerIpAndAttachPILTerms()
        private
        logTest("test_LicenseAttachmentIntegration_registerIpAndAttachPILTerms")
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

        (bytes memory sigMetadataAndAttachAndConfig, bytes32 expectedState, ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndAttachTermsAndConfigPermissionList(
                expectedIpId,
                licenseAttachmentWorkflowsAddr
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: testSenderSk
        });

        (address ipId, uint256[] memory licenseTermsIds) = licenseAttachmentWorkflows.registerIpAndAttachPILTerms({
            nftContract: address(spgNftContract),
            tokenId: tokenId,
            ipMetadata: testIpMetadata,
            licenseTermsData: commTermsData,
            sigMetadataAndAttachAndConfig: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadataAndAttachAndConfig
            })
        });

        assertEq(ipId, expectedIpId);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(IIPAccount(payable(ipId)).state(), expectedState);
        for (uint256 i = 0; i < licenseTermsIds.length; i++) {
            (address expectedLicenseTemplate, uint256 expectedLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(
                expectedIpId,
                i
            );
            assertEq(expectedLicenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsIds[i], expectedLicenseTermsId);
            assertEq(expectedLicenseTermsId, pilTemplate.getLicenseTermsId(commTermsData[i].terms));
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

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialUse({
                    mintingFee: testMintFee,
                    currencyToken: testMintFeeToken,
                    royaltyPolicy: royaltyPolicyLRPAddr
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 0,
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialUse({
                    mintingFee: testMintFee,
                    currencyToken: testMintFeeToken,
                    royaltyPolicy: royaltyPolicyLAPAddr
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: false,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 0,
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: testMintFee,
                    commercialRevShare: 5_000_000, // 5%
                    royaltyPolicy: royaltyPolicyLRPAddr,
                    currencyToken: testMintFeeToken
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 5_000_000, // 5%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: testMintFee,
                    commercialRevShare: 8_000_000, // 8%
                    royaltyPolicy: royaltyPolicyLAPAddr,
                    currencyToken: testMintFeeToken
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 8_000_000, // 8%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );
    }
}
