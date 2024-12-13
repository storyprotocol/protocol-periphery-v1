// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { MetaTx } from "@storyprotocol/core/lib/MetaTx.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

// contracts
import { Errors } from "../../contracts/lib/Errors.sol";
import { ISPGNFT } from "../../contracts/interfaces/ISPGNFT.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";

contract RoyaltyTokenDistributionWorkflowsTest is BaseTest {
    using Strings for uint256;
    using MessageHashUtils for bytes32;

    uint256 private nftMintingFee;
    uint256 private licenseMintingFee;

    PILTerms[] private commRemixTerms;

    WorkflowStructs.RoyaltyShare[] private royaltyShares;
    WorkflowStructs.MakeDerivative private derivativeData;

    function setUp() public override {
        super.setUp();
        _setUpTest();
    }

    function test_RoyaltyTokenDistributionWorkflows_mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens()
        public
    {
        vm.startPrank(u.alice);
        mockToken.mint(u.alice, nftMintingFee + licenseMintingFee);
        mockToken.approve(address(spgNftPublic), nftMintingFee);
        mockToken.approve(address(royaltyTokenDistributionWorkflows), licenseMintingFee);

        (address ipId, uint256 tokenId, uint256[] memory licenseTermsIds) = royaltyTokenDistributionWorkflows
            .mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens({
                spgNftContract: address(spgNftPublic),
                recipient: u.alice,
                ipMetadata: ipMetadataDefault,
                terms: commRemixTerms,
                royaltyShares: royaltyShares
            });
        vm.stopPrank();

        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(tokenId, 2);
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
                royaltyShares: royaltyShares
            });
        vm.stopPrank();

        assertEq(tokenId, 2);
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

        WorkflowStructs.SignatureData memory sigMetadata;
        WorkflowStructs.SignatureData memory sigAttach;
        WorkflowStructs.SignatureData memory sigApproveRoyaltyTokens;
        bytes32 expectedStateAttach;

        {
            (bytes memory signatureMetadata, bytes32 expectedStateMetadata, ) = _getSetPermissionSigForPeriphery({
                ipId: expectedIpId,
                to: address(royaltyTokenDistributionWorkflows),
                module: address(coreMetadataModule),
                selector: ICoreMetadataModule.setAll.selector,
                deadline: deadline,
                state: bytes32(0),
                signerSk: sk.alice
            });

            bytes memory signatureAttach;
            (signatureAttach, expectedStateAttach, ) = _getSetPermissionSigForPeriphery({
                ipId: expectedIpId,
                to: address(royaltyTokenDistributionWorkflows),
                module: address(licensingModule),
                selector: ILicensingModule.attachLicenseTerms.selector,
                deadline: deadline,
                state: expectedStateMetadata,
                signerSk: sk.alice
            });

            sigMetadata = WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signatureMetadata
            });

            sigAttach = WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signatureAttach
            });
        }

        // register IP, attach PIL terms, and deploy royalty vault
        vm.startPrank(u.alice);
        mockToken.mint(u.alice, licenseMintingFee);
        mockToken.approve(address(royaltyTokenDistributionWorkflows), licenseMintingFee);
        (address ipId, uint256[] memory licenseTermsIds, address ipRoyaltyVault) = royaltyTokenDistributionWorkflows
            .registerIpAndAttachPILTermsAndDeployRoyaltyVault({
                nftContract: address(mockNft),
                tokenId: tokenId,
                ipMetadata: ipMetadataDefault,
                terms: commRemixTerms,
                sigMetadata: sigMetadata,
                sigAttach: sigAttach
            });
        vm.stopPrank();

        {
            (bytes memory signatureApproveRoyaltyTokens, ) = _getSigForExecuteWithSig({
                ipId: expectedIpId,
                to: ipRoyaltyVault,
                deadline: deadline,
                state: expectedStateAttach,
                data: abi.encodeWithSelector(
                    IERC20.approve.selector,
                    address(royaltyTokenDistributionWorkflows),
                    100_000_000 // 100%
                ),
                signerSk: sk.alice
            });
            sigApproveRoyaltyTokens = WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signatureApproveRoyaltyTokens
            });
        }

        vm.startPrank(u.alice);
        // distribute royalty tokens
        royaltyTokenDistributionWorkflows.distributeRoyaltyTokens({
            ipId: ipId,
            ipRoyaltyVault: ipRoyaltyVault,
            royaltyShares: royaltyShares,
            sigApproveRoyaltyTokens: sigApproveRoyaltyTokens
        });
        vm.stopPrank();

        assertTrue(ipAssetRegistry.isRegistered(ipId));
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

    function test_RoyaltyTokenDistributionWorkflows_registerIpAndMakeDerivativeAndDistributeRoyaltyTokens() public {
        uint256 tokenId = mockNft.mint(u.alice);
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(mockNft), tokenId);

        uint256 deadline = block.timestamp + 1000;

        WorkflowStructs.SignatureData memory sigMetadata;
        WorkflowStructs.SignatureData memory sigRegister;
        WorkflowStructs.SignatureData memory sigApproveRoyaltyTokens;
        bytes32 expectedStateRegister;

        {
            (bytes memory signatureMetadata, bytes32 expectedStateMetadata, ) = _getSetPermissionSigForPeriphery({
                ipId: expectedIpId,
                to: address(royaltyTokenDistributionWorkflows),
                module: address(coreMetadataModule),
                selector: ICoreMetadataModule.setAll.selector,
                deadline: deadline,
                state: bytes32(0),
                signerSk: sk.alice
            });

            bytes memory signatureRegister;
            (signatureRegister, expectedStateRegister, ) = _getSetPermissionSigForPeriphery({
                ipId: expectedIpId,
                to: address(royaltyTokenDistributionWorkflows),
                module: address(licensingModule),
                selector: ILicensingModule.registerDerivative.selector,
                deadline: deadline,
                state: expectedStateMetadata,
                signerSk: sk.alice
            });

            sigMetadata = WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signatureMetadata
            });

            sigRegister = WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signatureRegister
            });
        }

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
                sigMetadata: sigMetadata,
                sigRegister: sigRegister
            });
        vm.stopPrank();

        {
            // get signature for approving royalty tokens
            (bytes memory signatureApproveRoyaltyTokens, ) = _getSigForExecuteWithSig({
                ipId: expectedIpId,
                to: ipRoyaltyVault,
                deadline: deadline,
                state: expectedStateRegister,
                data: abi.encodeWithSelector(
                    IERC20.approve.selector,
                    address(royaltyTokenDistributionWorkflows),
                    100_000_000 // 100%
                ),
                signerSk: sk.alice
            });
            sigApproveRoyaltyTokens = WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signatureApproveRoyaltyTokens
            });
        }

        vm.startPrank(u.alice);
        // distribute royalty tokens
        royaltyTokenDistributionWorkflows.distributeRoyaltyTokens({
            ipId: ipId,
            ipRoyaltyVault: ipRoyaltyVault,
            royaltyShares: royaltyShares,
            sigApproveRoyaltyTokens: sigApproveRoyaltyTokens
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

    function test_RoyaltyTokenDistributionWorkflows_revert_TotalPercentagesExceeds100Percent() public {
        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                author: u.dan,
                percentage: 10_000_000 // 10%
            })
        );

        vm.startPrank(u.alice);
        mockToken.mint(u.alice, nftMintingFee + licenseMintingFee);
        mockToken.approve(address(spgNftPublic), nftMintingFee);
        mockToken.approve(address(royaltyTokenDistributionWorkflows), licenseMintingFee);

        vm.expectRevert(Errors.RoyaltyTokenDistributionWorkflows__TotalPercentagesExceeds100Percent.selector);
        royaltyTokenDistributionWorkflows.mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            terms: commRemixTerms,
            royaltyShares: royaltyShares
        });
        vm.stopPrank();
    }

    function test_RoyaltyTokenDistributionWorkflows_revert_RoyaltyVaultNotDeployed() public {
        vm.startPrank(u.alice);
        mockToken.mint(u.alice, licenseMintingFee);
        mockToken.approve(address(spgNftPublic), licenseMintingFee);

        PILTerms[] memory terms = new PILTerms[](1);
        terms[0] = PILFlavors.nonCommercialSocialRemixing();
        vm.expectRevert(Errors.RoyaltyTokenDistributionWorkflows__RoyaltyVaultNotDeployed.selector);
        royaltyTokenDistributionWorkflows.mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            terms: terms,
            royaltyShares: royaltyShares
        });
        vm.stopPrank();
    }

    function _setUpTest() private {
        nftMintingFee = 1 * 10 ** mockToken.decimals();
        licenseMintingFee = 1 * 10 ** mockToken.decimals();

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
        (ipIdParent[0], , licenseTermsIdsParent) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            terms: commRemixTermsParent
        });
        vm.stopPrank();

        derivativeData = WorkflowStructs.MakeDerivative({
            parentIpIds: ipIdParent,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIdsParent,
            royaltyContext: ""
        });

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                author: u.admin,
                percentage: 50_000_000 // 50%
            })
        );

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                author: u.alice,
                percentage: 20_000_000 // 20%
            })
        );

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                author: u.bob,
                percentage: 20_000_000 // 20%
            })
        );

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                author: u.carl,
                percentage: 10_000_000 // 10%
            })
        );
    }

    /// @dev Assert that the royalty tokens have been distributed correctly.
    /// @param ipId The ID of the IP whose royalty tokens to check.
    function _assertRoyaltyTokenDistribution(address ipId) private {
        address royaltyVault = royaltyModule.ipRoyaltyVaults(ipId);
        IERC20 royaltyToken = IERC20(royaltyVault);

        for (uint256 i; i < royaltyShares.length; i++) {
            assertEq(royaltyToken.balanceOf(royaltyShares[i].author), royaltyShares[i].percentage);
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
}
