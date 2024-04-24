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
            address(this),
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
}
