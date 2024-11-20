//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

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
    uint256 commRemixTermsId;

    function setUp() public override {
        super.setUp();
        commRemixTermsId = IPILicenseTemplate(pilTemplate).registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 20,
                commercialRevShare: 50,
                royaltyPolicy: address(royaltyPolicyLRP),
                currencyToken: address(mockToken)
            })
        );
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
            terms: PILFlavors.commercialUse({
                mintingFee: 20,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            }),
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
            terms: PILFlavors.nonCommercialSocialRemixing(),
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
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            allowDuplicates: false
        });
    }

    function test_LicenseAttachmentWorkflows_mintAndRegisterIpAndAttachPILTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipId1, uint256 tokenId1, uint256 licenseTermsId1) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataEmpty,
                terms: PILFlavors.commercialUse({
                    mintingFee: 20,
                    currencyToken: address(mockToken),
                    royaltyPolicy: address(royaltyPolicyLAP)
                }),
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, 1);
        assertEq(licenseTermsId1, commRemixTermsId + 1);
        assertEq(nftContract.tokenURI(tokenId1), string.concat(testBaseURI, tokenId1.toString()));
        assertMetadata(ipId1, ipMetadataEmpty);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, licenseTermsId1);

        (address ipId2, uint256 tokenId2, uint256 licenseTermsId2) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                terms: PILFlavors.commercialUse({
                    mintingFee: 20,
                    currencyToken: address(mockToken),
                    royaltyPolicy: address(royaltyPolicyLAP)
                }),
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(tokenId2, 2);
        assertEq(nftContract.tokenURI(tokenId2), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipId2, ipMetadataDefault);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, licenseTermsId2);
        assertEq(licenseTermsId2, licenseTermsId1);
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
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            allowDuplicates: true
        });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, 1);
        assertEq(nftContract.tokenURI(tokenId1), string.concat(testBaseURI, tokenId1.toString()));
        assertMetadata(ipId1, ipMetadataEmpty);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);

        (address ipId2, uint256 tokenId2) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachLicenseTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            allowDuplicates: true
        });
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(tokenId2, 2);
        assertEq(nftContract.tokenURI(tokenId2), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipId2, ipMetadataDefault);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);
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

        (bytes memory sigAttach, ) = _getSigForExecuteWithSig({
            ipId: ipId,
            to: address(licensingModule),
            deadline: deadline,
            state: expectedState,
            data: abi.encodeWithSelector(
                ILicensingModule.attachLicenseTerms.selector,
                ipId,
                pilTemplate,
                commRemixTermsId
            ),
            signerSk: sk.alice
        });

        licenseAttachmentWorkflows.registerIpAndAttachLicenseTerms({
            nftContract: address(nftContract),
            tokenId: tokenId,
            ipMetadata: ipMetadataDefault,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigMetadata }),
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigAttach })
        });

        assertMetadata(ipId, ipMetadataDefault);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);
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
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            allowDuplicates: true
        });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commRemixTermsId;

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
                pilTemplate,
                commRemixTermsId
            ),
            signerSk: sk.alice
        });

        LicensingHelper.attachLicenseTermsWithSig({
            ipId: ipIdChild,
            licensingModule: address(licensingModule),
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature })
        });
    }
}
