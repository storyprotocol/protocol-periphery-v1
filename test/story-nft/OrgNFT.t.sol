// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

// contracts
import { IOrgNFT } from "../../contracts/interfaces/story-nft/IOrgNFT.sol";
import { OrgNFT } from "../../contracts/story-nft/OrgNFT.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";
import { TestProxyHelper } from "../utils/TestProxyHelper.t.sol";

contract OrgNFTTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_OrgNFT_initialize() public {
        address testOrgNftImpl = address(
            new OrgNFT({
                ipAssetRegistry: address(ipAssetRegistry),
                licensingModule: address(licensingModule),
                storyNftFactory: address(storyNftFactory),
                licenseTemplate: address(pilTemplate),
                licenseTermsId: 1
            })
        );

        OrgNFT testOrgNft = OrgNFT(
            TestProxyHelper.deployUUPSProxy(
                testOrgNftImpl,
                abi.encodeCall(OrgNFT.initialize, address(protocolAccessManager))
            )
        );

        assertEq(address(testOrgNft.IP_ASSET_REGISTRY()), address(ipAssetRegistry));
        assertEq(address(testOrgNft.LICENSING_MODULE()), address(licensingModule));
        assertEq(address(testOrgNft.STORY_NFT_FACTORY()), address(storyNftFactory));
        assertEq(testOrgNft.LICENSE_TEMPLATE(), address(pilTemplate));
        assertEq(testOrgNft.LICENSE_TERMS_ID(), 1);

        assertEq(testOrgNft.name(), "Organization NFT");
        assertEq(testOrgNft.symbol(), "OrgNFT");
        assertEq(testOrgNft.authority(), address(protocolAccessManager));
    }

    function test_OrgNFT_setTokenURI() public {
        string memory oldTokenURI = orgNft.tokenURI(0);
        string memory newTokenURI = "test";

        assertNotEq(oldTokenURI, newTokenURI);

        vm.startPrank(rootStoryNftOwner);
        orgNft.setTokenURI(0, newTokenURI);
        assertEq(orgNft.tokenURI(0), newTokenURI);
        orgNft.setTokenURI(0, oldTokenURI);
        assertEq(orgNft.tokenURI(0), oldTokenURI);
        vm.stopPrank();
    }

    function test_OrgNFT_revert_setTokenURI_CallerIsNotOwner() public {
        vm.startPrank(u.bob);
        vm.expectRevert(abi.encodeWithSelector(IOrgNFT.OrgNFT__CallerNotOwner.selector, 0, u.bob, rootStoryNftOwner));
        orgNft.setTokenURI(0, "test");
        vm.stopPrank();
    }

    function test_OrgNFT_revert_initialize_ZeroAddress() public {
        vm.expectRevert(IOrgNFT.OrgNFT__ZeroAddressParam.selector);
        OrgNFT testOrgNft = new OrgNFT({
            ipAssetRegistry: address(ipAssetRegistry),
            licensingModule: address(licensingModule),
            storyNftFactory: address(storyNftFactory),
            licenseTemplate: address(0),
            licenseTermsId: 1
        });

        address testOrgNftImpl = address(
            new OrgNFT({
                ipAssetRegistry: address(ipAssetRegistry),
                licensingModule: address(licensingModule),
                storyNftFactory: address(storyNftFactory),
                licenseTemplate: address(pilTemplate),
                licenseTermsId: 1
            })
        );

        vm.expectRevert(IOrgNFT.OrgNFT__ZeroAddressParam.selector);
        testOrgNft = OrgNFT(
            TestProxyHelper.deployUUPSProxy(testOrgNftImpl, abi.encodeCall(OrgNFT.initialize, address(0)))
        );
    }

    function test_OrgNFT_interfaceSupport() public view {
        assertTrue(IOrgNFT(address(orgNft)).supportsInterface(type(IOrgNFT).interfaceId));
        assertTrue(orgNft.supportsInterface(type(IERC721).interfaceId));
        assertTrue(orgNft.supportsInterface(type(IERC721Metadata).interfaceId));
    }

    function test_OrgNFT_revert_mintOrgNft_CallerIsNotStoryNftFactory() public {
        vm.startPrank(u.bob);
        vm.expectRevert(
            abi.encodeWithSelector(IOrgNFT.OrgNFT__CallerNotStoryNFTFactory.selector, u.bob, address(storyNftFactory))
        );
        orgNft.mintRootOrgNft(u.bob, "test");

        vm.expectRevert(
            abi.encodeWithSelector(IOrgNFT.OrgNFT__CallerNotStoryNFTFactory.selector, u.bob, address(storyNftFactory))
        );
        orgNft.mintOrgNft(u.bob, "test");
        vm.stopPrank();
    }
}
