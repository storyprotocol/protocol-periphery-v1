// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { MetaTx } from "@storyprotocol/core/lib/MetaTx.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";

import { IStoryProtocolGateway as ISPG } from "../contracts/interfaces/IStoryProtocolGateway.sol";
import { ISPGNFT } from "../contracts/interfaces/ISPGNFT.sol";
import { Errors } from "../contracts/lib/Errors.sol";
import { SPGNFTLib } from "../contracts/lib/SPGNFTLib.sol";

import { BaseTest } from "./utils/BaseTest.t.sol";
import { MockERC721 } from "./mocks/MockERC721.sol";

contract StoryProtocolGatewayTest is BaseTest {
    struct IPAsset {
        address payable ipId;
        uint256 tokenId;
        address owner;
    }

    ISPGNFT internal nftContract;
    ISPGNFT[] internal nftContracts;
    address internal groupId;
    address internal minter;
    address internal caller;
    mapping(uint256 index => IPAsset) internal ipAsset;
    address internal ipIdParent;

    ISPG.IPMetadata internal ipMetadataEmpty;
    ISPG.IPMetadata internal ipMetadataDefault;

    function setUp() public override {
        super.setUp();
        minter = alice;

        ipMetadataEmpty = ISPG.IPMetadata({
            ipMetadataURI: "",
            ipMetadataHash: "",
            nftMetadataURI: "",
            nftMetadataHash: ""
        });
        ipMetadataDefault = ISPG.IPMetadata({
            ipMetadataURI: "test-ip-uri",
            ipMetadataHash: "test-ip-hash",
            nftMetadataURI: "test-nft-uri",
            nftMetadataHash: "test-nft-hash"
        });
    }

    modifier withCollection() {
        nftContract = ISPGNFT(
            spg.createCollection({
                name: "Test Collection",
                symbol: "TEST",
                maxSupply: 100,
                mintFee: 100 * 10 ** mockToken.decimals(),
                mintFeeToken: address(mockToken),
                owner: minter
            })
        );
        _;
    }

    function test_SPG_createCollection() public withCollection {
        uint256 mintFee = nftContract.mintFee();

        assertEq(nftContract.name(), "Test Collection");
        assertEq(nftContract.symbol(), "TEST");
        assertEq(nftContract.totalSupply(), 0);
        assertTrue(nftContract.hasRole(SPGNFTLib.MINTER_ROLE, alice));
        assertEq(mintFee, 100 * 10 ** mockToken.decimals());
    }

    modifier whenCallerDoesNotHaveMinterRole() {
        caller = bob;
        _;
    }

    function test_SPG_revert_mintAndRegisterIp_callerNotMinterRole()
        public
        withCollection
        whenCallerDoesNotHaveMinterRole
    {
        vm.expectRevert(Errors.SPG__CallerNotMinterRole.selector);
        vm.prank(caller);
        spg.mintAndRegisterIp({ spgNftContract: address(nftContract), recipient: bob, ipMetadata: ipMetadataEmpty });
    }

    modifier whenCallerHasMinterRole() {
        caller = alice;
        vm.startPrank(caller);
        _;
    }

    function test_SPG_mintAndRegisterIp() public withCollection whenCallerHasMinterRole {
        mockToken.mint(address(caller), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        (address ipId1, uint256 tokenId1) = spg.mintAndRegisterIp({
            spgNftContract: address(nftContract),
            recipient: bob,
            ipMetadata: ipMetadataEmpty
        });
        assertEq(tokenId1, 1);
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertSPGNFTMetadata(tokenId1, ipMetadataEmpty.nftMetadataURI);
        assertMetadata(ipId1, ipMetadataEmpty);

        (address ipId2, uint256 tokenId2) = spg.mintAndRegisterIp({
            spgNftContract: address(nftContract),
            recipient: bob,
            ipMetadata: ipMetadataDefault
        });
        assertEq(tokenId2, 2);
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertSPGNFTMetadata(tokenId2, ipMetadataDefault.nftMetadataURI);
        assertMetadata(ipId2, ipMetadataDefault);
    }

    function test_SPG_registerIp() public withCollection {
        MockERC721 nftContract = new MockERC721("Test NFT");
        uint256 tokenId = nftContract.mint(address(alice));
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadata, bytes32 expectedState, ) = _getSetPermissionSignatureForSPG({
            ipId: expectedIpId,
            module: address(coreMetadataModule),
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerPk: alicePk
        });

        address actualIpId = spg.registerIp({
            nftContract: address(nftContract),
            tokenId: tokenId,
            ipMetadata: ipMetadataDefault,
            sigMetadata: ISPG.SignatureData({ signer: alice, deadline: deadline, signature: sigMetadata })
        });

        assertEq(IIPAccount(payable(actualIpId)).state(), expectedState);
        assertEq(actualIpId, expectedIpId);
        assertTrue(ipAssetRegistry.isRegistered(actualIpId));
        assertMetadata(actualIpId, ipMetadataDefault);
    }

    modifier withIp(address owner) {
        vm.startPrank(owner);
        mockToken.mint(address(owner), 100 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 100 * 10 ** mockToken.decimals());
        (address ipId, uint256 tokenId) = spg.mintAndRegisterIp({
            spgNftContract: address(nftContract),
            recipient: owner,
            ipMetadata: ipMetadataDefault
        });
        ipAsset[1] = IPAsset({ ipId: payable(ipId), tokenId: tokenId, owner: owner });
        vm.stopPrank();
        _;
    }

    function test_SPG_registerPILTermsAndAttach() public withCollection withIp(alice) {
        address payable ipId = ipAsset[1].ipId;
        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature, , bytes memory data) = _getSetPermissionSignatureForSPG({
            ipId: ipId,
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerPk: alicePk
        });

        vm.prank(address(0x111));
        IIPAccount(ipId).executeWithSig({
            to: address(accessController),
            value: 0,
            data: data,
            signer: alice,
            deadline: deadline,
            signature: signature
        });

        uint256 ltAmt = pilTemplate.totalRegisteredLicenseTerms();

        uint256 licenseTermsId = spg.registerPILTermsAndAttach({
            ipId: ipAsset[1].ipId,
            terms: PILFlavors.nonCommercialSocialRemixing()
        });

        assertEq(licenseTermsId, ltAmt + 1);
    }

    modifier withEnoughTokens() {
        require(caller != address(0), "withEnoughTokens: caller not set");
        mockToken.mint(address(caller), 10000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 10000 * 10 ** mockToken.decimals());
        mockToken.approve(address(spg), 10000 * 10 ** mockToken.decimals());
        _;
    }

    function test_SPG_mintAndRegisterIpAndAttachPILTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
    {
        (address ipId1, uint256 tokenId1, uint256 licenseTermsId1) = spg.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataEmpty,
            terms: PILFlavors.nonCommercialSocialRemixing()
        });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, 1);
        assertEq(licenseTermsId1, 1);
        assertSPGNFTMetadata(tokenId1, ipMetadataEmpty.nftMetadataURI);
        assertMetadata(ipId1, ipMetadataEmpty);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, licenseTermsId1);

        (address ipId2, uint256 tokenId2, uint256 licenseTermsId2) = spg.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            terms: PILFlavors.nonCommercialSocialRemixing()
        });
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(tokenId2, 2);
        assertEq(licenseTermsId1, licenseTermsId2);
        assertSPGNFTMetadata(tokenId2, ipMetadataDefault.nftMetadataURI);
        assertMetadata(ipId2, ipMetadataDefault);
    }

    function test_SPG_registerIpAndAttachPILTerms() public withCollection whenCallerHasMinterRole withEnoughTokens {
        uint256 tokenId = nftContract.mint(address(caller), ipMetadataEmpty.nftMetadataURI);
        address payable ipId = payable(ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenId));

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadata, bytes32 expectedState, ) = _getSetPermissionSignatureForSPG({
            ipId: ipId,
            module: address(coreMetadataModule),
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerPk: alicePk
        });

        (bytes memory sigAttach, , ) = _getSetPermissionSignatureForSPG({
            ipId: ipId,
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: expectedState,
            signerPk: alicePk
        });

        spg.registerIpAndAttachPILTerms({
            nftContract: address(nftContract),
            tokenId: tokenId,
            ipMetadata: ipMetadataDefault,
            terms: PILFlavors.nonCommercialSocialRemixing(),
            sigMetadata: ISPG.SignatureData({ signer: alice, deadline: deadline, signature: sigMetadata }),
            sigAttach: ISPG.SignatureData({ signer: alice, deadline: deadline, signature: sigAttach })
        });
    }

    modifier withNonCommercialParentIp() {
        (ipIdParent, , ) = spg.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            terms: PILFlavors.nonCommercialSocialRemixing()
        });
        _;
    }

    function test_SPG_mintAndRegisterIpAndMakeDerivativeWithNonCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
        withNonCommercialParentIp
    {
        _mintAndRegisterIpAndMakeDerivativeBaseTest();
    }

    function test_SPG_registerIpAndMakeDerivativeWithNonCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
        withNonCommercialParentIp
    {
        _registerIpAndMakeDerivativeBaseTest();
    }

    modifier withCommercialParentIp() {
        (ipIdParent, , ) = spg.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            terms: PILFlavors.commercialUse({
                mintingFee: 100 * 10 ** mockToken.decimals(),
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        });
        _;
    }

    function test_SPG_mintAndRegisterIpAndMakeDerivativeWithCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
        withCommercialParentIp
    {
        _mintAndRegisterIpAndMakeDerivativeBaseTest();
    }

    function test_SPG_registerIpAndMakeDerivativeWithCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
        withCommercialParentIp
    {
        _registerIpAndMakeDerivativeBaseTest();
    }

    function test_SPG_mintAndRegisterIpAndMakeDerivativeWithLicenseTokens()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
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
            royaltyContext: ""
        });

        // Need so that SPG can transfer the license tokens
        licenseToken.setApprovalForAll(address(spg), true);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        (address ipIdChild, uint256 tokenIdChild) = spg.mintAndRegisterIpAndMakeDerivativeWithLicenseTokens({
            spgNftContract: address(nftContract),
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            ipMetadata: ipMetadataDefault,
            recipient: caller
        });
        assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
        assertEq(tokenIdChild, 2);
        assertSPGNFTMetadata(tokenIdChild, ipMetadataDefault.nftMetadataURI);
        assertMetadata(ipIdChild, ipMetadataDefault);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);
        assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);

        assertParentChild({
            ipIdParent: ipIdParent,
            ipIdChild: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_SPG_registerIpAndMakeDerivativeWithLicenseTokens()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
        withNonCommercialParentIp
    {
        caller = alice;
        vm.startPrank(caller);

        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint256 tokenIdChild = nftContract.mint(address(caller), ipMetadataEmpty.nftMetadataURI);
        address ipIdChild = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild);

        uint256 deadline = block.timestamp + 1000;

        uint256 startLicenseTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipIdParent,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: licenseTermsIdParent,
            amount: 1,
            receiver: caller,
            royaltyContext: ""
        });

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;
        licenseToken.approve(address(spg), startLicenseTokenId);

        (bytes memory sigMetadata, bytes32 expectedState, ) = _getSetPermissionSignatureForSPG({
            ipId: ipIdChild,
            module: address(coreMetadataModule),
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerPk: alicePk
        });
        (bytes memory sigRegister, , ) = _getSetPermissionSignatureForSPG({
            ipId: ipIdChild,
            module: address(licensingModule),
            selector: ILicensingModule.registerDerivativeWithLicenseTokens.selector,
            deadline: deadline,
            state: expectedState,
            signerPk: alicePk
        });

        address ipIdChildActual = spg.registerIpAndMakeDerivativeWithLicenseTokens({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            ipMetadata: ipMetadataDefault,
            sigMetadata: ISPG.SignatureData({ signer: alice, deadline: deadline, signature: sigMetadata }),
            sigRegister: ISPG.SignatureData({ signer: alice, deadline: deadline, signature: sigRegister })
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
            ipIdParent: ipIdParent,
            ipIdChild: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_SPG_multicall_createCollection() public {
        nftContracts = new ISPGNFT[](10);
        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSignature(
                "createCollection(string,string,uint32,uint256,address,address)",
                "Test Collection",
                "TEST",
                100,
                100 * 10 ** mockToken.decimals(),
                address(mockToken),
                minter
            );
        }

        bytes[] memory results = spg.multicall(data);
        for (uint256 i = 0; i < 10; i++) {
            nftContracts[i] = ISPGNFT(abi.decode(results[i], (address)));
        }

        for (uint256 i = 0; i < 10; i++) {
            assertEq(nftContracts[i].name(), "Test Collection");
            assertEq(nftContracts[i].symbol(), "TEST");
            assertEq(nftContracts[i].totalSupply(), 0);
            assertTrue(nftContracts[i].hasRole(SPGNFTLib.MINTER_ROLE, alice));
            assertEq(nftContracts[i].mintFee(), 100 * 10 ** mockToken.decimals());
        }
    }

    function test_SPG_multicall_mintAndRegisterIp() public withCollection whenCallerHasMinterRole {
        mockToken.mint(address(caller), 1000 * 10 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 * 10 ** mockToken.decimals());

        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                spg.mintAndRegisterIp.selector,
                address(nftContract),
                bob,
                ipMetadataDefault
            );
        }
        bytes[] memory results = spg.multicall(data);
        address[] memory ipIds = new address[](10);
        uint256[] memory tokenIds = new uint256[](10);

        for (uint256 i = 0; i < 10; i++) {
            (ipIds[i], tokenIds[i]) = abi.decode(results[i], (address, uint256));
            assertTrue(ipAssetRegistry.isRegistered(ipIds[i]));
            assertSPGNFTMetadata(tokenIds[i], ipMetadataDefault.nftMetadataURI);
            assertMetadata(ipIds[i], ipMetadataDefault);
        }
    }

    function test_SPG_multicall_mintAndRegisterIpAndMakeDerivative()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
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
                spg.mintAndRegisterIpAndMakeDerivative.selector,
                address(nftContract),
                ISPG.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: ""
                }),
                ipMetadataDefault,
                caller
            );
        }

        bytes[] memory results = spg.multicall(data);

        for (uint256 i = 0; i < 10; i++) {
            (address ipIdChild, uint256 tokenIdChild) = abi.decode(results[i], (address, uint256));
            assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
            assertEq(tokenIdChild, i + 2);
            assertSPGNFTMetadata(tokenIdChild, ipMetadataDefault.nftMetadataURI);
            assertMetadata(ipIdChild, ipMetadataDefault);
            (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
                ipIdChild,
                0
            );
            assertEq(licenseTemplateChild, licenseTemplateParent);
            assertEq(licenseTermsIdChild, licenseTermsIdParent);
            assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);
            assertParentChild({
                ipIdParent: ipIdParent,
                ipIdChild: ipIdChild,
                expectedParentCount: 1,
                expectedParentIndex: 0
            });
        }
    }

    modifier withGroup() {
        groupId = groupingModule.registerGroup(address(rewardPool));
        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature, , bytes memory data) = _getSetPermissionSignatureForSPG({
            ipId: groupId,
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerPk: alicePk
        });

        IIPAccount(payable(groupId)).executeWithSig({
            to: address(accessController),
            value: 0,
            data: data,
            signer: alice,
            deadline: deadline,
            signature: signature
        });

        uint256 licenseTermsId = spg.registerPILTermsAndAttach({
            ipId: groupId,
            terms: PILFlavors.nonCommercialSocialRemixing()
        });
        _;
    }

    function test_SPG_mintAndRegisterIpAndAddToGroup()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
        withGroup
    {
        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigAddToGroup, bytes32 expectedState, ) = _getSetPermissionSignatureForSPG({
            ipId: groupId,
            module: address(groupingModule),
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerPk: alicePk
        });

        (address ipId, uint256 tokenId) = spg.mintAndRegisterIpAndAttachPILTermsAndAddToGroup({
            spgNftContract: address(nftContract),
            groupId: groupId,
            recipient: caller,
            ipMetadata: ipMetadataEmpty,
            licenseTermsId: 1,
            sigAddToGroup: ISPG.SignatureData({ signer: alice, deadline: deadline, signature: sigAddToGroup })
        });

        assertEq(expectedState, IIPAccount(payable(groupId)).state());
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertTrue(ipAssetRegistry.isRegisteredGroup(groupId));
        assertTrue(ipAssetRegistry.containsIp(groupId, ipId));
        assertEq(ipAssetRegistry.totalMembers(groupId), 1);
        assertEq(tokenId, 1);
        assertSPGNFTMetadata(tokenId, ipMetadataEmpty.nftMetadataURI);
        assertMetadata(ipId, ipMetadataEmpty);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, 1);
    }

    function test_SPG_registerIpAndAddToGroup()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
        withGroup
    {
        uint256 tokenId = nftContract.mint(address(caller), ipMetadataEmpty.nftMetadataURI);
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadataAndAttach, , ) = _getSetBatchPermissionSignatureForSPG({
            ipId: expectedIpId,
            permissionList: _getMetadataAndAttachTermsPermissionList(expectedIpId),
            deadline: deadline,
            state: bytes32(0),
            signerPk: alicePk
        });

        (bytes memory sigAddToGroup, , ) = _getSetPermissionSignatureForSPG({
            ipId: groupId,
            module: address(groupingModule),
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerPk: alicePk
        });

        address ipId = spg.registerIpAndAttachPILTermsAndAddToGroup({
            nftContract: address(nftContract),
            tokenId: tokenId,
            groupId: groupId,
            ipMetadata: ipMetadataEmpty,
            licenseTermsId: 1,
            sigMetadataAndAttach: ISPG.SignatureData({
                signer: alice,
                deadline: deadline,
                signature: sigMetadataAndAttach
            }),
            sigAddToGroup: ISPG.SignatureData({ signer: alice, deadline: deadline, signature: sigAddToGroup })
        });

        assertEq(expectedIpId, ipId);
        assertTrue(ipAssetRegistry.isRegistered(expectedIpId));
        assertTrue(ipAssetRegistry.isRegisteredGroup(groupId));
        assertTrue(ipAssetRegistry.containsIp(groupId, expectedIpId));
        assertEq(ipAssetRegistry.totalMembers(groupId), 1);
        assertSPGNFTMetadata(tokenId, ipMetadataEmpty.nftMetadataURI);
        assertMetadata(expectedIpId, ipMetadataEmpty);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(expectedIpId, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, 1);
    }

    function test_SPG_registerGroupAndAddIps() public withCollection whenCallerHasMinterRole {
        mockToken.mint(address(caller), 1000 * 10 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 * 10 ** mockToken.decimals());

        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                spg.mintAndRegisterIpAndAttachPILTerms.selector,
                address(nftContract),
                bob,
                ipMetadataDefault,
                PILFlavors.nonCommercialSocialRemixing()
            );
        }
        bytes[] memory results = spg.multicall(data);
        address[] memory ipIds = new address[](10);

        for (uint256 i = 0; i < 10; i++) {
            (ipIds[i], ) = abi.decode(results[i], (address, uint256));
        }

        uint256 groupLicenseTermsId;
        (groupId, groupLicenseTermsId) = spg.registerGroupAndAttachPILTermsAndAddIps(
            address(rewardPool),
            ipIds,
            PILFlavors.nonCommercialSocialRemixing()
        );

        assertTrue(ipAssetRegistry.isRegisteredGroup(groupId));
        assertEq(groupLicenseTermsId, 1);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(groupId, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, groupLicenseTermsId);

        assertEq(ipAssetRegistry.totalMembers(groupId), 10);
        for (uint256 i = 0; i < 10; i++) {
            assertTrue(ipAssetRegistry.containsIp(groupId, ipIds[i]));
        }
    }

    /// @dev Assert metadata for the SPGNFT.
    function assertSPGNFTMetadata(uint256 tokenId, string memory expectedMetadata) internal {
        assertEq(nftContract.tokenURI(tokenId), expectedMetadata);
    }

    /// @dev Assert metadata for the IP.
    function assertMetadata(address ipId, ISPG.IPMetadata memory expectedMetadata) internal {
        assertEq(coreMetadataViewModule.getMetadataURI(ipId), expectedMetadata.ipMetadataURI);
        assertEq(coreMetadataViewModule.getMetadataHash(ipId), expectedMetadata.ipMetadataHash);
        assertEq(coreMetadataViewModule.getNftMetadataHash(ipId), expectedMetadata.nftMetadataHash);
    }

    /// @dev Assert parent and derivative relationship.
    function assertParentChild(
        address ipIdParent,
        address ipIdChild,
        uint256 expectedParentCount,
        uint256 expectedParentIndex
    ) internal {
        assertTrue(licenseRegistry.hasDerivativeIps(ipIdParent));
        assertTrue(licenseRegistry.isDerivativeIp(ipIdChild));
        assertTrue(licenseRegistry.isParentIp({ parentIpId: ipIdParent, childIpId: ipIdChild }));
        assertEq(licenseRegistry.getParentIpCount(ipIdChild), expectedParentCount);
        assertEq(licenseRegistry.getParentIp(ipIdChild, expectedParentIndex), ipIdParent);
    }

    /// @dev Get the signature for setting permission for the IP by the SPG.
    /// @param ipId The ID of the IP.
    /// @param module The address of the module to set the permission for.
    /// @param selector The selector of the function to be permitted for execution.
    /// @param deadline The deadline for the signature.
    /// @param state IPAccount's internal nonce
    /// @param signerPk The private key of the signer.
    /// @return signature The signature for setting the permission.
    /// @return expectedState The expected IPAccount's state after setting the permission.
    /// @return data The call data for executing the setPermission function.
    function _getSetPermissionSignatureForSPG(
        address ipId,
        address module,
        bytes4 selector,
        uint256 deadline,
        bytes32 state,
        uint256 signerPk
    ) internal view returns (bytes memory signature, bytes32 expectedState, bytes memory data) {
        expectedState = keccak256(
            abi.encode(
                state, // ipAccount.state()
                abi.encodeWithSelector(
                    IIPAccount.execute.selector,
                    address(accessController),
                    0, // amount of ether to send
                    abi.encodeWithSelector(
                        IAccessController.setPermission.selector,
                        ipId,
                        address(spg),
                        address(module),
                        selector,
                        AccessPermission.ALLOW
                    )
                )
            )
        );

        data = abi.encodeWithSelector(
            IAccessController.setPermission.selector,
            ipId,
            address(spg),
            address(module),
            selector,
            AccessPermission.ALLOW
        );

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(ipId),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(accessController),
                    value: 0,
                    data: data,
                    nonce: expectedState,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /// @dev Get the permission list for setting metadata and attaching license terms for the IP.
    /// @param ipId The ID of the IP that the permissions are for.
    /// @return permissionList The list of permissions for setting metadata and attaching license terms.
    function _getMetadataAndAttachTermsPermissionList(
        address ipId
    ) internal view returns (AccessPermission.Permission[] memory permissionList) {
        address[] memory modules = new address[](2);
        bytes4[] memory selectors = new bytes4[](2);
        permissionList = new AccessPermission.Permission[](modules.length);

        modules[0] = address(coreMetadataModule);
        modules[1] = address(licensingModule);
        selectors[0] = ICoreMetadataModule.setAll.selector;
        selectors[1] = ILicensingModule.attachLicenseTerms.selector;

        for (uint256 i = 0; i < 2; i++) {
            permissionList[i] = AccessPermission.Permission({
                ipAccount: ipId,
                signer: address(spg),
                to: modules[i],
                func: selectors[i],
                permission: AccessPermission.ALLOW
            });
        }
    }

    /// @dev Get the signature for setting batch permission for the IP by the SPG.
    /// @param ipId The ID of the IP to set the permissions for.
    /// @param permissionList A list of permissions to set.
    /// @param deadline The deadline for the signature.
    /// @param state IPAccount's internal state
    /// @param signerPk The private key of the signer.
    /// @return signature The signature for setting the batch permission.
    /// @return expectedState The expected IPAccount's state after setting batch permission.
    /// @return data The call data for executing the setBatchPermissions function.
    function _getSetBatchPermissionSignatureForSPG(
        address ipId,
        AccessPermission.Permission[] memory permissionList,
        uint256 deadline,
        bytes32 state,
        uint256 signerPk
    ) internal returns (bytes memory signature, bytes32 expectedState, bytes memory data) {
        assertEq(state, bytes32(0));
        expectedState = keccak256(
            abi.encode(
                state, // ipAccount.state()
                abi.encodeWithSelector(
                    IIPAccount.execute.selector,
                    address(accessController),
                    0, // amount of ether to send
                    abi.encodeWithSelector(IAccessController.setBatchPermissions.selector, permissionList)
                )
            )
        );

        data = abi.encodeWithSelector(IAccessController.setBatchPermissions.selector, permissionList);

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(ipId),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(accessController),
                    value: 0,
                    data: data,
                    nonce: expectedState,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _mintAndRegisterIpAndMakeDerivativeBaseTest() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        (address ipIdChild, uint256 tokenIdChild) = spg.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: ISPG.MakeDerivative({
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
        assertSPGNFTMetadata(tokenIdChild, ipMetadataDefault.nftMetadataURI);
        assertMetadata(ipIdChild, ipMetadataDefault);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);
        assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);

        assertParentChild({
            ipIdParent: ipIdParent,
            ipIdChild: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function _registerIpAndMakeDerivativeBaseTest() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint256 tokenIdChild = nftContract.mint(address(caller), ipMetadataEmpty.nftMetadataURI);
        address ipIdChild = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadata, bytes32 expectedState, ) = _getSetPermissionSignatureForSPG({
            ipId: ipIdChild,
            module: address(coreMetadataModule),
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerPk: alicePk
        });
        (bytes memory sigRegister, , ) = _getSetPermissionSignatureForSPG({
            ipId: ipIdChild,
            module: address(licensingModule),
            selector: ILicensingModule.registerDerivative.selector,
            deadline: deadline,
            state: expectedState,
            signerPk: alicePk
        });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        address ipIdChildActual = spg.registerIpAndMakeDerivative({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            derivData: ISPG.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: ""
            }),
            ipMetadata: ipMetadataDefault,
            sigMetadata: ISPG.SignatureData({ signer: alice, deadline: deadline, signature: sigMetadata }),
            sigRegister: ISPG.SignatureData({ signer: alice, deadline: deadline, signature: sigRegister })
        });
        assertEq(ipIdChildActual, ipIdChild);
        assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
        assertSPGNFTMetadata(tokenIdChild, ipMetadataEmpty.nftMetadataURI);
        assertMetadata(ipIdChild, ipMetadataDefault);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);
        assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);

        assertParentChild({
            ipIdParent: ipIdParent,
            ipIdChild: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }
}
