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

        WorkflowStructs.SignatureData memory sigMetadata;
        WorkflowStructs.SignatureData memory sigRegister;
        {
            (bytes memory signatureMetadata, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
                ipId: ipIdChild,
                to: address(derivativeWorkflows),
                module: address(coreMetadataModule),
                selector: ICoreMetadataModule.setAll.selector,
                deadline: deadline,
                state: bytes32(0),
                signerSk: sk.alice
            });
            (bytes memory signatureRegister, , ) = _getSetPermissionSigForPeriphery({
                ipId: ipIdChild,
                to: address(derivativeWorkflows),
                module: address(licensingModule),
                selector: ILicensingModule.registerDerivativeWithLicenseTokens.selector,
                deadline: deadline,
                state: expectedState,
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

        address ipIdChildActual = derivativeWorkflows.registerIpAndMakeDerivativeWithLicenseTokens({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            maxRts: revShare,
            ipMetadata: ipMetadataDefault,
            sigMetadata: sigMetadata,
            sigRegister: sigRegister
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

        (bytes memory sigMetadata, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: ipIdChild,
            to: address(derivativeWorkflows),
            module: address(coreMetadataModule),
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });
        (bytes memory sigRegister, , ) = _getSetPermissionSigForPeriphery({
            ipId: ipIdChild,
            to: address(derivativeWorkflows),
            module: address(licensingModule),
            selector: ILicensingModule.registerDerivative.selector,
            deadline: deadline,
            state: expectedState,
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
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigMetadata }),
            sigRegister: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigRegister })
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

    ////////////////////////////////////////////////////////////////////////////
    //                   DEPRECATED, WILL BE REMOVED IN V1.4                  //
    ////////////////////////////////////////////////////////////////////////////

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivative_withNonCommercialLicense_DEPR()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        _mintAndRegisterIpAndMakeDerivativeBaseTest_DEPR();
    }

    function test_DerivativeWorkflows_registerIpAndMakeDerivative_withNonCommercialLicense_DEPR()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        _registerIpAndMakeDerivativeBaseTest_DEPR();
    }

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivative_withCommercialLicense_DEPR()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withCommercialParentIp
    {
        _mintAndRegisterIpAndMakeDerivativeBaseTest_DEPR();
    }

    function test_DerivativeWorkflows_registerIpAndMakeDerivative_withCommercialLicense_DEPR()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withCommercialParentIp
    {
        _registerIpAndMakeDerivativeBaseTest_DEPR();
    }

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivativeWithLicenseTokens_DEPR()
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
                ipMetadata: ipMetadataDefault,
                recipient: caller
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

    function test_DerivativeWorkflows_registerIpAndMakeDerivativeWithLicenseTokens_DEPR()
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

        uint256 tokenIdChild = nftContract.mint(
            caller,
            ipMetadataDefault.nftMetadataURI,
            ipMetadataDefault.nftMetadataHash,
            true
        );
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

        (bytes memory sigMetadata, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: ipIdChild,
            to: address(derivativeWorkflows),
            module: address(coreMetadataModule),
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });
        (bytes memory sigRegister, , ) = _getSetPermissionSigForPeriphery({
            ipId: ipIdChild,
            to: address(derivativeWorkflows),
            module: address(licensingModule),
            selector: ILicensingModule.registerDerivativeWithLicenseTokens.selector,
            deadline: deadline,
            state: expectedState,
            signerSk: sk.alice
        });

        address ipIdChildActual = derivativeWorkflows.registerIpAndMakeDerivativeWithLicenseTokens({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            ipMetadata: ipMetadataDefault,
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigMetadata }),
            sigRegister: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigRegister })
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

    function test_SPG_multicall_mintAndRegisterIpAndMakeDerivative_DEPR()
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
        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "mintAndRegisterIpAndMakeDerivative(address,(address[],address,uint256[],bytes),(string,bytes32,string,bytes32),address)"
                    )
                ),
                address(nftContract),
                WorkflowStructs.MakeDerivativeDEPR({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: ""
                }),
                ipMetadataDefault,
                caller
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

    function _mintAndRegisterIpAndMakeDerivativeBaseTest_DEPR() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        (address ipIdChild, uint256 tokenIdChild) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: WorkflowStructs.MakeDerivativeDEPR({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: ""
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller
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

    function _registerIpAndMakeDerivativeBaseTest_DEPR() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint256 tokenIdChild = nftContract.mint(
            address(caller),
            ipMetadataDefault.nftMetadataURI,
            ipMetadataDefault.nftMetadataHash,
            true
        );
        address ipIdChild = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadata, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: ipIdChild,
            to: address(derivativeWorkflows),
            module: address(coreMetadataModule),
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });
        (bytes memory sigRegister, , ) = _getSetPermissionSigForPeriphery({
            ipId: ipIdChild,
            to: address(derivativeWorkflows),
            module: address(licensingModule),
            selector: ILicensingModule.registerDerivative.selector,
            deadline: deadline,
            state: expectedState,
            signerSk: sk.alice
        });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        address ipIdChildActual = derivativeWorkflows.registerIpAndMakeDerivative({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            derivData: WorkflowStructs.MakeDerivativeDEPR({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: ""
            }),
            ipMetadata: ipMetadataDefault,
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigMetadata }),
            sigRegister: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigRegister })
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
}
