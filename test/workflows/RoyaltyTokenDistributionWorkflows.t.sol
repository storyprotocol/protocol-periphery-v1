// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { MetaTx } from "@storyprotocol/core/lib/MetaTx.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

// contracts
import { Errors } from "../../contracts/lib/Errors.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";

contract RoyaltyTokenDistributionWorkflowsTest is BaseTest {
    using Strings for uint256;
    using MessageHashUtils for bytes32;

    uint256 private nftMintingFee;
    uint256 private licenseMintingFee;

    WorkflowStructs.LicenseTermsData[] private commRemixTermsData;
    WorkflowStructs.RoyaltyShare[] private royaltyShares;
    WorkflowStructs.MakeDerivative private derivativeData;

    /// DEPRECATED, WILL BE REMOVED IN V1.4----------------------------------------------------------------------------
    PILTerms[] private commRemixTerms;
    WorkflowStructs.MakeDerivativeDEPR private derivativeDataDEPR;
    ///----------------------------------------------------------------------------------------------------------------

    function setUp() public override {
        super.setUp();
        _setUpTest();
        _setUpDEPR();
    }

    function test_RoyaltyTokenDistributionWorkflows_mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens()
        public
    {
        vm.startPrank(u.alice);
        mockToken.mint(u.alice, nftMintingFee);
        mockToken.approve(address(spgNftPublic), nftMintingFee);

        (address ipId, uint256 tokenId, uint256[] memory licenseTermsIds) = royaltyTokenDistributionWorkflows
            .mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens({
                spgNftContract: address(spgNftPublic),
                recipient: u.alice,
                ipMetadata: ipMetadataDefault,
                licenseTermsData: commRemixTermsData,
                royaltyShares: royaltyShares,
                allowDuplicates: true
            });
        vm.stopPrank();

        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(tokenId, 3);
        assertEq(spgNftPublic.tokenURI(tokenId), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipId, ipMetadataDefault);
        _assertAttachedLicenseTerms(ipId, licenseTermsIds);
        _assertRoyaltyTokenDistribution(ipId);
    }

    function test_RoyaltyTokenDistributionWorkflows_mintAndRegisterIpAndMakeDerivativeAndDistributeRoyaltyTokens()
        public
    {
        vm.startPrank(u.alice);
        mockToken.mint(u.alice, nftMintingFee + licenseMintingFee);
        mockToken.approve(address(spgNftPublic), nftMintingFee);
        mockToken.approve(address(royaltyTokenDistributionWorkflows), licenseMintingFee);

        (address ipId, uint256 tokenId) = royaltyTokenDistributionWorkflows
            .mintAndRegisterIpAndMakeDerivativeAndDistributeRoyaltyTokens({
                spgNftContract: address(spgNftPublic),
                recipient: u.alice,
                ipMetadata: ipMetadataDefault,
                derivData: derivativeData,
                royaltyShares: royaltyShares,
                allowDuplicates: true
            });
        vm.stopPrank();

        assertEq(tokenId, 3);
        assertEq(spgNftPublic.tokenURI(tokenId), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertEq(ipAssetRegistry.ipId(block.chainid, address(spgNftPublic), tokenId), ipId);
        assertMetadata(ipId, ipMetadataDefault);
        assertParentChild({
            parentIpId: derivativeData.parentIpIds[0],
            childIpId: ipId,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
        (address licenseTemplateAttached, uint256 licenseTermsIdAttached) = licenseRegistry.getAttachedLicenseTerms(
            ipId,
            0
        );
        assertEq(licenseTemplateAttached, address(pilTemplate));
        assertEq(licenseTermsIdAttached, derivativeData.licenseTermsIds[0]);
        _assertRoyaltyTokenDistribution(ipId);
    }

    function test_RoyaltyTokenDistributionWorkflows_registerIpAndAttachPILTermsAndDistributeRoyaltyTokens() public {
        uint256 tokenId = mockNft.mint(u.alice);
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(mockNft), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory signatureMetadataAndAttachAndConfig, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndAttachTermsAndConfigPermissionList(
                expectedIpId,
                address(royaltyTokenDistributionWorkflows)
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        // register IP, attach PIL terms, and deploy royalty vault
        vm.startPrank(u.alice);
        (address ipId, uint256[] memory licenseTermsIds, address ipRoyaltyVault) = royaltyTokenDistributionWorkflows
            .registerIpAndAttachPILTermsAndDeployRoyaltyVault({
                nftContract: address(mockNft),
                tokenId: tokenId,
                ipMetadata: ipMetadataDefault,
                licenseTermsData: commRemixTermsData,
                sigMetadataAndAttachAndConfig: WorkflowStructs.SignatureData({
                    signer: u.alice,
                    deadline: deadline,
                    signature: signatureMetadataAndAttachAndConfig
                })
            });
        vm.stopPrank();

        (bytes memory signatureApproveRoyaltyTokens, ) = _getSigForExecuteWithSig({
            ipId: ipId,
            to: ipRoyaltyVault,
            deadline: deadline,
            state: IIPAccount(payable(ipId)).state(),
            data: abi.encodeWithSelector(
                IERC20.approve.selector,
                address(royaltyTokenDistributionWorkflows),
                95_000_000 // 95%
            ),
            signerSk: sk.alice
        });

        vm.startPrank(u.alice);
        // distribute royalty tokens
        royaltyTokenDistributionWorkflows.distributeRoyaltyTokens({
            ipId: ipId,
            royaltyShares: royaltyShares,
            sigApproveRoyaltyTokens: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signatureApproveRoyaltyTokens
            })
        });
        vm.stopPrank();

        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertMetadata(ipId, ipMetadataDefault);
        _assertAttachedLicenseTerms(ipId, licenseTermsIds);
        _assertRoyaltyTokenDistribution(ipId);
    }

    function test_RoyaltyTokenDistributionWorkflows_registerIpAndMakeDerivativeAndDistributeRoyaltyTokens() public {
        uint256 tokenId = mockNft.mint(u.alice);
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(mockNft), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                expectedIpId,
                address(royaltyTokenDistributionWorkflows),
                false
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        // register IP, make derivative, and deploy royalty vault
        vm.startPrank(u.alice);
        mockToken.mint(u.alice, licenseMintingFee);
        mockToken.approve(address(royaltyTokenDistributionWorkflows), licenseMintingFee);
        (address ipId, address ipRoyaltyVault) = royaltyTokenDistributionWorkflows
            .registerIpAndMakeDerivativeAndDeployRoyaltyVault({
                nftContract: address(mockNft),
                tokenId: tokenId,
                ipMetadata: ipMetadataDefault,
                derivData: derivativeData,
                sigMetadataAndRegister: WorkflowStructs.SignatureData({
                    signer: u.alice,
                    deadline: deadline,
                    signature: signatureMetadataAndRegister
                })
            });
        vm.stopPrank();

        // get signature for approving royalty tokens
        (bytes memory signatureApproveRoyaltyTokens, ) = _getSigForExecuteWithSig({
            ipId: ipId,
            to: ipRoyaltyVault,
            deadline: deadline,
            state: IIPAccount(payable(ipId)).state(),
            data: abi.encodeWithSelector(
                IERC20.approve.selector,
                address(royaltyTokenDistributionWorkflows),
                95_000_000 // 95%
            ),
            signerSk: sk.alice
        });

        vm.startPrank(u.alice);
        // distribute royalty tokens
        royaltyTokenDistributionWorkflows.distributeRoyaltyTokens({
            ipId: ipId,
            royaltyShares: royaltyShares,
            sigApproveRoyaltyTokens: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signatureApproveRoyaltyTokens
            })
        });
        vm.stopPrank();

        assertEq(ipAssetRegistry.ipId(block.chainid, address(mockNft), tokenId), ipId);
        assertMetadata(ipId, ipMetadataDefault);
        assertParentChild({
            parentIpId: derivativeData.parentIpIds[0],
            childIpId: ipId,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
        (address licenseTemplateAttached, uint256 licenseTermsIdAttached) = licenseRegistry.getAttachedLicenseTerms(
            ipId,
            0
        );
        assertEq(licenseTemplateAttached, address(pilTemplate));
        assertEq(licenseTermsIdAttached, derivativeData.licenseTermsIds[0]);
        _assertRoyaltyTokenDistribution(ipId);
    }

    function test_RoyaltyTokenDistributionWorkflows_revert_TotalSharesExceedsIPAccountBalance() public {
        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                recipient: u.dan,
                percentage: 10_000_000 // 10%
            })
        );

        vm.startPrank(u.alice);
        mockToken.mint(u.alice, nftMintingFee);
        mockToken.approve(address(spgNftPublic), nftMintingFee);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.RoyaltyTokenDistributionWorkflows__TotalSharesExceedsIPAccountBalance.selector,
                95_000_000 + 10_000_000,
                100_000_000
            )
        );
        royaltyTokenDistributionWorkflows.mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            licenseTermsData: commRemixTermsData,
            royaltyShares: royaltyShares,
            allowDuplicates: true
        });
        vm.stopPrank();
    }

    function _setUpTest() private {
        nftMintingFee = 1 * 10 ** mockToken.decimals();
        licenseMintingFee = 1 * 10 ** mockToken.decimals();

        uint32 testCommRevShare = 5 * 10 ** 6; // 5%

        commRemixTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: licenseMintingFee,
                    commercialRevShare: testCommRevShare,
                    royaltyPolicy: address(royaltyPolicyLAP),
                    currencyToken: address(mockToken)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: licenseMintingFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: testCommRevShare, // 5%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(evenSplitGroupPool)
                })
            })
        );

        commRemixTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: licenseMintingFee,
                    commercialRevShare: 5_000_000, // 5%
                    royaltyPolicy: address(royaltyPolicyLRP),
                    currencyToken: address(mockToken)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: licenseMintingFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 5_000_000, // 5%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(evenSplitGroupPool)
                })
            })
        );

        commRemixTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: licenseMintingFee,
                    commercialRevShare: 8_000_000, // 8%
                    royaltyPolicy: address(royaltyPolicyLAP),
                    currencyToken: address(mockToken)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: licenseMintingFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 8_000_000, // 8%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(evenSplitGroupPool)
                })
            })
        );

        address[] memory ipIdParent = new address[](1);
        uint256[] memory licenseTermsIds;
        vm.startPrank(u.alice);
        mockToken.mint(u.alice, licenseMintingFee);
        mockToken.approve(address(spgNftPublic), licenseMintingFee);
        (ipIdParent[0], , licenseTermsIds) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            licenseTermsData: commRemixTermsData,
            allowDuplicates: true
        });
        vm.stopPrank();

        uint256[] memory licenseTermsIdsParent = new uint256[](1);
        licenseTermsIdsParent[0] = licenseTermsIds[0];

        derivativeData = WorkflowStructs.MakeDerivative({
            parentIpIds: ipIdParent,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIdsParent,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRts: testCommRevShare,
            maxRevenueShare: 0
        });

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                recipient: u.admin,
                percentage: 50_000_000 // 50%
            })
        );

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                recipient: u.alice,
                percentage: 20_000_000 // 20%
            })
        );

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                recipient: u.bob,
                percentage: 20_000_000 // 20%
            })
        );

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                recipient: u.carl,
                percentage: 5_000_000 // 5%
            })
        );
    }

    function _assertAttachedLicenseTerms(address ipId, uint256[] memory licenseTermsIds) private {
        for (uint256 i = 0; i < commRemixTermsData.length; i++) {
            (address licenseTemplate, uint256 licenseTermsIdAttached) = licenseRegistry.getAttachedLicenseTerms(
                ipId,
                i
            );
            assertEq(licenseTermsIds[i], licenseTermsIdAttached);
            assertEq(licenseTemplate, address(pilTemplate));
            assertEq(licenseTermsIdAttached, licenseTermsIds[i]);
            assertEq(licenseTermsIdAttached, pilTemplate.getLicenseTermsId(commRemixTermsData[i].terms));
            Licensing.LicensingConfig memory licensingConfig = licenseRegistry.getLicensingConfig(
                ipId,
                licenseTemplate,
                licenseTermsIdAttached
            );
            assertEq(licensingConfig.isSet, commRemixTermsData[i].licensingConfig.isSet);
            assertEq(licensingConfig.mintingFee, commRemixTermsData[i].licensingConfig.mintingFee);
            assertEq(licensingConfig.licensingHook, commRemixTermsData[i].licensingConfig.licensingHook);
            assertEq(licensingConfig.hookData, commRemixTermsData[i].licensingConfig.hookData);
            assertEq(licensingConfig.commercialRevShare, commRemixTermsData[i].licensingConfig.commercialRevShare);
            assertEq(licensingConfig.disabled, commRemixTermsData[i].licensingConfig.disabled);
            assertEq(
                licensingConfig.expectGroupRewardPool,
                commRemixTermsData[i].licensingConfig.expectGroupRewardPool
            );
            assertEq(
                licensingConfig.expectMinimumGroupRewardShare,
                commRemixTermsData[i].licensingConfig.expectMinimumGroupRewardShare
            );
        }
    }

    /// @dev Assert that the royalty tokens have been distributed correctly.
    /// @param ipId The ID of the IP whose royalty tokens to check.
    function _assertRoyaltyTokenDistribution(address ipId) private {
        address royaltyVault = royaltyModule.ipRoyaltyVaults(ipId);
        IERC20 royaltyToken = IERC20(royaltyVault);

        for (uint256 i; i < royaltyShares.length; i++) {
            assertEq(royaltyToken.balanceOf(royaltyShares[i].recipient), royaltyShares[i].percentage);
        }
    }

    /// @dev Get the signature for executing a function on behalf of the IP via {IIPAccount.executeWithSig}.
    /// @param ipId The ID of the IP whose account will execute the function.
    /// @param to The address of the contract to execute the function on.
    /// @param deadline The deadline for the signature.
    /// @param state IPAccount's internal nonce
    /// @param data the call data for the function.
    /// @param signerSk The secret key of the signer.
    /// @return signature The signature for executing the function.
    /// @return expectedState The expected IPAccount's state after executing the function.
    function _getSigForExecuteWithSig(
        address ipId,
        address to,
        uint256 deadline,
        bytes32 state,
        bytes memory data,
        uint256 signerSk
    ) internal view returns (bytes memory signature, bytes32 expectedState) {
        expectedState = keccak256(
            abi.encode(
                state, // ipAccount.state()
                abi.encodeWithSelector(
                    IIPAccount.execute.selector,
                    to, // to
                    0, // value
                    data
                )
            )
        );

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(ipId),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({ to: to, value: 0, data: data, nonce: expectedState, deadline: deadline })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    ////////////////////////////////////////////////////////////////////////////
    //                   DEPRECATED, WILL BE REMOVED IN V1.4                  //
    ////////////////////////////////////////////////////////////////////////////

    function test_RoyaltyTokenDistributionWorkflows_mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens_DEPR()
        public
    {
        vm.startPrank(u.alice);
        mockToken.mint(u.alice, nftMintingFee + licenseMintingFee);
        mockToken.approve(address(spgNftPublic), nftMintingFee);
        mockToken.approve(address(royaltyTokenDistributionWorkflows), licenseMintingFee);

        (address ipId, uint256 tokenId, uint256[] memory licenseTermsIds) = royaltyTokenDistributionWorkflows
            .mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens_deprecated({
                spgNftContract: address(spgNftPublic),
                recipient: u.alice,
                ipMetadata: ipMetadataDefault,
                terms: commRemixTerms,
                royaltyShares: royaltyShares
            });
        vm.stopPrank();

        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(tokenId, 3);
        assertEq(spgNftPublic.tokenURI(tokenId), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipId, ipMetadataDefault);
        assertEq(licenseTermsIds[0], pilTemplate.getLicenseTermsId(commRemixTerms[0]));
        (address licenseTemplateAttached, uint256 licenseTermsIdAttached) = licenseRegistry.getAttachedLicenseTerms(
            ipId,
            0
        );
        assertEq(licenseTemplateAttached, address(pilTemplate));
        assertEq(licenseTermsIdAttached, pilTemplate.getLicenseTermsId(commRemixTerms[0]));
        (licenseTemplateAttached, licenseTermsIdAttached) = licenseRegistry.getAttachedLicenseTerms(ipId, 1);
        assertEq(licenseTemplateAttached, address(pilTemplate));
        assertEq(licenseTermsIdAttached, pilTemplate.getLicenseTermsId(commRemixTerms[1]));
        _assertRoyaltyTokenDistribution(ipId);
    }

    function test_RoyaltyTokenDistributionWorkflows_revert_RoyaltyVaultNotDeployed_DEPR() public {
        vm.startPrank(u.alice);
        mockToken.mint(u.alice, licenseMintingFee);
        mockToken.approve(address(spgNftPublic), licenseMintingFee);

        PILTerms[] memory terms = new PILTerms[](1);
        terms[0] = PILFlavors.nonCommercialSocialRemixing();
        vm.expectRevert(Errors.RoyaltyTokenDistributionWorkflows__RoyaltyVaultNotDeployed.selector);
        royaltyTokenDistributionWorkflows.mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens_deprecated({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            terms: terms,
            royaltyShares: royaltyShares
        });
        vm.stopPrank();
    }

    function _setUpDEPR() private {
        uint32 testCommRevShare = 5 * 10 ** 6; // 5%

        commRemixTerms.push(
            PILFlavors.commercialRemix({
                mintingFee: licenseMintingFee,
                commercialRevShare: testCommRevShare,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(mockToken)
            })
        );

        commRemixTerms.push(
            PILFlavors.commercialRemix({
                mintingFee: licenseMintingFee,
                commercialRevShare: testCommRevShare,
                royaltyPolicy: address(royaltyPolicyLRP),
                currencyToken: address(mockToken)
            })
        );

        PILTerms[] memory commRemixTermsParent = new PILTerms[](1);
        commRemixTermsParent[0] = PILFlavors.commercialRemix({
            mintingFee: licenseMintingFee,
            commercialRevShare: testCommRevShare,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockToken)
        });

        address[] memory ipIdParent = new address[](1);
        uint256[] memory licenseTermsIdsParent;
        vm.startPrank(u.alice);
        mockToken.mint(u.alice, licenseMintingFee);
        mockToken.approve(address(spgNftPublic), licenseMintingFee);
        (ipIdParent[0], , licenseTermsIdsParent) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms_deprecated({
                spgNftContract: address(spgNftPublic),
                recipient: u.alice,
                ipMetadata: ipMetadataDefault,
                terms: commRemixTermsParent
            });
        vm.stopPrank();

        derivativeDataDEPR = WorkflowStructs.MakeDerivativeDEPR({
            parentIpIds: ipIdParent,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIdsParent,
            royaltyContext: ""
        });
    }
}
