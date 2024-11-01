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
                orgNft: address(orgNft),
                pilTemplate: address(pilTemplate),
                defaultLicenseTermsId: 1
            })
        );

        string memory tokenURI = "Test Token URI";

        bytes memory storyBadgeNftCustomInitParams = abi.encode(
            IStoryBadgeNFT.CustomInitParams({ tokenURI: tokenURI, signer: rootStoryNftSigner })
        );

        IStoryNFT.StoryNftInitParams memory storyBadgeNftInitParams = IStoryNFT.StoryNftInitParams({
            owner: rootStoryNftOwner,
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
        assertEq(testStoryBadgeNft.owner(), rootStoryNftOwner);
        assertEq(testStoryBadgeNft.totalSupply(), 0);
        assertTrue(testStoryBadgeNft.locked(0));
    }

    function test_StoryBadgeNFT_revert_initialize_ZeroAddress() public {
        vm.expectRevert(IStoryNFT.StoryNFT__ZeroAddressParam.selector);
        StoryBadgeNFT testStoryBadgeNft = new StoryBadgeNFT(
            address(ipAssetRegistry),
            address(licensingModule),
            address(0),
            address(pilTemplate),
            1
        );

        address testStoryBadgeNftImpl = address(
            new StoryBadgeNFT({
                ipAssetRegistry: address(ipAssetRegistry),
                licensingModule: address(licensingModule),
                orgNft: address(orgNft),
                pilTemplate: address(pilTemplate),
                defaultLicenseTermsId: 1
            })
        );

        string memory tokenURI = "Test Token URI";

        bytes memory storyBadgeNftCustomInitParams = abi.encode(
            IStoryBadgeNFT.CustomInitParams({
                tokenURI: tokenURI,
                signer: address(0) // Should revert
            })
        );

        IStoryNFT.StoryNftInitParams memory storyBadgeNftInitParams = IStoryNFT.StoryNftInitParams({
            owner: rootStoryNftOwner,
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
        assertTrue(BaseStoryNFT(rootStoryNft).supportsInterface(type(IOrgStoryNFT).interfaceId));
        assertTrue(BaseStoryNFT(rootStoryNft).supportsInterface(type(IERC721).interfaceId));
        assertTrue(BaseStoryNFT(rootStoryNft).supportsInterface(type(IERC721Metadata).interfaceId));
    }

    function test_StoryBadgeNFT_mint() public {
        bytes memory signature = _signAddress(rootStoryNftSignerSk, u.carl);

        uint256 totalSupplyBefore = rootStoryNft.totalSupply();
        vm.startPrank(u.carl);
        (uint256 tokenId, address ipId) = rootStoryNft.mint(u.carl, signature);
        vm.stopPrank();

        assertEq(rootStoryNft.ownerOf(tokenId), u.carl);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(rootStoryNft.tokenURI(tokenId), "Test Token URI");
        assertEq(rootStoryNft.totalSupply(), totalSupplyBefore + 1);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            rootStoryNft.orgIpId(),
            0
        );
        assertEq(licenseTemplateParent, licenseTemplateChild);
        assertEq(licenseTermsIdParent, licenseTermsIdChild);
        assertEq(IIPAccount(payable(ipId)).owner(), u.carl);

        assertParentChild({
            parentIpId: rootStoryNft.orgIpId(),
            childIpId: ipId,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_StoryBadgeNFT_setContractURI() public {
        string memory oldContractURI = rootStoryNft.contractURI();
        string memory newContractURI = "New Contract URI";

        assertNotEq(oldContractURI, newContractURI);

        vm.startPrank(rootStoryNftOwner);
        rootStoryNft.setContractURI(newContractURI);
        assertEq(rootStoryNft.contractURI(), newContractURI);

        rootStoryNft.setContractURI(oldContractURI);
        assertEq(rootStoryNft.contractURI(), oldContractURI);
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_setContractURI_CallerIsNotOwner() public {
        vm.startPrank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, u.carl));
        rootStoryNft.setContractURI("New Contract URI");
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_setSigner() public {
        vm.prank(rootStoryNftOwner);
        rootStoryNft.setSigner(u.bob);

        bytes memory signature = _signAddress(sk.bob, u.carl);

        vm.prank(u.carl);
        rootStoryNft.mint(u.carl, signature);

        vm.prank(rootStoryNftOwner);
        rootStoryNft.setSigner(rootStoryNftSigner);
    }

    function test_StoryBadgeNFT_setTokenURI() public {
        assertEq(rootStoryNft.tokenURI(0), "Test Token URI");

        vm.prank(rootStoryNftOwner);
        rootStoryNft.setTokenURI("New Token URI");

        assertEq(rootStoryNft.tokenURI(0), "New Token URI");
    }

    function test_StoryBadgeNFT_revert_setSigner_CallerIsNotOwner() public {
        vm.startPrank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, u.carl));
        rootStoryNft.setSigner(u.carl);
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_setTokenURI_CallerIsNotOwner() public {
        vm.startPrank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, u.carl));
        rootStoryNft.setTokenURI("New Token URI");
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_mint_SignatureAlreadyUsed() public {
        bytes memory signature = _signAddress(rootStoryNftSignerSk, u.carl);

        vm.startPrank(u.carl);
        rootStoryNft.mint(u.carl, signature);
        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__SignatureAlreadyUsed.selector);
        rootStoryNft.mint(u.carl, signature);
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_mint_InvalidSignature() public {
        bytes memory signature = _signAddress(sk.carl, u.carl);

        vm.startPrank(u.carl);
        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__InvalidSignature.selector);
        rootStoryNft.mint(u.carl, signature);
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_TransferLocked() public {
        bytes memory signature = _signAddress(rootStoryNftSignerSk, u.carl);

        vm.startPrank(u.carl);
        (uint256 tokenId, ) = rootStoryNft.mint(u.carl, signature);

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        rootStoryNft.approve(u.bob, tokenId);

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        rootStoryNft.setApprovalForAll(u.bob, true);

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        rootStoryNft.transferFrom(u.carl, u.bob, tokenId);

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        rootStoryNft.safeTransferFrom(u.carl, u.bob, tokenId);
        vm.stopPrank();
    }
}
