//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

// contracts
import { Errors } from "../../contracts/lib/Errors.sol";
import { LicensingHelper } from "../../contracts/lib/LicensingHelper.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";

contract DerivativeWorkflowsTest is BaseTest {
    using Strings for uint256;

    address internal ipIdParent;
    WorkflowStructs.LicenseTermsData[] internal nonCommTermsData;
    WorkflowStructs.LicenseTermsData[] internal commTermsData;
    function setUp() public override {
        super.setUp();
        nonCommTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.nonCommercialSocialRemixing(),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: 0,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 0,
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(evenSplitGroupPool)
                })
            })
        );

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: 100 * 10 ** mockToken.decimals(),
                    commercialRevShare: 10 * 10 ** 6, // 10%
                    royaltyPolicy: address(royaltyPolicyLAP),
                    currencyToken: address(mockToken)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: 100 * 10 ** mockToken.decimals(),
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 10 * 10 ** 6,
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(evenSplitGroupPool)
                })
            })
        );
    }

    modifier withNonCommercialParentIp() {
        {
            (ipIdParent, , ) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                licenseTermsData: nonCommTermsData,
                allowDuplicates: true
            });
        }
        _;
    }

    modifier withCommercialParentIp() {
        {
            (ipIdParent, , ) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                licenseTermsData: commTermsData,
                allowDuplicates: true
            });
        }
        _;
    }

    function test_DerivativeWorkflows_revert_DuplicatedNFTMetadataHash()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        // First, create an derivative with the same NFT metadata hash but with dedup turned off
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint32 revShare = pilTemplate.getLicenseTerms(licenseTermsIdParent).commercialRevShare;

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
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller,
            allowDuplicates: true
        });

        // Now attempt to create another derivative with the same NFT metadata hash but with dedup turned on
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SPGNFT__DuplicatedNFTMetadataHash.selector,
                address(nftContract),
                1,
                ipMetadataDefault.nftMetadataHash
            )
        );
        derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller,
            allowDuplicates: false
        });
    }

    function test_DerivativeWorkflows_revert_CallerNotSigner_registerIpAndMakeDerivative()
        public
        whenCallerHasMinterRole
        withCollection
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint32 revShare = pilTemplate.getLicenseTerms(licenseTermsIdParent).commercialRevShare;

        uint256 tokenIdChild = nftContract.mint({
            to: caller,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: true
        });
        address ipIdChild = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory signatureMetadataAndRegister, bytes32 expectedState, ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipIdChild,
            permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                ipIdChild,
                address(derivativeWorkflows),
                false
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        vm.startPrank(u.bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.DerivativeWorkflows__CallerNotSigner.selector, u.bob, u.alice));

        derivativeWorkflows.registerIpAndMakeDerivative({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: ipMetadataDefault,
            sigMetadataAndRegister: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signatureMetadataAndRegister
            })
        });
    }

    function test_DerivativeWorkflows_revert_CallerNotSigner_registerIpAndMakeDerivativeWithLicenseTokens()
        public
        whenCallerHasMinterRole
        withCollection
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint32 revShare = pilTemplate.getLicenseTerms(licenseTermsIdParent).commercialRevShare;

        uint256 tokenIdChild = nftContract.mint({
            to: caller,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: true
        });
        address ipIdChild = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild);

        uint256 deadline = block.timestamp + 1000;

        uint256 startLicenseTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipIdParent,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: licenseTermsIdParent,
            amount: 1,
            receiver: caller,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;
        licenseToken.approve(address(derivativeWorkflows), startLicenseTokenId);

        (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipIdChild,
            permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                ipIdChild,
                address(derivativeWorkflows),
                true
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        vm.startPrank(u.bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.DerivativeWorkflows__CallerNotSigner.selector, u.bob, u.alice));

        derivativeWorkflows.registerIpAndMakeDerivativeWithLicenseTokens({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            maxRts: revShare,
            ipMetadata: ipMetadataDefault,
            sigMetadataAndRegister: WorkflowStructs.SignatureData({
                signer: caller,
                deadline: deadline,
                signature: signatureMetadataAndRegister
            })
        });
    }

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivative_withNonCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        _mintAndRegisterIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_registerIpAndMakeDerivative_withNonCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        _registerIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivative_withCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withCommercialParentIp
    {
        _mintAndRegisterIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_registerIpAndMakeDerivative_withCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withCommercialParentIp
    {
        _registerIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivativeWithLicenseTokens()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint32 revShare = pilTemplate.getLicenseTerms(licenseTermsIdParent).commercialRevShare;

        uint256 startLicenseTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipIdParent,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: licenseTermsIdParent,
            amount: 1,
            receiver: caller,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        // Need so that derivative workflows can transfer the license tokens
        licenseToken.setApprovalForAll(address(derivativeWorkflows), true);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        (address ipIdChild, uint256 tokenIdChild) = derivativeWorkflows
            .mintAndRegisterIpAndMakeDerivativeWithLicenseTokens({
                spgNftContract: address(nftContract),
                licenseTokenIds: licenseTokenIds,
                royaltyContext: "",
                maxRts: revShare,
                ipMetadata: ipMetadataDefault,
                recipient: caller,
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
        assertEq(tokenIdChild, 2);
        assertEq(nftContract.tokenURI(tokenIdChild), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipIdChild, ipMetadataDefault);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);
        assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);

        assertParentChild({
            parentIpId: ipIdParent,
            childIpId: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_DerivativeWorkflows_registerIpAndMakeDerivativeWithLicenseTokens()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint32 revShare = pilTemplate.getLicenseTerms(licenseTermsIdParent).commercialRevShare;

        uint256 tokenIdChild = nftContract.mint({
            to: caller,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: true
        });
        address ipIdChild = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild);

        uint256 deadline = block.timestamp + 1000;

        uint256 startLicenseTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipIdParent,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: licenseTermsIdParent,
            amount: 1,
            receiver: caller,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;
        licenseToken.approve(address(derivativeWorkflows), startLicenseTokenId);

        (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipIdChild,
            permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                ipIdChild,
                address(derivativeWorkflows),
                true
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        address ipIdChildActual = derivativeWorkflows.registerIpAndMakeDerivativeWithLicenseTokens({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            maxRts: revShare,
            ipMetadata: ipMetadataDefault,
            sigMetadataAndRegister: WorkflowStructs.SignatureData({
                signer: caller,
                deadline: deadline,
                signature: signatureMetadataAndRegister
            })
        });
        assertEq(ipIdChildActual, ipIdChild);
        assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
        assertMetadata(ipIdChild, ipMetadataDefault);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);

        assertParentChild({
            parentIpId: ipIdParent,
            childIpId: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_SPG_multicall_mintAndRegisterIpAndMakeDerivative()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint32 revShare = pilTemplate.getLicenseTerms(licenseTermsIdParent).commercialRevShare;

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "mintAndRegisterIpAndMakeDerivative(address,(address[],address,uint256[],bytes,uint256,uint32,uint32),(string,bytes32,string,bytes32),address,bool)"
                    )
                ),
                address(nftContract),
                WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0,
                    maxRts: revShare,
                    maxRevenueShare: 0
                }),
                ipMetadataDefault,
                caller,
                true
            );
        }

        bytes[] memory results = derivativeWorkflows.multicall(data);

        for (uint256 i = 0; i < 10; i++) {
            (address ipIdChild, uint256 tokenIdChild) = abi.decode(results[i], (address, uint256));
            assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
            assertEq(tokenIdChild, i + 2);
            assertEq(nftContract.tokenURI(tokenIdChild), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
            assertMetadata(ipIdChild, ipMetadataDefault);
            (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
                ipIdChild,
                0
            );
            assertEq(licenseTemplateChild, licenseTemplateParent);
            assertEq(licenseTermsIdChild, licenseTermsIdParent);
            assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);
            assertParentChild({
                parentIpId: ipIdParent,
                childIpId: ipIdChild,
                expectedParentCount: 1,
                expectedParentIndex: 0
            });
        }
    }

    function _mintAndRegisterIpAndMakeDerivativeBaseTest() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint32 revShare = pilTemplate.getLicenseTerms(licenseTermsIdParent).commercialRevShare;

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
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller,
            allowDuplicates: true
        });
        assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
        assertEq(tokenIdChild, 2);
        assertEq(nftContract.tokenURI(tokenIdChild), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipIdChild, ipMetadataDefault);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);
        assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);

        assertParentChild({
            parentIpId: ipIdParent,
            childIpId: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function _registerIpAndMakeDerivativeBaseTest() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint32 revShare = pilTemplate.getLicenseTerms(licenseTermsIdParent).commercialRevShare;

        uint256 tokenIdChild = nftContract.mint({
            to: caller,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: true
        });
        address ipIdChild = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory signatureMetadataAndRegister, bytes32 expectedState, ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipIdChild,
            permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                ipIdChild,
                address(derivativeWorkflows),
                false
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        address ipIdChildActual = derivativeWorkflows.registerIpAndMakeDerivative({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: ipMetadataDefault,
            sigMetadataAndRegister: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signatureMetadataAndRegister
            })
        });
        assertEq(ipIdChildActual, ipIdChild);
        assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
        assertEq(nftContract.tokenURI(tokenIdChild), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipIdChild, ipMetadataDefault);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);
        assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);

        assertParentChild({
            parentIpId: ipIdParent,
            childIpId: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_DerivativeWorkflows_revert_ParentIpIdsAndLicenseTermsIdsMismatch()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withCommercialParentIp
    {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint32 revShare = pilTemplate.getLicenseTerms(licenseTermsIdParent).commercialRevShare;

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = licenseTermsIdParent;
        licenseTermsIds[1] = licenseTermsIdParent;

        vm.expectRevert(
            abi.encodeWithSelector(LicensingHelper.LicensingHelper__ParentIpIdsAndLicenseTermsIdsMismatch.selector)
        );
        derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller,
            allowDuplicates: true
        });
    }
}
