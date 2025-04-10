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

        vm.startPrank(u.alice);
        uint256[] memory licenseTermsIds = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signature
            })
        });
        vm.stopPrank();
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

        vm.startPrank(u.alice);
        uint256[] memory licenseTermsIds1 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signature1
            })
        });
        vm.stopPrank();

        (bytes memory signature2, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getAttachTermsAndConfigPermissionList(ipId, address(licenseAttachmentWorkflows)),
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        // attach the same license terms to the IP again, but it shouldn't revert
        vm.startPrank(u.alice);
        uint256[] memory licenseTermsIds2 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signature2
            })
        });
        vm.stopPrank();

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
            state: IIPAccount(payable(ipIdChild)).state(),
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

    function test_LicenseAttachmentWorkflows_mintAndRegisterIpAndAttachPILTerms_withRegistrationFee()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        vm.stopPrank();

        uint96 registrationFee = 1 ether;
        address treasury = address(0x12345);

        vm.prank(u.admin);
        ipAssetRegistry.setRegistrationFee(treasury, address(mockToken), registrationFee);

        uint256 treasuryBalanceBefore = mockToken.balanceOf(treasury);
        uint256 callerBalanceBefore = mockToken.balanceOf(caller);

        vm.prank(caller);
        licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataEmpty,
            licenseTermsData: commTermsData,
            allowDuplicates: true
        });

        assertEq(mockToken.balanceOf(treasury), treasuryBalanceBefore + registrationFee);
        assertEq(mockToken.balanceOf(caller), callerBalanceBefore - registrationFee - nftContract.mintFee());
    }

    function test_LicenseAttachmentWorkflows_registerIpAndAttachPILTerms_withRegistrationFee()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        vm.stopPrank();

        uint96 registrationFee = 1 ether;
        address treasury = address(0x12345);

        vm.prank(u.admin);
        ipAssetRegistry.setRegistrationFee(treasury, address(mockToken), registrationFee);

        vm.prank(caller);
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

        vm.startPrank(caller);

        uint256 callerBalanceBefore = mockToken.balanceOf(caller);
        uint256 treasuryBalanceBefore = mockToken.balanceOf(treasury);

        licenseAttachmentWorkflows.registerIpAndAttachPILTerms({
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

        assertEq(mockToken.balanceOf(treasury), treasuryBalanceBefore + registrationFee);
        assertEq(mockToken.balanceOf(caller), callerBalanceBefore - registrationFee);
    }

    function test_LicenseAttachmentWorkflows_mintAndRegisterIpAndAttachDefaultTerms_withRegistrationFee()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        vm.stopPrank();

        uint96 registrationFee = 1 ether;
        address treasury = address(0x12345);

        vm.prank(u.admin);
        ipAssetRegistry.setRegistrationFee(treasury, address(mockToken), registrationFee);

        uint256 callerBalanceBefore = mockToken.balanceOf(caller);
        uint256 treasuryBalanceBefore = mockToken.balanceOf(treasury);

        vm.prank(caller);
        licenseAttachmentWorkflows.mintAndRegisterIpAndAttachDefaultTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataEmpty,
            allowDuplicates: true
        });

        assertEq(mockToken.balanceOf(treasury), treasuryBalanceBefore + registrationFee);
        assertEq(mockToken.balanceOf(caller), callerBalanceBefore - registrationFee - nftContract.mintFee());
    }

    function test_LicenseAttachmentWorkflows_registerIpAndAttachDefaultTerms_withRegistrationFee()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        vm.stopPrank();

        uint96 registrationFee = 1 ether;
        address treasury = address(0x12345);

        vm.prank(u.admin);
        ipAssetRegistry.setRegistrationFee(treasury, address(mockToken), registrationFee);

        vm.prank(caller);
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

        uint256 callerBalanceBefore = mockToken.balanceOf(caller);
        uint256 treasuryBalanceBefore = mockToken.balanceOf(treasury);

        vm.prank(caller);
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

        assertEq(mockToken.balanceOf(treasury), treasuryBalanceBefore + registrationFee);
        assertEq(mockToken.balanceOf(caller), callerBalanceBefore - registrationFee);
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
}
