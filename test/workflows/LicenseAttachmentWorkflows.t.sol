//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
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

contract LicenseAttachmentWorkflowsTest is BaseTest {
    using Strings for uint256;

    struct IPAsset {
        address payable ipId;
        uint256 tokenId;
        address owner;
    }

    mapping(uint256 index => IPAsset) internal ipAsset;

    WorkflowStructs.LicenseTermsData[] internal commTermsData;
    PILTerms[] private terms;

    function setUp() public override {
        super.setUp();
        _setUpLicenseTermsData();
        _setUpTerms();
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
            licenseTermsData: commTermsData,
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
            licenseTermsData: commTermsData,
            allowDuplicates: false
        });
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach() public withCollection withIp(u.alice) {
        address payable ipId = ipAsset[1].ipId;
        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getAttachTermsAndConfigPermissionList(ipId, address(licenseAttachmentWorkflows)),
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        uint256 ltAmt = pilTemplate.totalRegisteredLicenseTerms();

        uint256[] memory licenseTermsIds = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signature
            })
        });
        _assertAttachedLicenseTerms(ipId, licenseTermsIds);
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
                licenseTermsData: commTermsData,
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, 1);
        assertEq(nftContract.tokenURI(tokenId1), string.concat(testBaseURI, tokenId1.toString()));
        assertMetadata(ipId1, ipMetadataEmpty);
        _assertAttachedLicenseTerms(ipId1, licenseTermsIds1);

        (address ipId2, uint256 tokenId2, uint256[] memory licenseTermsIds2) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                licenseTermsData: commTermsData,
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(tokenId2, 2);
        assertEq(nftContract.tokenURI(tokenId2), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipId2, ipMetadataDefault);
        _assertAttachedLicenseTerms(ipId2, licenseTermsIds2);
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

        (bytes memory sigMetadataAndAttachAndConfig, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getMetadataAndAttachTermsAndConfigPermissionList(
                ipId,
                address(licenseAttachmentWorkflows)
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        (, uint256[] memory licenseTermsIds) = licenseAttachmentWorkflows.registerIpAndAttachPILTerms({
            nftContract: address(nftContract),
            tokenId: tokenId,
            ipMetadata: ipMetadataDefault,
            licenseTermsData: commTermsData,
            sigMetadataAndAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: sigMetadataAndAttachAndConfig
            })
        });

        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertMetadata(ipId, ipMetadataDefault);
        _assertAttachedLicenseTerms(ipId, licenseTermsIds);
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach_idempotency()
        public
        withCollection
        withIp(u.alice)
    {
        address payable ipId = ipAsset[1].ipId;
        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature1, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getAttachTermsAndConfigPermissionList(ipId, address(licenseAttachmentWorkflows)),
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        uint256[] memory licenseTermsIds1 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signature1
            })
        });

        (bytes memory signature2, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getAttachTermsAndConfigPermissionList(ipId, address(licenseAttachmentWorkflows)),
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        // attach the same license terms to the IP again, but it shouldn't revert
        uint256[] memory licenseTermsIds2 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signature2
            })
        });

        for (uint256 i = 0; i < licenseTermsIds1.length; i++) {
            assertEq(licenseTermsIds1[i], licenseTermsIds2[i]);
        }
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach_revert_DerivativesCannotAddLicenseTerms()
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
                licenseTermsData: commTermsData,
                allowDuplicates: true
            });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdsParent[3];

        mockToken.mint(address(caller), 100 * 10 ** mockToken.decimals());
        mockToken.approve(address(derivativeWorkflows), 100 * 10 ** mockToken.decimals());
        (address ipIdChild, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: 0, // non-commercial remixing does not require royalty tokens
                maxRevenueShare: 0
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller,
            allowDuplicates: true
        });

        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipIdChild,
            permissionList: _getAttachTermsAndConfigPermissionList(ipIdChild, address(licenseAttachmentWorkflows)),
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        // attach a different license terms to the child ip, should revert with the correct error
        vm.expectRevert(CoreErrors.LicensingModule__DerivativesCannotAddLicenseTerms.selector);
        licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipIdChild,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signature
            })
        });
    }

    function test_LicenseAttachmentWorkflows_revert_NoLicenseData() public {
        vm.expectRevert(Errors.LicenseAttachmentWorkflows__NoLicenseTermsData.selector);
        licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipAsset[1].ipId,
            licenseTermsData: new WorkflowStructs.LicenseTermsData[](0),
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: block.timestamp + 1000,
                signature: new bytes(0)
            })
        });

        vm.expectRevert(Errors.LicenseAttachmentWorkflows__NoLicenseTermsData.selector);
        licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            licenseTermsData: new WorkflowStructs.LicenseTermsData[](0),
            allowDuplicates: true
        });

        vm.expectRevert(Errors.LicenseAttachmentWorkflows__NoLicenseTermsData.selector);
        licenseAttachmentWorkflows.registerIpAndAttachPILTerms({
            nftContract: address(nftContract),
            tokenId: 0,
            ipMetadata: ipMetadataDefault,
            licenseTermsData: new WorkflowStructs.LicenseTermsData[](0),
            sigMetadataAndAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: block.timestamp + 1000,
                signature: new bytes(0)
            })
        });
    }

    function test_LicenseAttachmentWorkflows_mintAndRegisterIpAndAttachDefaultTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipId1, uint256 tokenId1) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachDefaultTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataEmpty,
            allowDuplicates: true
        });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, 1);
        assertEq(nftContract.tokenURI(tokenId1), string.concat(testBaseURI, tokenId1.toString()));
        assertMetadata(ipId1, ipMetadataEmpty);
        uint256[] memory licenseTemplates = new uint256[](1);
        (, licenseTemplates[0]) = licenseRegistry.getDefaultLicenseTerms();
        (, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(licenseTermsId, licenseTemplates[0]);
    }

    function test_LicenseAttachmentWorkflows_registerIpAndAttachDefaultTerms()
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

        (bytes memory sigMetadataAndDefaultTerms, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getMetadataAndDefaultTermsPermissionList(ipId, address(licenseAttachmentWorkflows)),
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        licenseAttachmentWorkflows.registerIpAndAttachDefaultTerms({
            nftContract: address(nftContract),
            tokenId: tokenId,
            ipMetadata: ipMetadataDefault,
            sigMetadataAndDefaultTerms: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: sigMetadataAndDefaultTerms
            })
        });

        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertMetadata(ipId, ipMetadataDefault);
        uint256[] memory licenseTemplates = new uint256[](1);
        (, licenseTemplates[0]) = licenseRegistry.getDefaultLicenseTerms();
        (, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
        assertEq(licenseTermsId, licenseTemplates[0]);
    }

    function _assertAttachedLicenseTerms(address ipId, uint256[] memory licenseTermsIds) internal {
        for (uint256 i = 0; i < commTermsData.length; i++) {
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, i);
            assertEq(licenseTemplate, address(pilTemplate));
            assertEq(licenseTermsId, licenseTermsIds[i]);
            assertEq(pilTemplate.getLicenseTermsId(commTermsData[i].terms), licenseTermsIds[i]);
            Licensing.LicensingConfig memory licensingConfig = licenseRegistry.getLicensingConfig(
                ipId,
                licenseTemplate,
                licenseTermsId
            );
            assertEq(licensingConfig.isSet, commTermsData[i].licensingConfig.isSet);
            assertEq(licensingConfig.mintingFee, commTermsData[i].licensingConfig.mintingFee);
            assertEq(licensingConfig.licensingHook, commTermsData[i].licensingConfig.licensingHook);
            assertEq(licensingConfig.hookData, commTermsData[i].licensingConfig.hookData);
            assertEq(licensingConfig.commercialRevShare, commTermsData[i].licensingConfig.commercialRevShare);
            assertEq(licensingConfig.disabled, commTermsData[i].licensingConfig.disabled);
            assertEq(licensingConfig.expectGroupRewardPool, commTermsData[i].licensingConfig.expectGroupRewardPool);
            assertEq(
                licensingConfig.expectMinimumGroupRewardShare,
                commTermsData[i].licensingConfig.expectMinimumGroupRewardShare
            );
        }
    }

    function _setUpLicenseTermsData() internal {
        uint256 testMintFee = 100 * 10 ** mockToken.decimals();

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialUse({
                    mintingFee: testMintFee,
                    currencyToken: address(mockToken),
                    royaltyPolicy: address(royaltyPolicyLAP)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
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
                terms: PILFlavors.commercialUse({
                    mintingFee: testMintFee,
                    currencyToken: address(mockToken),
                    royaltyPolicy: address(royaltyPolicyLRP)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
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
                    mintingFee: testMintFee,
                    commercialRevShare: 5_000_000, // 5%
                    royaltyPolicy: address(royaltyPolicyLRP),
                    currencyToken: address(mockToken)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 5_000_000, // 5%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(evenSplitGroupPool)
                })
            })
        );

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: testMintFee,
                    commercialRevShare: 8_000_000, // 8%
                    royaltyPolicy: address(royaltyPolicyLAP),
                    currencyToken: address(mockToken)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 8_000_000, // 8%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(evenSplitGroupPool)
                })
            })
        );
    }

    ////////////////////////////////////////////////////////////////////////////
    //                              DEPRECATED                                //
    ////////////////////////////////////////////////////////////////////////////

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach_DEPR() public withCollection withIp(u.alice) {
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

        uint256[] memory licenseTermsIds = licenseAttachmentWorkflows.registerPILTermsAndAttach_deprecated({
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

    function test_LicenseAttachmentWorkflows_mintAndRegisterIpAndAttachPILTerms_DEPR()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipId1, uint256 tokenId1, uint256[] memory licenseTermsIds1) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms_deprecated({
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
            .mintAndRegisterIpAndAttachPILTerms_deprecated({
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

    function test_LicenseAttachmentWorkflows_registerIpAndAttachPILTerms_DEPR()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        uint256 tokenId = nftContract.mint(address(caller), ipMetadataEmpty.nftMetadataURI, "", true);
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

        licenseAttachmentWorkflows.registerIpAndAttachPILTerms_deprecated({
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

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach_idempotency_DEPR()
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

        uint256[] memory licenseTermsIds1 = licenseAttachmentWorkflows.registerPILTermsAndAttach_deprecated({
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
        uint256[] memory licenseTermsIds2 = licenseAttachmentWorkflows.registerPILTermsAndAttach_deprecated({
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

    function test_revert_registerPILTermsAndAttach_DerivativesCannotAddLicenseTerms_DEPR()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipIdParent, , uint256[] memory licenseTermsIdsParent) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms_deprecated({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                terms: terms
            });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdsParent[0];

        (address ipIdChild, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative_deprecated({
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
        licenseAttachmentWorkflows.registerPILTermsAndAttach_deprecated({
            ipId: ipIdChild,
            terms: terms,
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature })
        });
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach_SingleTerms_DEPR()
        public
        withCollection
        withIp(u.alice)
    {
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

        uint256 licenseTermsId = licenseAttachmentWorkflows.registerPILTermsAndAttach_deprecated({
            ipId: ipId,
            terms: PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            }),
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature })
        });

        assertEq(licenseTermsId, ltAmt + 1);
    }

    function test_LicenseAttachmentWorkflows_mintAndRegisterIpAndAttachPILTerms_SingleTerms_DEPR()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipId1, uint256 tokenId1, uint256 licenseTermsId1) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms_deprecated({
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
            .mintAndRegisterIpAndAttachPILTerms_deprecated({
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

    function test_LicenseAttachmentWorkflows_registerIpAndAttachPILTerms_SingleTerms_DEPR()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        uint256 tokenId = nftContract.mint(address(caller), ipMetadataEmpty.nftMetadataURI, "", true);
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

        licenseAttachmentWorkflows.registerIpAndAttachPILTerms_deprecated({
            nftContract: address(nftContract),
            tokenId: tokenId,
            ipMetadata: ipMetadataDefault,
            terms: PILFlavors.nonCommercialSocialRemixing(),
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigMetadata }),
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigAttach })
        });
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach_idempotency_SingleTerms_DEPR()
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

        uint256 licenseTermsId1 = licenseAttachmentWorkflows.registerPILTermsAndAttach_deprecated({
            ipId: ipId,
            terms: PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            }),
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

        // attach the same license terms to the IP again, but it shouldn't revert
        uint256 licenseTermsId2 = licenseAttachmentWorkflows.registerPILTermsAndAttach_deprecated({
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

    function test_revert_registerPILTermsAndAttach_DerivativesCannotAddLicenseTerms_SingleTerms_DEPR()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipIdParent, , uint256 licenseTermsIdParent) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms_deprecated({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                terms: PILFlavors.nonCommercialSocialRemixing()
            });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        (address ipIdChild, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative_deprecated({
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

        // attach a different license terms to the child ip, should revert with the correct error
        vm.expectRevert(CoreErrors.LicensingModule__DerivativesCannotAddLicenseTerms.selector);
        licenseAttachmentWorkflows.registerPILTermsAndAttach_deprecated({
            ipId: ipIdChild,
            terms: PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            }),
            sigAttach: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: signature })
        });
    }

    function _setUpTerms() private {
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
                royaltyPolicy: address(royaltyPolicyLAP)
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
}
