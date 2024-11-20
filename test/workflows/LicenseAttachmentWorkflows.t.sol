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

// contracts
import { Errors } from "../../contracts/lib/Errors.sol";
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

    function setUp() public override {
        super.setUp();
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
        (address ipId1, uint256 tokenId1, uint256 licenseTermsId1) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                terms: PILFlavors.nonCommercialSocialRemixing(),
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
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach() public withCollection withIp(u.alice) {
        address payable ipId = ipAsset[1].ipId;
        uint256 deadline = block.timestamp + 1000;

        // TODO: this is a hack to get the license terms id, we should refactor this in the next PR
        uint256 licenseTermsId = IPILicenseTemplate(pilTemplate).registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        (bytes memory signature, ) = _getSigForExecuteWithSig({
            ipId: ipId,
            to: address(licensingModule),
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            data: abi.encodeWithSelector(
                ILicensingModule.attachLicenseTerms.selector,
                ipId,
                pilTemplate,
                licenseTermsId
            ),
            signerSk: sk.alice
        });

        uint256 ltAmt = pilTemplate.totalRegisteredLicenseTerms();

        licenseTermsId = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            terms: PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            }),
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature })
        });

        assertEq(licenseTermsId, ltAmt);
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
                terms: PILFlavors.nonCommercialSocialRemixing(),
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, 1);
        assertEq(licenseTermsId1, 1);
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
                terms: PILFlavors.nonCommercialSocialRemixing(),
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(tokenId2, 2);
        assertEq(licenseTermsId1, licenseTermsId2);
        assertEq(nftContract.tokenURI(tokenId2), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipId2, ipMetadataDefault);
    }

    function test_LicenseAttachmentWorkflows_registerIpAndAttachPILTerms()
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
                IPILicenseTemplate(pilTemplate).getLicenseTermsId(PILFlavors.nonCommercialSocialRemixing())
            ),
            signerSk: sk.alice
        });

        licenseAttachmentWorkflows.registerIpAndAttachPILTerms({
            nftContract: address(nftContract),
            tokenId: tokenId,
            ipMetadata: ipMetadataDefault,
            terms: PILFlavors.nonCommercialSocialRemixing(),
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigMetadata }),
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigAttach })
        });
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach_idempotency()
        public
        withCollection
        withIp(u.alice)
    {
        address payable ipId = ipAsset[1].ipId;
        uint256 deadline = block.timestamp + 1000;

        // TODO: this is a hack to get the license terms id, we should refactor this in the next PR
        uint256 licenseTermsId = IPILicenseTemplate(pilTemplate).registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        (bytes memory signature1, ) = _getSigForExecuteWithSig({
            ipId: ipId,
            to: address(licensingModule),
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            data: abi.encodeWithSelector(
                ILicensingModule.attachLicenseTerms.selector,
                ipId,
                pilTemplate,
                licenseTermsId
            ),
            signerSk: sk.alice
        });

        uint256 licenseTermsId1 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            terms: PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            }),
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature1 })
        });

        (bytes memory signature2, ) = _getSigForExecuteWithSig({
            ipId: ipId,
            to: address(licensingModule),
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            data: abi.encodeWithSelector(
                ILicensingModule.attachLicenseTerms.selector,
                ipId,
                pilTemplate,
                licenseTermsId1
            ),
            signerSk: sk.alice
        });

        // attach the same license terms to the IP again, but it shouldn't revert
        uint256 licenseTermsId2 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            terms: PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            }),
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature2 })
        });

        assertEq(licenseTermsId1, licenseTermsId2);
    }

    function test_revert_registerPILTermsAndAttach_DerivativesCannotAddLicenseTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipIdParent, , uint256 licenseTermsIdParent) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                terms: PILFlavors.nonCommercialSocialRemixing(),
                allowDuplicates: true
            });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

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

        // TODO: this is a hack to get the license terms id, we should refactor this in the next PR
        uint256 licenseTermsId = IPILicenseTemplate(pilTemplate).registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        (bytes memory signature, ) = _getSigForExecuteWithSig({
            ipId: ipIdChild,
            to: address(licensingModule),
            deadline: deadline,
            state: IIPAccount(payable(ipIdChild)).state(),
            data: abi.encodeWithSelector(
                ILicensingModule.attachLicenseTerms.selector,
                ipIdChild,
                pilTemplate,
                licenseTermsId
            ),
            signerSk: sk.alice
        });

        // attach a different license terms to the child ip, should revert with the correct error
        vm.expectRevert(CoreErrors.LicensingModule__DerivativesCannotAddLicenseTerms.selector);
        licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipIdChild,
            terms: PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            }),
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature })
        });
    }
}
