//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

// contracts
import { Errors } from "../../contracts/lib/Errors.sol";
import { LicensingHelper } from "../../contracts/lib/LicensingHelper.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";

contract LicenseAttachmentWorkflowsTest is BaseTest {
    using Strings for uint256;

    struct IPAsset {
        address payable ipId;
        uint256 tokenId;
        address owner;
    }

    mapping(uint256 index => IPAsset) internal ipAsset;
    PILTerms[] internal commTerms;
    address[] internal licenseTemplates;
    uint256[] internal commTermsIds;

    function setUp() public override {
        super.setUp();

        commTerms.push(
            PILFlavors.commercialRemix({
                mintingFee: 20,
                commercialRevShare: 50,
                royaltyPolicy: address(royaltyPolicyLRP),
                currencyToken: address(mockToken)
            })
        );

        commTerms.push(
            PILFlavors.commercialUse({
                mintingFee: 20,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(mockToken)
            })
        );

        licenseTemplates = new address[](2);
        licenseTemplates[0] = address(pilTemplate);
        licenseTemplates[1] = address(pilTemplate);

        commTermsIds = new uint256[](2);
        commTermsIds[0] = IPILicenseTemplate(pilTemplate).registerLicenseTerms(commTerms[0]);
        commTermsIds[1] = IPILicenseTemplate(pilTemplate).registerLicenseTerms(commTerms[1]);
    }

    modifier withIp(address owner) {
        vm.startPrank(owner);
        mockToken.mint(address(owner), 100 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 100 * 10 ** mockToken.decimals());
        (address ipId, uint256 tokenId) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(nftContract),
            recipient: owner,
            ipMetadata: ipMetadataDefault,
            allowDuplicates: true
        });
        ipAsset[1] = IPAsset({ ipId: payable(ipId), tokenId: tokenId, owner: owner });
        vm.stopPrank();
        _;
    }

    function test_LicenseAttachmentWorkflows_revert_DuplicatedNFTMetadataHash()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            terms: commTerms,
            allowDuplicates: true
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SPGNFT__DuplicatedNFTMetadataHash.selector,
                address(nftContract),
                1,
                ipMetadataDefault.nftMetadataHash
            )
        );
        licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            terms: commTerms,
            allowDuplicates: false
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SPGNFT__DuplicatedNFTMetadataHash.selector,
                address(nftContract),
                1,
                ipMetadataDefault.nftMetadataHash
            )
        );
        licenseAttachmentWorkflows.mintAndRegisterIpAndAttachLicenseTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            licenseTemplates: licenseTemplates,
            licenseTermsIds: commTermsIds,
            allowDuplicates: false
        });
    }

    function test_LicenseAttachmentWorkflows_mintAndRegisterIpAndAttachPILTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipId1, uint256 tokenId1, uint256[] memory licenseTermsIds1) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataEmpty,
                terms: commTerms,
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, 1);
        assertEq(nftContract.tokenURI(tokenId1), string.concat(testBaseURI, tokenId1.toString()));
        assertMetadata(ipId1, ipMetadataEmpty);
        address licenseTemplate;
        uint256 licenseTermsId;
        for (uint256 i = 0; i < licenseTermsIds1.length; i++) {
            assertEq(licenseTermsIds1[i], commTermsIds[i]);
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, i);
            assertEq(licenseTemplate, licenseTemplates[i]);
            assertEq(licenseTermsId, licenseTermsIds1[i]);
        }

        (address ipId2, uint256 tokenId2, uint256[] memory licenseTermsIds2) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                terms: commTerms,
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(tokenId2, 2);
        assertEq(nftContract.tokenURI(tokenId2), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipId2, ipMetadataDefault);
        for (uint256 i = 0; i < licenseTermsIds2.length; i++) {
            assertEq(licenseTermsIds2[i], commTermsIds[i]);
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, i);
            assertEq(licenseTemplate, licenseTemplates[i]);
            assertEq(licenseTermsId, licenseTermsIds2[i]);
        }
    }

    function test_LicenseAttachmentWorkflows_mintAndRegisterIpAndAttachLicenseTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipId1, uint256 tokenId1) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachLicenseTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataEmpty,
            licenseTemplates: licenseTemplates,
            licenseTermsIds: commTermsIds,
            allowDuplicates: true
        });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, 1);
        assertEq(nftContract.tokenURI(tokenId1), string.concat(testBaseURI, tokenId1.toString()));
        assertMetadata(ipId1, ipMetadataEmpty);
        address licenseTemplate;
        uint256 licenseTermsId;
        for (uint256 i = 0; i < commTermsIds.length; i++) {
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, i);
            assertEq(licenseTemplate, licenseTemplates[i]);
            assertEq(licenseTermsId, commTermsIds[i]);
        }

        (address ipId2, uint256 tokenId2) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachLicenseTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            licenseTemplates: licenseTemplates,
            licenseTermsIds: commTermsIds,
            allowDuplicates: true
        });
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(tokenId2, 2);
        assertEq(nftContract.tokenURI(tokenId2), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipId2, ipMetadataDefault);
        for (uint256 i = 0; i < commTermsIds.length; i++) {
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, i);
            assertEq(licenseTemplate, licenseTemplates[i]);
            assertEq(licenseTermsId, commTermsIds[i]);
        }
    }

    function test_LicenseAttachmentWorkflows_registerIpAndAttachLicenseTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        uint256 tokenId = nftContract.mint({
            to: caller,
            nftMetadataURI: ipMetadataEmpty.nftMetadataURI,
            nftMetadataHash: ipMetadataEmpty.nftMetadataHash,
            allowDuplicates: true
        });
        address payable ipId = payable(ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenId));

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadata, bytes32 expectedState) = _getSigForExecuteWithSig({
            ipId: ipId,
            to: address(coreMetadataModule),
            deadline: deadline,
            state: bytes32(0),
            data: abi.encodeWithSelector(
                ICoreMetadataModule.setAll.selector,
                ipId,
                ipMetadataDefault.ipMetadataURI,
                ipMetadataDefault.ipMetadataHash,
                ipMetadataDefault.nftMetadataHash
            ),
            signerSk: sk.alice
        });

        bytes[] memory sigsAttach = new bytes[](commTermsIds.length);
        for (uint256 i = 0; i < commTermsIds.length; i++) {
            (sigsAttach[i], expectedState) = _getSigForExecuteWithSig({
                ipId: ipId,
                to: address(licensingModule),
                deadline: deadline,
                state: expectedState,
                data: abi.encodeWithSelector(
                    ILicensingModule.attachLicenseTerms.selector,
                    ipId,
                    licenseTemplates[i],
                    commTermsIds[i]
                ),
                signerSk: sk.alice
            });
        }

        WorkflowStructs.SignatureData[] memory sigsAttachData = new WorkflowStructs.SignatureData[](
            commTermsIds.length
        );
        for (uint256 i = 0; i < commTermsIds.length; i++) {
            sigsAttachData[i] = WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: sigsAttach[i]
            });
        }

        licenseAttachmentWorkflows.registerIpAndAttachLicenseTerms({
            nftContract: address(nftContract),
            tokenId: tokenId,
            ipMetadata: ipMetadataDefault,
            licenseTemplates: licenseTemplates,
            licenseTermsIds: commTermsIds,
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigMetadata }),
            sigsAttach: sigsAttachData
        });

        assertMetadata(ipId, ipMetadataDefault);
        address licenseTemplate;
        uint256 licenseTermsId;
        for (uint256 i = 0; i < commTermsIds.length; i++) {
            (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, i);
            assertEq(licenseTemplate, licenseTemplates[i]);
            assertEq(licenseTermsId, commTermsIds[i]);
        }
    }

    function test_revert_registerPILTermsAndAttach_DerivativesCannotAddLicenseTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipIdParent, ) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachLicenseTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            licenseTemplates: licenseTemplates,
            licenseTermsIds: commTermsIds,
            allowDuplicates: true
        });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commTermsIds[0];

        vm.startPrank(caller);
        mockToken.mint(address(caller), 20 * 10 ** mockToken.decimals());
        mockToken.approve(address(derivativeWorkflows), 10 * 10 ** mockToken.decimals());

        (address ipIdChild, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller,
            allowDuplicates: true
        });

        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature, ) = _getSigForExecuteWithSig({
            ipId: ipIdChild,
            to: address(licensingModule),
            deadline: deadline,
            state: IIPAccount(payable(ipIdChild)).state(),
            data: abi.encodeWithSelector(
                ILicensingModule.attachLicenseTerms.selector,
                ipIdChild,
                licenseTemplates[1],
                commTermsIds[1]
            ),
            signerSk: sk.alice
        });

        vm.expectRevert(CoreErrors.LicensingModule__DerivativesCannotAddLicenseTerms.selector);
        LicensingHelper.attachLicenseTermsWithSig({
            ipId: ipIdChild,
            licensingModule: address(licensingModule),
            licenseTemplate: licenseTemplates[1],
            licenseTermsId: commTermsIds[1],
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature })
        });
    }
}
