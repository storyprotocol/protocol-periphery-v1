// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// contracts
import { BaseStoryNFT } from "../../contracts/story-nft/BaseStoryNFT.sol";
import { IStoryBadgeNFT } from "../../contracts/interfaces/story-nft/IStoryBadgeNFT.sol";
import { IOrgStoryNFT } from "../../contracts/interfaces/story-nft/IOrgStoryNFT.sol";
import { IStoryNFT } from "../../contracts/interfaces/story-nft/IStoryNFT.sol";
import { StoryBadgeNFT } from "../../contracts/story-nft/StoryBadgeNFT.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";
import { TestProxyHelper } from "../utils/TestProxyHelper.t.sol";

contract StoryBadgeNFTTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_StoryBadgeNFT_initialize() public {
        address testStoryBadgeNftImpl = address(
            new StoryBadgeNFT({
                ipAssetRegistry: address(ipAssetRegistry),
                licensingModule: address(licensingModule),
                coreMetadataModule: address(coreMetadataModule),
                upgradeableBeacon: address(defaultOrgStoryNftBeacon),
                orgNft: address(orgNft),
                pilTemplate: address(pilTemplate),
                defaultLicenseTermsId: 1
            })
        );

        string memory tokenURI = "Test Token URI";

        bytes memory storyBadgeNftCustomInitParams = abi.encode(
            IStoryBadgeNFT.CustomInitParams({
                tokenURI: tokenURI,
                signer: rootOrgStoryNftSigner,
                ipMetadataURI: ipMetadataDefault.ipMetadataURI,
                ipMetadataHash: ipMetadataDefault.ipMetadataHash,
                nftMetadataHash: ipMetadataDefault.nftMetadataHash
            })
        );

        IStoryNFT.StoryNftInitParams memory storyBadgeNftInitParams = IStoryNFT.StoryNftInitParams({
            owner: rootOrgStoryNftOwner,
            name: "Test Badge",
            symbol: "TB",
            contractURI: "Test Contract URI",
            baseURI: "",
            customInitData: storyBadgeNftCustomInitParams
        });

        StoryBadgeNFT testStoryBadgeNft = StoryBadgeNFT(
            TestProxyHelper.deployUUPSProxy(
                testStoryBadgeNftImpl,
                abi.encodeCall(IOrgStoryNFT.initialize, (0, address(1), storyBadgeNftInitParams))
            )
        );

        assertEq(testStoryBadgeNft.ORG_NFT(), address(orgNft));
        assertEq(address(BaseStoryNFT(address(testStoryBadgeNft)).IP_ASSET_REGISTRY()), address(ipAssetRegistry));
        assertEq(address(BaseStoryNFT(address(testStoryBadgeNft)).LICENSING_MODULE()), address(licensingModule));
        assertEq(testStoryBadgeNft.PIL_TEMPLATE(), address(pilTemplate));
        assertEq(testStoryBadgeNft.DEFAULT_LICENSE_TERMS_ID(), 1);
        assertEq(testStoryBadgeNft.name(), "Test Badge");
        assertEq(testStoryBadgeNft.symbol(), "TB");
        assertEq(testStoryBadgeNft.contractURI(), "Test Contract URI");
        assertEq(testStoryBadgeNft.tokenURI(0), tokenURI);
        assertEq(testStoryBadgeNft.owner(), rootOrgStoryNftOwner);
        assertEq(testStoryBadgeNft.totalSupply(), 0);
        assertTrue(testStoryBadgeNft.locked(0));
    }

    function test_StoryBadgeNFT_revert_initialize_ZeroAddress() public {
        vm.expectRevert(IStoryNFT.StoryNFT__ZeroAddressParam.selector);
        StoryBadgeNFT testStoryBadgeNft = new StoryBadgeNFT(
            address(ipAssetRegistry),
            address(licensingModule),
            address(coreMetadataModule),
            address(defaultOrgStoryNftBeacon),
            address(0),
            address(pilTemplate),
            1
        );

        address testStoryBadgeNftImpl = address(
            new StoryBadgeNFT({
                ipAssetRegistry: address(ipAssetRegistry),
                licensingModule: address(licensingModule),
                coreMetadataModule: address(coreMetadataModule),
                upgradeableBeacon: address(defaultOrgStoryNftBeacon),
                orgNft: address(orgNft),
                pilTemplate: address(pilTemplate),
                defaultLicenseTermsId: 1
            })
        );

        string memory tokenURI = "Test Token URI";

        bytes memory storyBadgeNftCustomInitParams = abi.encode(
            IStoryBadgeNFT.CustomInitParams({
                tokenURI: tokenURI,
                signer: address(0), // Should revert
                ipMetadataURI: ipMetadataDefault.ipMetadataURI,
                ipMetadataHash: ipMetadataDefault.ipMetadataHash,
                nftMetadataHash: ipMetadataDefault.nftMetadataHash
            })
        );

        IStoryNFT.StoryNftInitParams memory storyBadgeNftInitParams = IStoryNFT.StoryNftInitParams({
            owner: rootOrgStoryNftOwner,
            name: "Test Badge",
            symbol: "TB",
            contractURI: "Test Contract URI",
            baseURI: "",
            customInitData: storyBadgeNftCustomInitParams
        });

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__ZeroAddressParam.selector);
        testStoryBadgeNft = StoryBadgeNFT(
            TestProxyHelper.deployUUPSProxy(
                testStoryBadgeNftImpl,
                abi.encodeCall(IOrgStoryNFT.initialize, (0, address(1), storyBadgeNftInitParams))
            )
        );
    }

    function test_StoryBadgeNFT_interfaceSupport() public {
        assertTrue(BaseStoryNFT(rootOrgStoryNft).supportsInterface(type(IOrgStoryNFT).interfaceId));
        assertTrue(BaseStoryNFT(rootOrgStoryNft).supportsInterface(type(IERC721).interfaceId));
        assertTrue(BaseStoryNFT(rootOrgStoryNft).supportsInterface(type(IERC721Metadata).interfaceId));
    }

    function test_StoryBadgeNFT_mint() public {
        bytes memory signature = _signAddress(rootOrgStoryNftSignerSk, u.carl);

        uint256 totalSupplyBefore = rootOrgStoryNft.totalSupply();
        vm.startPrank(u.carl);
        (uint256 tokenId, address ipId) = rootOrgStoryNft.mint(u.carl, signature);
        vm.stopPrank();

        assertEq(rootOrgStoryNft.ownerOf(tokenId), u.carl);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(rootOrgStoryNft.tokenURI(tokenId), "Test Token URI");
        assertMetadata(ipId, ipMetadataDefault);
        assertEq(rootOrgStoryNft.totalSupply(), totalSupplyBefore + 1);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            rootOrgStoryNft.orgIpId(),
            0
        );
        assertEq(licenseTemplateParent, licenseTemplateChild);
        assertEq(licenseTermsIdParent, licenseTermsIdChild);
        assertEq(IIPAccount(payable(ipId)).owner(), u.carl);

        assertParentChild({
            parentIpId: rootOrgStoryNft.orgIpId(),
            childIpId: ipId,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_StoryBadgeNFT_setContractURI() public {
        string memory oldContractURI = rootOrgStoryNft.contractURI();
        string memory newContractURI = "New Contract URI";

        assertNotEq(oldContractURI, newContractURI);

        vm.startPrank(rootOrgStoryNftOwner);
        rootOrgStoryNft.setContractURI(newContractURI);
        assertEq(rootOrgStoryNft.contractURI(), newContractURI);

        rootOrgStoryNft.setContractURI(oldContractURI);
        assertEq(rootOrgStoryNft.contractURI(), oldContractURI);
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_setContractURI_CallerIsNotOwner() public {
        vm.startPrank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, u.carl));
        rootOrgStoryNft.setContractURI("New Contract URI");
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_setSigner() public {
        vm.prank(rootOrgStoryNftOwner);
        rootOrgStoryNft.setSigner(u.bob);

        bytes memory signature = _signAddress(sk.bob, u.carl);

        vm.prank(u.carl);
        rootOrgStoryNft.mint(u.carl, signature);

        vm.prank(rootOrgStoryNftOwner);
        rootOrgStoryNft.setSigner(rootOrgStoryNftSigner);
    }

    function test_StoryBadgeNFT_setTokenURI() public {
        assertEq(rootOrgStoryNft.tokenURI(0), "Test Token URI");

        vm.prank(rootOrgStoryNftOwner);
        rootOrgStoryNft.setTokenURI("New Token URI");

        assertEq(rootOrgStoryNft.tokenURI(0), "New Token URI");
    }

    function test_StoryBadgeNFT_cachedMint() public {
        bytes memory signature = _signAddress(rootOrgStoryNftSignerSk, u.alice);
        vm.startPrank(u.alice);
        (uint256 tokenId, ) = rootOrgStoryNft.mint(u.alice, signature);
        assertEq(rootOrgStoryNft.ownerOf(tokenId), u.alice); // minted directly
        vm.stopPrank();

        vm.startPrank(rootOrgStoryNftOwner);
        rootOrgStoryNft.mintToCache(1);
        assertEq(rootOrgStoryNft.cacheSize(), 1); // 1 cached
        rootOrgStoryNft.mintToCache(100);
        assertEq(rootOrgStoryNft.cacheSize(), 101); // 100 cached + 1 minted
        rootOrgStoryNft.setCacheMode(true); // enable cache mode
        vm.stopPrank();

        signature = _signAddress(rootOrgStoryNftSignerSk, u.carl);
        vm.startPrank(u.carl);
        (tokenId, ) = rootOrgStoryNft.mint(u.carl, signature);
        assertEq(rootOrgStoryNft.ownerOf(tokenId), u.carl); // minted from cache
        vm.stopPrank();
        assertEq(rootOrgStoryNft.cacheSize(), 100); // cache size is reduced by 1

        vm.startPrank(rootOrgStoryNftOwner);
        rootOrgStoryNft.setCacheMode(false); // disable cache mode
        vm.stopPrank();

        signature = _signAddress(rootOrgStoryNftSignerSk, u.bob);
        vm.startPrank(u.bob);
        (tokenId, ) = rootOrgStoryNft.mint(u.bob, signature);
        assertEq(rootOrgStoryNft.ownerOf(tokenId), u.bob); // minted directly
        vm.stopPrank();
        assertEq(rootOrgStoryNft.cacheSize(), 100); // cache size is unchanged
    }

    function test_StoryBadgeNFT_revert_setSigner_CallerIsNotOwner() public {
        vm.startPrank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, u.carl));
        rootOrgStoryNft.setSigner(u.carl);
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_setTokenURI_CallerIsNotOwner() public {
        vm.startPrank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, u.carl));
        rootOrgStoryNft.setTokenURI("New Token URI");
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_mint_SignatureAlreadyUsed() public {
        bytes memory signature = _signAddress(rootOrgStoryNftSignerSk, u.carl);

        vm.startPrank(u.carl);
        rootOrgStoryNft.mint(u.carl, signature);
        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__SignatureAlreadyUsed.selector);
        rootOrgStoryNft.mint(u.carl, signature);
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_mint_InvalidSignature() public {
        bytes memory signature = _signAddress(sk.carl, u.carl);

        vm.startPrank(u.carl);
        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__InvalidSignature.selector);
        rootOrgStoryNft.mint(u.carl, signature);
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_TransferLocked() public {
        bytes memory signature = _signAddress(rootOrgStoryNftSignerSk, u.carl);

        vm.startPrank(u.carl);
        (uint256 tokenId, ) = rootOrgStoryNft.mint(u.carl, signature);

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        rootOrgStoryNft.approve(u.bob, tokenId);

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        rootOrgStoryNft.setApprovalForAll(u.bob, true);

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        rootOrgStoryNft.transferFrom(u.carl, u.bob, tokenId);

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        rootOrgStoryNft.safeTransferFrom(u.carl, u.bob, tokenId);
        vm.stopPrank();
    }
}
