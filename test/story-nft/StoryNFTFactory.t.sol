// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { IAccessManaged } from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// contracts
import { IOrgNFT } from "../../contracts/interfaces/story-nft/IOrgNFT.sol";
import { IStoryBadgeNFT } from "../../contracts/interfaces/story-nft/IStoryBadgeNFT.sol";
import { IStoryNFT } from "../../contracts/interfaces/story-nft/IStoryNFT.sol";
import { IStoryNFTFactory } from "../../contracts/interfaces/story-nft/IStoryNFTFactory.sol";
import { StoryNFTFactory } from "../../contracts/story-nft/StoryNFTFactory.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";
import { TestProxyHelper } from "../utils/TestProxyHelper.t.sol";

contract StoryNFTFactoryTest is BaseTest {
    string private orgName;
    string private orgTokenURI;
    string private storyNftName;
    string private storyNftSymbol;
    string private storyNftContractURI;
    string private storyNftBaseURI;
    string private storyNftTokenURI;
    IStoryNFT.StoryNftInitParams private storyNftInitParams;

    function setUp() public override {
        super.setUp();

        orgName = "Carl's Org";
        orgTokenURI = "Carl's Org Token URI";
        storyNftName = "Carl's StoryBadge";
        storyNftSymbol = "CSB";
        storyNftContractURI = "Carl's StoryBadge Contract URI";
        storyNftBaseURI = "";
        storyNftTokenURI = "Carl's StoryBadge Token URI";

        storyNftInitParams = IStoryNFT.StoryNftInitParams({
            owner: u.carl,
            name: storyNftName,
            symbol: storyNftSymbol,
            contractURI: storyNftContractURI,
            baseURI: storyNftBaseURI,
            customInitData: abi.encode(IStoryBadgeNFT.CustomInitParams({ tokenURI: storyNftTokenURI, signer: u.carl }))
        });
    }

    function test_StoryNFTFactory_initialize() public {
        address testStoryNftFactoryImpl = address(
            new StoryNFTFactory({
                ipAssetRegistry: address(ipAssetRegistry),
                licensingModule: address(licensingModule),
                pilTemplate: address(pilTemplate),
                defaultLicenseTermsId: 1,
                orgNft: address(orgNft)
            })
        );

        StoryNFTFactory testStoryNftFactory = StoryNFTFactory(
            TestProxyHelper.deployUUPSProxy(
                testStoryNftFactoryImpl,
                abi.encodeCall(
                    StoryNFTFactory.initialize,
                    (address(protocolAccessManager), address(defaultStoryNftTemplate), address(storyNftFactorySigner))
                )
            )
        );

        assertEq(testStoryNftFactory.IP_ASSET_REGISTRY(), address(ipAssetRegistry));
        assertEq(testStoryNftFactory.LICENSING_MODULE(), address(licensingModule));
        assertEq(testStoryNftFactory.PIL_TEMPLATE(), address(pilTemplate));
        assertEq(testStoryNftFactory.DEFAULT_LICENSE_TERMS_ID(), 1);
        assertEq(address(testStoryNftFactory.ORG_NFT()), address(orgNft));
        assertEq(testStoryNftFactory.getDefaultStoryNftTemplate(), address(defaultStoryNftTemplate));
        assertEq(testStoryNftFactory.authority(), address(protocolAccessManager));
    }

    function test_StoryNFTFactory_deployStoryNft() public {
        uint256 totalSupplyBefore = IOrgNFT(orgNft).totalSupply();

        vm.startPrank(u.carl);
        (address orgNft, uint256 orgTokenId, address orgIpId, address storyNft) = storyNftFactory.deployStoryNft({
            storyNftTemplate: defaultStoryNftTemplate,
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgTokenURI: orgTokenURI,
            signature: _signAddress(storyNftFactorySignerSk, u.carl),
            storyNftInitParams: storyNftInitParams
        });

        assertEq(IOrgNFT(orgNft).totalSupply(), totalSupplyBefore + 1);
        assertEq(IOrgNFT(orgNft).ownerOf(orgTokenId), u.carl);
        assertEq(IOrgNFT(orgNft).tokenURI(orgTokenId), orgTokenURI);
        assertTrue(ipAssetRegistry.isRegistered(orgIpId));
        assertEq(Ownable(storyNft).owner(), u.carl);
        assertEq(IStoryBadgeNFT(storyNft).name(), storyNftName);
        assertEq(IStoryBadgeNFT(storyNft).symbol(), storyNftSymbol);
        assertEq(IStoryBadgeNFT(storyNft).contractURI(), storyNftContractURI);
        assertEq(IStoryBadgeNFT(storyNft).tokenURI(0), storyNftTokenURI);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            orgIpId,
            0
        );
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            rootStoryNft.orgIpId(),
            0
        );
        assertEq(licenseTemplateParent, licenseTemplateChild);
        assertEq(licenseTermsIdParent, licenseTermsIdChild);
        assertEq(IIPAccount(payable(orgIpId)).owner(), u.carl);
        assertParentChild({
            parentIpId: rootStoryNft.orgIpId(),
            childIpId: orgIpId,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_StoryNFTFactory_deployStoryNftByAdmin() public {
        uint256 totalSupplyBefore = IOrgNFT(orgNft).totalSupply();

        vm.startPrank(u.admin);
        (address orgNft, uint256 orgTokenId, address orgIpId, address storyNft) = storyNftFactory
            .deployStoryNftByAdmin({
                storyNftTemplate: defaultStoryNftTemplate,
                orgNftRecipient: u.carl,
                orgName: orgName,
                orgTokenURI: orgTokenURI,
                storyNftInitParams: storyNftInitParams,
                isRootOrg: false
            });

        assertEq(IOrgNFT(orgNft).totalSupply(), totalSupplyBefore + 1);
        assertEq(IOrgNFT(orgNft).ownerOf(orgTokenId), u.carl);
        assertEq(IOrgNFT(orgNft).tokenURI(orgTokenId), orgTokenURI);
        assertTrue(ipAssetRegistry.isRegistered(orgIpId));
        assertEq(Ownable(storyNft).owner(), u.carl);
        assertEq(IStoryBadgeNFT(storyNft).name(), storyNftName);
        assertEq(IStoryBadgeNFT(storyNft).symbol(), storyNftSymbol);
        assertEq(IStoryBadgeNFT(storyNft).contractURI(), storyNftContractURI);
        assertEq(IStoryBadgeNFT(storyNft).tokenURI(0), storyNftTokenURI);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            orgIpId,
            0
        );
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            rootStoryNft.orgIpId(),
            0
        );
        assertEq(licenseTemplateParent, licenseTemplateChild);
        assertEq(licenseTermsIdParent, licenseTermsIdChild);
        assertEq(IIPAccount(payable(orgIpId)).owner(), u.carl);
        assertParentChild({
            parentIpId: rootStoryNft.orgIpId(),
            childIpId: orgIpId,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_StoryNFTFactory_setDefaultStoryNftTemplate() public {
        assertEq(storyNftFactory.getDefaultStoryNftTemplate(), defaultStoryNftTemplate);

        vm.prank(u.admin);
        storyNftFactory.setDefaultStoryNftTemplate(address(rootStoryNft));
        assertEq(storyNftFactory.getDefaultStoryNftTemplate(), address(rootStoryNft));

        vm.prank(u.admin);
        storyNftFactory.setDefaultStoryNftTemplate(address(defaultStoryNftTemplate));
        assertEq(storyNftFactory.getDefaultStoryNftTemplate(), address(defaultStoryNftTemplate));
    }

    function test_StoryNFTFactory_setSigner() public {
        vm.prank(u.admin);
        storyNftFactory.setSigner(u.bob);

        vm.prank(u.carl);
        storyNftFactory.deployStoryNft({
            storyNftTemplate: address(defaultStoryNftTemplate),
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgTokenURI: orgTokenURI,
            signature: _signAddress(sk.bob, u.carl),
            storyNftInitParams: storyNftInitParams
        });

        vm.prank(u.admin);
        storyNftFactory.setSigner(storyNftFactorySigner);
    }

    function test_StoryNFTFactory_whitelistNftTemplate() public {
        assertFalse(storyNftFactory.isNftTemplateWhitelisted(address(rootStoryNft)));
        vm.prank(u.admin);
        storyNftFactory.whitelistNftTemplate(address(rootStoryNft));
        assertTrue(storyNftFactory.isNftTemplateWhitelisted(address(rootStoryNft)));
    }

    function test_StoryNFTFactory_getStoryNftAddress() public {
        vm.startPrank(u.carl);
        (, uint256 orgTokenId, address orgIpId, address storyNft) = storyNftFactory.deployStoryNft({
            storyNftTemplate: defaultStoryNftTemplate,
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgTokenURI: orgTokenURI,
            signature: _signAddress(storyNftFactorySignerSk, u.carl),
            storyNftInitParams: storyNftInitParams
        });

        assertEq(storyNftFactory.getStoryNftAddressByOrgName(orgName), address(storyNft));
        assertEq(storyNftFactory.getStoryNftAddressByOrgTokenId(orgTokenId), address(storyNft));
        assertEq(storyNftFactory.getStoryNftAddressByOrgIpId(orgIpId), address(storyNft));
    }

    function test_StoryNFTFactory_revert_initialize_ZeroAddress() public {
        vm.expectRevert(IStoryNFTFactory.StoryNFTFactory__ZeroAddressParam.selector);
        StoryNFTFactory testStoryNftFactory = new StoryNFTFactory({
            ipAssetRegistry: address(ipAssetRegistry),
            licensingModule: address(0),
            pilTemplate: address(pilTemplate),
            defaultLicenseTermsId: 1,
            orgNft: address(orgNft)
        });

        address testStoryNftFactoryImpl = address(
            new StoryNFTFactory({
                ipAssetRegistry: address(ipAssetRegistry),
                licensingModule: address(licensingModule),
                pilTemplate: address(pilTemplate),
                defaultLicenseTermsId: 1,
                orgNft: address(orgNft)
            })
        );

        vm.expectRevert(IStoryNFTFactory.StoryNFTFactory__ZeroAddressParam.selector);
        testStoryNftFactory = StoryNFTFactory(
            TestProxyHelper.deployUUPSProxy(
                testStoryNftFactoryImpl,
                abi.encodeCall(
                    StoryNFTFactory.initialize,
                    (address(protocolAccessManager), address(0), address(storyNftFactorySigner))
                )
            )
        );
    }

    function test_StoryNFTFactory_revert_setDefaultStoryNftTemplate() public {
        vm.prank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, u.carl));
        storyNftFactory.setDefaultStoryNftTemplate(defaultStoryNftTemplate);

        vm.startPrank(u.admin);
        vm.expectRevert(IStoryNFTFactory.StoryNFTFactory__ZeroAddressParam.selector);
        storyNftFactory.setDefaultStoryNftTemplate(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(IStoryNFTFactory.StoryNFTFactory__UnsupportedIStoryNFT.selector, address(orgNft))
        );
        storyNftFactory.setDefaultStoryNftTemplate(address(orgNft));
        vm.stopPrank();
    }

    function test_StoryNFTFactory_revert_whitelistNftTemplate_ZeroAddress() public {
        vm.prank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, u.carl));
        storyNftFactory.whitelistNftTemplate(defaultStoryNftTemplate);

        vm.startPrank(u.admin);
        vm.expectRevert(IStoryNFTFactory.StoryNFTFactory__ZeroAddressParam.selector);
        storyNftFactory.whitelistNftTemplate(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(IStoryNFTFactory.StoryNFTFactory__UnsupportedIStoryNFT.selector, address(orgNft))
        );
        storyNftFactory.whitelistNftTemplate(address(orgNft));
        vm.stopPrank();
    }

    function test_StoryNFTFactory_revert_deployStoryNft() public {
        vm.prank(u.carl);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStoryNFTFactory.StoryNFTFactory__NftTemplateNotWhitelisted.selector,
                address(rootStoryNft)
            )
        );
        storyNftFactory.deployStoryNft({
            storyNftTemplate: address(rootStoryNft),
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgTokenURI: orgTokenURI,
            signature: _signAddress(storyNftFactorySignerSk, u.carl),
            storyNftInitParams: storyNftInitParams
        });

        bytes memory signature = _signAddress(storyNftFactorySignerSk, u.carl);
        vm.startPrank(u.carl);
        (, , , address storyNft) = storyNftFactory.deployStoryNft({
            storyNftTemplate: address(defaultStoryNftTemplate),
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgTokenURI: orgTokenURI,
            signature: signature,
            storyNftInitParams: storyNftInitParams
        });
        vm.expectRevert(
            abi.encodeWithSelector(IStoryNFTFactory.StoryNFTFactory__SignatureAlreadyUsed.selector, signature)
        );
        storyNftFactory.deployStoryNft({
            storyNftTemplate: address(defaultStoryNftTemplate),
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgTokenURI: orgTokenURI,
            signature: signature,
            storyNftInitParams: storyNftInitParams
        });
        vm.stopPrank();

        vm.prank(u.bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStoryNFTFactory.StoryNFTFactory__OrgAlreadyDeployed.selector,
                orgName,
                address(storyNft)
            )
        );
        storyNftFactory.deployStoryNft({
            storyNftTemplate: address(defaultStoryNftTemplate),
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgTokenURI: orgTokenURI,
            signature: _signAddress(storyNftFactorySignerSk, u.bob),
            storyNftInitParams: storyNftInitParams
        });

        signature = _signAddress(storyNftFactorySignerSk, u.bob);
        vm.prank(u.alice);
        vm.expectRevert(abi.encodeWithSelector(IStoryNFTFactory.StoryNFTFactory__InvalidSignature.selector, signature));
        storyNftFactory.deployStoryNft({
            storyNftTemplate: address(defaultStoryNftTemplate),
            orgNftRecipient: u.alice,
            orgName: "Alice's Org",
            orgTokenURI: orgTokenURI,
            signature: signature,
            storyNftInitParams: storyNftInitParams
        });
    }
}
