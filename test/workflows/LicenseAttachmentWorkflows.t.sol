//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

// contracts
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
            ipMetadata: ipMetadataDefault
        });
        ipAsset[1] = IPAsset({ ipId: payable(ipId), tokenId: tokenId, owner: owner });
        vm.stopPrank();
        _;
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach() public withCollection withIp(u.alice) {
        address payable ipId = ipAsset[1].ipId;
        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature, , bytes memory data) = _getSetPermissionSigForPeriphery({
            ipId: ipId,
            to: address(licenseAttachmentWorkflows),
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        vm.prank(address(0x111));
        IIPAccount(ipId).executeWithSig({
            to: address(accessController),
            value: 0,
            data: data,
            signer: u.alice,
            deadline: deadline,
            signature: signature
        });

        uint256 ltAmt = pilTemplate.totalRegisteredLicenseTerms();

        uint256 licenseTermsId = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipAsset[1].ipId,
            terms: PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        });

        assertEq(licenseTermsId, ltAmt + 1);
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
                terms: PILFlavors.nonCommercialSocialRemixing()
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
                terms: PILFlavors.nonCommercialSocialRemixing()
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
        uint256 tokenId = nftContract.mint(address(caller), ipMetadataEmpty.nftMetadataURI);
        address payable ipId = payable(ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenId));

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadata, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: ipId,
            to: address(licenseAttachmentWorkflows),
            module: address(coreMetadataModule),
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        (bytes memory sigAttach, , ) = _getSetPermissionSigForPeriphery({
            ipId: ipId,
            to: address(licenseAttachmentWorkflows),
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: expectedState,
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

        (bytes memory signature, , bytes memory data) = _getSetPermissionSigForPeriphery({
            ipId: ipId,
            to: address(licenseAttachmentWorkflows),
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        IIPAccount(ipId).executeWithSig({
            to: address(accessController),
            value: 0,
            data: data,
            signer: u.alice,
            deadline: deadline,
            signature: signature
        });

        uint256 licenseTermsId1 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            terms: PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        });

        // attach the same license terms to the IP again, but it shouldn't revert
        uint256 licenseTermsId2 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            terms: PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
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
                terms: PILFlavors.nonCommercialSocialRemixing()
            });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        (address ipIdChild, uint256 tokenIdChild) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: ""
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller
        });

        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature, , bytes memory data) = _getSetPermissionSigForPeriphery({
            ipId: ipIdChild,
            to: address(licenseAttachmentWorkflows),
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(payable(ipIdChild)).state(),
            signerSk: sk.alice
        });

        IIPAccount(payable(ipIdChild)).executeWithSig({
            to: address(accessController),
            value: 0,
            data: data,
            signer: u.alice,
            deadline: deadline,
            signature: signature
        });

        // attach a different license terms to the child ip, should revert with the correct error
        vm.expectRevert(CoreErrors.LicensingModule__DerivativesCannotAddLicenseTerms.selector);
        licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipIdChild,
            terms: PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        });
    }
}
