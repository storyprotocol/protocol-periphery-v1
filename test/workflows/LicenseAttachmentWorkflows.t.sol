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
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

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
    PILTerms[] private terms;

    function setUp() public override {
        super.setUp();

        terms.push(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        terms.push(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 5 * 10 ** 6, // 5%
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(mockToken)
            })
        );
        terms.push(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLRP)
            })
        );
        terms.push(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 5 * 10 ** 6, // 5%
                royaltyPolicy: address(royaltyPolicyLRP),
                currencyToken: address(mockToken)
            })
        );
        terms.push(
            PILFlavors.commercialRemix({
                mintingFee: 100 * 10 ** mockToken.decimals(),
                commercialRevShare: 10 * 10 ** 6, // 10%
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
            ipMetadata: ipMetadataDefault
        });
        ipAsset[1] = IPAsset({ ipId: payable(ipId), tokenId: tokenId, owner: owner });
        vm.stopPrank();
        _;
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach() public withCollection withIp(u.alice) {
        address payable ipId = ipAsset[1].ipId;
        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature, , ) = _getSetPermissionSigForPeriphery({
            ipId: ipId,
            to: address(licenseAttachmentWorkflows),
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        uint256 ltAmt = pilTemplate.totalRegisteredLicenseTerms();

        uint256[] memory licenseTermsIds = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            terms: terms,
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature })
        });

        assertEq(licenseTermsIds[0], ltAmt + 1);
        assertEq(licenseTermsIds[1], ltAmt + 2);
        assertEq(licenseTermsIds[2], ltAmt + 3);
        assertEq(licenseTermsIds[3], ltAmt + 4);
        assertEq(licenseTermsIds[4], ltAmt + 5);
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
                terms: terms
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, 1);
        assertEq(licenseTermsIds1[0], 2);
        assertEq(licenseTermsIds1[1], 3);
        assertEq(licenseTermsIds1[2], 4);
        assertEq(licenseTermsIds1[3], 5);
        assertEq(licenseTermsIds1[4], 6);
        assertEq(nftContract.tokenURI(tokenId1), string.concat(testBaseURI, tokenId1.toString()));
        assertMetadata(ipId1, ipMetadataEmpty);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, licenseTermsIds1[0]);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 1);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, licenseTermsIds1[1]);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 2);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, licenseTermsIds1[2]);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 3);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, licenseTermsIds1[3]);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 4);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, licenseTermsIds1[4]);

        (address ipId2, uint256 tokenId2, uint256[] memory licenseTermsIds2) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                terms: terms
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(tokenId2, 2);
        assertEq(licenseTermsIds1[0], licenseTermsIds2[0]);
        assertEq(licenseTermsIds1[1], licenseTermsIds2[1]);
        assertEq(licenseTermsIds1[2], licenseTermsIds2[2]);
        assertEq(licenseTermsIds1[3], licenseTermsIds2[3]);
        assertEq(licenseTermsIds1[4], licenseTermsIds2[4]);
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
            terms: terms,
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigMetadata }),
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigAttach })
        });

        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertMetadata(ipId, ipMetadataDefault);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, pilTemplate.getLicenseTermsId(terms[0]));
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 1);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, pilTemplate.getLicenseTermsId(terms[1]));
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 2);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, pilTemplate.getLicenseTermsId(terms[2]));
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 3);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, pilTemplate.getLicenseTermsId(terms[3]));
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 4);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, pilTemplate.getLicenseTermsId(terms[4]));
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach_idempotency()
        public
        withCollection
        withIp(u.alice)
    {
        address payable ipId = ipAsset[1].ipId;
        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature1, , ) = _getSetPermissionSigForPeriphery({
            ipId: ipId,
            to: address(licenseAttachmentWorkflows),
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        uint256[] memory licenseTermsIds1 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            terms: terms,
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature1 })
        });

        (bytes memory signature2, , ) = _getSetPermissionSigForPeriphery({
            ipId: ipId,
            to: address(licenseAttachmentWorkflows),
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        /// attach the same license terms to the IP again, but it shouldn't revert
        uint256[] memory licenseTermsIds2 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            terms: terms,
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature2 })
        });

        assertEq(licenseTermsIds1[0], licenseTermsIds2[0]);
        assertEq(licenseTermsIds1[1], licenseTermsIds2[1]);
        assertEq(licenseTermsIds1[2], licenseTermsIds2[2]);
        assertEq(licenseTermsIds1[3], licenseTermsIds2[3]);
        assertEq(licenseTermsIds1[4], licenseTermsIds2[4]);
    }

    function test_revert_registerPILTermsAndAttach_DerivativesCannotAddLicenseTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipIdParent, , uint256[] memory licenseTermsIdsParent) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                terms: terms
            });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdsParent[0];

        (address ipIdChild, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
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

        (bytes memory signature, , ) = _getSetPermissionSigForPeriphery({
            ipId: ipIdChild,
            to: address(licenseAttachmentWorkflows),
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(payable(ipIdChild)).state(),
            signerSk: sk.alice
        });

        /// attach license terms to the child ip, should revert with the correct error
        vm.expectRevert(CoreErrors.LicensingModule__DerivativesCannotAddLicenseTerms.selector);
        licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipIdChild,
            terms: terms,
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature })
        });
    }
}
