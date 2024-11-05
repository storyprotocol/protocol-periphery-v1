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
import { IOrgStoryNFTFactory } from "../../contracts/interfaces/story-nft/IOrgStoryNFTFactory.sol";
import { OrgStoryNFTFactory } from "../../contracts/story-nft/OrgStoryNFTFactory.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";
import { TestProxyHelper } from "../utils/TestProxyHelper.t.sol";

contract OrgStoryNFTFactoryTest is BaseTest {
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
            customInitData: abi.encode(
                IStoryBadgeNFT.CustomInitParams({
                    tokenURI: storyNftTokenURI,
                    signer: u.carl,
                    ipMetadataURI: ipMetadataDefault.ipMetadataURI,
                    ipMetadataHash: ipMetadataDefault.ipMetadataHash,
                    nftMetadataHash: ipMetadataDefault.nftMetadataHash
                })
            )
        });
    }

    function test_StoryNFTFactory_initialize() public {
        address testOrgStoryNftFactoryImpl = address(
            new OrgStoryNFTFactory({
                ipAssetRegistry: address(ipAssetRegistry),
                licensingModule: address(licensingModule),
                pilTemplate: address(pilTemplate),
                defaultLicenseTermsId: 1,
                orgNft: address(orgNft)
            })
        );

        OrgStoryNFTFactory testOrgStoryNftFactory = OrgStoryNFTFactory(
            TestProxyHelper.deployUUPSProxy(
                testOrgStoryNftFactoryImpl,
                abi.encodeCall(
                    OrgStoryNFTFactory.initialize,
                    (
                        address(protocolAccessManager),
                        address(defaultOrgStoryNftTemplate),
                        address(orgStoryNftFactorySigner)
                    )
                )
            )
        );

        assertEq(testOrgStoryNftFactory.IP_ASSET_REGISTRY(), address(ipAssetRegistry));
        assertEq(testOrgStoryNftFactory.LICENSING_MODULE(), address(licensingModule));
        assertEq(testOrgStoryNftFactory.PIL_TEMPLATE(), address(pilTemplate));
        assertEq(testOrgStoryNftFactory.DEFAULT_LICENSE_TERMS_ID(), 1);
        assertEq(address(testOrgStoryNftFactory.ORG_NFT()), address(orgNft));
        assertEq(testOrgStoryNftFactory.getDefaultOrgStoryNftTemplate(), address(defaultOrgStoryNftTemplate));
        assertEq(testOrgStoryNftFactory.authority(), address(protocolAccessManager));
    }

    function test_StoryNFTFactory_deployStoryNft() public {
        uint256 totalSupplyBefore = IOrgNFT(orgNft).totalSupply();

        vm.startPrank(u.carl);
        (address orgNft, uint256 orgTokenId, address orgIpId, address storyNft) = orgStoryNftFactory.deployOrgStoryNft({
            orgStoryNftTemplate: defaultOrgStoryNftTemplate,
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgIpMetadata: ipMetadataDefault,
            signature: _signAddress(orgStoryNftFactorySignerSk, u.carl),
            storyNftInitParams: storyNftInitParams
        });

        assertEq(IOrgNFT(orgNft).totalSupply(), totalSupplyBefore + 1);
        assertEq(IOrgNFT(orgNft).ownerOf(orgTokenId), u.carl);
        assertEq(IOrgNFT(orgNft).tokenURI(orgTokenId), ipMetadataDefault.nftMetadataURI);
        assertMetadata(orgIpId, ipMetadataDefault);
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
            rootOrgStoryNft.orgIpId(),
            0
        );
        assertEq(licenseTemplateParent, licenseTemplateChild);
        assertEq(licenseTermsIdParent, licenseTermsIdChild);
        assertEq(IIPAccount(payable(orgIpId)).owner(), u.carl);
        assertParentChild({
            parentIpId: rootOrgStoryNft.orgIpId(),
            childIpId: orgIpId,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_StoryNFTFactory_deployStoryNftByAdmin() public {
        uint256 totalSupplyBefore = IOrgNFT(orgNft).totalSupply();

        vm.startPrank(u.admin);
        (address orgNft, uint256 orgTokenId, address orgIpId, address storyNft) = orgStoryNftFactory
            .deployOrgStoryNftByAdmin({
                orgStoryNftTemplate: defaultOrgStoryNftTemplate,
                orgNftRecipient: u.carl,
                orgName: orgName,
                orgIpMetadata: ipMetadataDefault,
                storyNftInitParams: storyNftInitParams,
                isRootOrg: false
            });

        assertEq(IOrgNFT(orgNft).totalSupply(), totalSupplyBefore + 1);
        assertEq(IOrgNFT(orgNft).ownerOf(orgTokenId), u.carl);
        assertEq(IOrgNFT(orgNft).tokenURI(orgTokenId), ipMetadataDefault.nftMetadataURI);
        assertMetadata(orgIpId, ipMetadataDefault);
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
            rootOrgStoryNft.orgIpId(),
            0
        );
        assertEq(licenseTemplateParent, licenseTemplateChild);
        assertEq(licenseTermsIdParent, licenseTermsIdChild);
        assertEq(IIPAccount(payable(orgIpId)).owner(), u.carl);
        assertParentChild({
            parentIpId: rootOrgStoryNft.orgIpId(),
            childIpId: orgIpId,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_StoryNFTFactory_setDefaultStoryNftTemplate() public {
        assertEq(orgStoryNftFactory.getDefaultOrgStoryNftTemplate(), defaultOrgStoryNftTemplate);

        vm.prank(u.admin);
        orgStoryNftFactory.setDefaultOrgStoryNftTemplate(address(rootOrgStoryNft));
        assertEq(orgStoryNftFactory.getDefaultOrgStoryNftTemplate(), address(rootOrgStoryNft));

        vm.prank(u.admin);
        orgStoryNftFactory.setDefaultOrgStoryNftTemplate(address(defaultOrgStoryNftTemplate));
        assertEq(orgStoryNftFactory.getDefaultOrgStoryNftTemplate(), address(defaultOrgStoryNftTemplate));
    }

    function test_StoryNFTFactory_setSigner() public {
        vm.prank(u.admin);
        orgStoryNftFactory.setSigner(u.bob);

        vm.prank(u.carl);
        orgStoryNftFactory.deployOrgStoryNft({
            orgStoryNftTemplate: address(defaultOrgStoryNftTemplate),
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgIpMetadata: ipMetadataDefault,
            signature: _signAddress(sk.bob, u.carl),
            storyNftInitParams: storyNftInitParams
        });

        vm.prank(u.admin);
        orgStoryNftFactory.setSigner(orgStoryNftFactorySigner);
    }

    function test_StoryNFTFactory_whitelistNftTemplate() public {
        assertFalse(orgStoryNftFactory.isNftTemplateWhitelisted(address(rootOrgStoryNft)));
        vm.prank(u.admin);
        orgStoryNftFactory.whitelistNftTemplate(address(rootOrgStoryNft));
        assertTrue(orgStoryNftFactory.isNftTemplateWhitelisted(address(rootOrgStoryNft)));
    }

    function test_StoryNFTFactory_getStoryNftAddress() public {
        vm.startPrank(u.carl);
        (, uint256 orgTokenId, address orgIpId, address storyNft) = orgStoryNftFactory.deployOrgStoryNft({
            orgStoryNftTemplate: defaultOrgStoryNftTemplate,
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgIpMetadata: ipMetadataDefault,
            signature: _signAddress(orgStoryNftFactorySignerSk, u.carl),
            storyNftInitParams: storyNftInitParams
        });

        assertEq(orgStoryNftFactory.getOrgStoryNftAddressByOrgName(orgName), address(storyNft));
        assertEq(orgStoryNftFactory.getOrgStoryNftAddressByOrgTokenId(orgTokenId), address(storyNft));
        assertEq(orgStoryNftFactory.getOrgStoryNftAddressByOrgIpId(orgIpId), address(storyNft));
    }

    function test_StoryNFTFactory_revert_initialize_ZeroAddress() public {
        vm.expectRevert(IOrgStoryNFTFactory.OrgStoryNFTFactory__ZeroAddressParam.selector);
        OrgStoryNFTFactory testOrgStoryNftFactory = new OrgStoryNFTFactory({
            ipAssetRegistry: address(ipAssetRegistry),
            licensingModule: address(0),
            pilTemplate: address(pilTemplate),
            defaultLicenseTermsId: 1,
            orgNft: address(orgNft)
        });

        address testOrgStoryNftFactoryImpl = address(
            new OrgStoryNFTFactory({
                ipAssetRegistry: address(ipAssetRegistry),
                licensingModule: address(licensingModule),
                pilTemplate: address(pilTemplate),
                defaultLicenseTermsId: 1,
                orgNft: address(orgNft)
            })
        );

        vm.expectRevert(IOrgStoryNFTFactory.OrgStoryNFTFactory__ZeroAddressParam.selector);
        testOrgStoryNftFactory = OrgStoryNFTFactory(
            TestProxyHelper.deployUUPSProxy(
                testOrgStoryNftFactoryImpl,
                abi.encodeCall(
                    OrgStoryNFTFactory.initialize,
                    (address(protocolAccessManager), address(0), address(orgStoryNftFactorySigner))
                )
            )
        );
    }

    function test_StoryNFTFactory_revert_setDefaultStoryNftTemplate() public {
        vm.prank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, u.carl));
        orgStoryNftFactory.setDefaultOrgStoryNftTemplate(defaultOrgStoryNftTemplate);

        vm.startPrank(u.admin);
        vm.expectRevert(IOrgStoryNFTFactory.OrgStoryNFTFactory__ZeroAddressParam.selector);
        orgStoryNftFactory.setDefaultOrgStoryNftTemplate(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                IOrgStoryNFTFactory.OrgStoryNFTFactory__UnsupportedIOrgStoryNFT.selector,
                address(orgNft)
            )
        );
        orgStoryNftFactory.setDefaultOrgStoryNftTemplate(address(orgNft));
        vm.stopPrank();
    }

    function test_StoryNFTFactory_revert_whitelistNftTemplate_ZeroAddress() public {
        vm.prank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, u.carl));
        orgStoryNftFactory.whitelistNftTemplate(defaultOrgStoryNftTemplate);

        vm.startPrank(u.admin);
        vm.expectRevert(IOrgStoryNFTFactory.OrgStoryNFTFactory__ZeroAddressParam.selector);
        orgStoryNftFactory.whitelistNftTemplate(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                IOrgStoryNFTFactory.OrgStoryNFTFactory__UnsupportedIOrgStoryNFT.selector,
                address(orgNft)
            )
        );
        orgStoryNftFactory.whitelistNftTemplate(address(orgNft));
        vm.stopPrank();
    }

    function test_StoryNFTFactory_revert_deployStoryNft() public {
        vm.prank(u.carl);
        vm.expectRevert(
            abi.encodeWithSelector(
                IOrgStoryNFTFactory.OrgStoryNFTFactory__NftTemplateNotWhitelisted.selector,
                address(rootOrgStoryNft)
            )
        );
        orgStoryNftFactory.deployOrgStoryNft({
            orgStoryNftTemplate: address(rootOrgStoryNft),
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgIpMetadata: ipMetadataDefault,
            signature: _signAddress(orgStoryNftFactorySignerSk, u.carl),
            storyNftInitParams: storyNftInitParams
        });

        bytes memory signature = _signAddress(orgStoryNftFactorySignerSk, u.carl);
        vm.startPrank(u.carl);
        (, , , address storyNft) = orgStoryNftFactory.deployOrgStoryNft({
            orgStoryNftTemplate: address(defaultOrgStoryNftTemplate),
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgIpMetadata: ipMetadataDefault,
            signature: signature,
            storyNftInitParams: storyNftInitParams
        });
        vm.expectRevert(
            abi.encodeWithSelector(IOrgStoryNFTFactory.OrgStoryNFTFactory__SignatureAlreadyUsed.selector, signature)
        );
        orgStoryNftFactory.deployOrgStoryNft({
            orgStoryNftTemplate: address(defaultOrgStoryNftTemplate),
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgIpMetadata: ipMetadataDefault,
            signature: signature,
            storyNftInitParams: storyNftInitParams
        });
        vm.stopPrank();

        vm.prank(u.bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IOrgStoryNFTFactory.OrgStoryNFTFactory__OrgAlreadyDeployed.selector,
                orgName,
                address(storyNft)
            )
        );
        orgStoryNftFactory.deployOrgStoryNft({
            orgStoryNftTemplate: address(defaultOrgStoryNftTemplate),
            orgNftRecipient: u.carl,
            orgName: orgName,
            orgIpMetadata: ipMetadataDefault,
            signature: _signAddress(orgStoryNftFactorySignerSk, u.bob),
            storyNftInitParams: storyNftInitParams
        });

        signature = _signAddress(orgStoryNftFactorySignerSk, u.bob);
        vm.prank(u.alice);
        vm.expectRevert(
            abi.encodeWithSelector(IOrgStoryNFTFactory.OrgStoryNFTFactory__InvalidSignature.selector, signature)
        );
        orgStoryNftFactory.deployOrgStoryNft({
            orgStoryNftTemplate: address(defaultOrgStoryNftTemplate),
            orgNftRecipient: u.alice,
            orgName: "Alice's Org",
            orgIpMetadata: ipMetadataDefault,
            signature: signature,
            storyNftInitParams: storyNftInitParams
        });
    }
}
