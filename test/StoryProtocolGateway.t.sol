// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { MetaTx } from "@storyprotocol/core/lib/MetaTx.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";

import { ISPGNFT } from "../contracts/interfaces/ISPGNFT.sol";
import { Errors } from "../contracts/lib/Errors.sol";
import { SPGNFTLib } from "../contracts/lib/SPGNFTLib.sol";

import { BaseTest } from "./utils/BaseTest.t.sol";

contract StoryProtocolGatewayTest is BaseTest {
    struct IPAsset {
        address payable ipId;
        uint256 tokenId;
        address owner;
    }

    ISPGNFT internal nftContract;
    address internal minter;
    address internal caller;
    mapping(uint256 index => IPAsset) internal ipAsset;

    function setUp() public override {
        super.setUp();
        minter = alice;
    }

    modifier withCollection() {
        nftContract = ISPGNFT(
            spg.createCollection({
                name: "Test Collection",
                symbol: "TEST",
                maxSupply: 100,
                mintCost: 100 * 10 ** mockToken.decimals(),
                mintToken: address(mockToken),
                owner: minter
            })
        );
        _;
    }

    function test_SPG_createCollection() public withCollection {
        uint256 mintCost = nftContract.mintCost();

        assertEq(nftContract.name(), "Test Collection");
        assertEq(nftContract.symbol(), "TEST");
        assertEq(nftContract.totalSupply(), 0);
        assertTrue(nftContract.hasRole(SPGNFTLib.MINTER_ROLE, alice));
        assertEq(mintCost, 100 * 10 ** mockToken.decimals());
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
        spg.mintAndRegisterIp({ nftContract: address(nftContract), recipient: bob });
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
            nftContract: address(nftContract),
            recipient: bob
        });
        assertEq(tokenId1, 1);
        assertTrue(ipAssetRegistry.isRegistered(ipId1));

        (address ipId2, uint256 tokenId2) = spg.mintAndRegisterIp({
            nftContract: address(nftContract),
            recipient: bob,
            metadataURI: "test-uri",
            metadataHash: "test-hash",
            nftMetadataHash: "test-nft-hash"
        });
        assertEq(tokenId2, 2);
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(coreMetadataViewModule.getMetadataURI(ipId2), "test-uri");
        assertEq(coreMetadataViewModule.getMetadataHash(ipId2), "test-hash");
        assertEq(coreMetadataViewModule.getNftMetadataHash(ipId2), "test-nft-hash");
    }

    modifier withIp(address owner) {
        vm.startPrank(owner);
        mockToken.mint(address(owner), 100 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 100 * 10 ** mockToken.decimals());
        (address ipId, uint256 tokenId) = spg.mintAndRegisterIp({
            nftContract: address(nftContract),
            recipient: owner
        });
        ipAsset[1] = IPAsset({ ipId: payable(ipId), tokenId: tokenId, owner: owner });
        vm.stopPrank();
        _;
    }

    function test_SPG_registerPILTermsAndAttach() public withCollection withIp(alice) {
        address payable ipId = ipAsset[1].ipId;
        uint256 deadline = block.timestamp + 1000;

        bytes memory data = abi.encodeWithSignature(
            "setPermission(address,address,address,bytes4,uint8)",
            ipId,
            address(spg),
            address(licensingModule),
            ILicensingModule.attachLicenseTerms.selector,
            AccessPermission.ALLOW
        );

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(ipId),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(accessController),
                    value: 0,
                    data: data,
                    nonce: IIPAccount(ipId).state() + 1,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

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

    function test_SPG_mintAndRegisterIpAndAttachPILTerms() public withCollection whenCallerHasMinterRole {
        mockToken.mint(address(caller), 200 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 200 * 10 ** mockToken.decimals());

        (address ipId1, uint256 tokenId1, uint256 licenseTermsId1) = spg.mintAndRegisterIpAndAttachPILTerms({
            nftContract: address(nftContract),
            recipient: caller,
            terms: PILFlavors.nonCommercialSocialRemixing()
        });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, 1);
        assertEq(licenseTermsId1, 1);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, licenseTermsId1);

        (address ipId2, uint256 tokenId2, uint256 licenseTermsId2) = spg.mintAndRegisterIpAndAttachPILTerms({
            nftContract: address(nftContract),
            recipient: caller,
            metadataURI: "test-uri",
            metadataHash: "test-hash",
            nftMetadataHash: "test-nft-hash",
            terms: PILFlavors.nonCommercialSocialRemixing()
        });
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(tokenId2, 2);
        assertEq(licenseTermsId1, licenseTermsId2);
        assertEq(coreMetadataViewModule.getMetadataURI(ipId2), "test-uri");
        assertEq(coreMetadataViewModule.getMetadataHash(ipId2), "test-hash");
        assertEq(coreMetadataViewModule.getNftMetadataHash(ipId2), "test-nft-hash");
    }

    function test_SPG_registerIpAndAttachPILTerms() public withCollection whenCallerHasMinterRole {
        mockToken.mint(address(caller), 200 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 200 * 10 ** mockToken.decimals());

        uint256 tokenId = nftContract.mint(address(caller));
        address payable ipId = payable(ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenId));
        ipAsset[1] = IPAsset({ ipId: ipId, tokenId: tokenId, owner: caller });

        uint256 deadline = block.timestamp + 1000;

        bytes memory data = abi.encodeWithSignature(
            "setPermission(address,address,address,bytes4,uint8)",
            ipId,
            address(spg),
            address(licensingModule),
            ILicensingModule.attachLicenseTerms.selector,
            AccessPermission.ALLOW
        );

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(ipId),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({ to: address(accessController), value: 0, data: data, nonce: 1, deadline: deadline })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        (address ipIdOut, uint256 licenseTermsIdOut) = spg.registerIpAndAttachPILTerms({
            nftContract: address(nftContract),
            tokenId: tokenId,
            terms: PILFlavors.nonCommercialSocialRemixing(),
            signer: alice,
            deadline: deadline,
            signature: signature
        });
    }

    function test_SPG_registerAndMakeDerivativeWithLicenseTokens() public withCollection whenCallerHasMinterRole {
        mockToken.mint(address(caller), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        (address ipIdParent, uint256 tokenIdParent, ) = spg.mintAndRegisterIpAndAttachPILTerms({
            nftContract: address(nftContract),
            recipient: caller,
            terms: PILFlavors.nonCommercialSocialRemixing()
        });
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

        licenseToken.setApprovalForAll(address(spg), true);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        (address ipIdChild, uint256 tokenIdChild) = spg.registerAndMakeDerivativeWithLicenseTokens({
            nftContract: address(nftContract),
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            recipient: caller
        });

        assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
        assertEq(tokenIdChild, 2);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);

        assertTrue(licenseRegistry.hasDerivativeIps(ipIdParent));
        assertTrue(licenseRegistry.isDerivativeIp(ipIdChild));
        assertTrue(licenseRegistry.isParentIp({ parentIpId: ipIdParent, childIpId: ipIdChild }));
        assertEq(licenseRegistry.getParentIpCount(ipIdChild), 1);
        assertEq(licenseRegistry.getParentIp(ipIdChild, 0), ipIdParent);
    }
}
