// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { Errors } from "@storyprotocol/core/lib/Errors.sol";

import { TotalLicenseTokenLimitHook } from "../../contracts/hooks/TotalLicenseTokenLimitHook.sol";

import { BaseTest } from "../utils/BaseTest.t.sol";

contract TotalLicenseTokenLimitHookTest is BaseTest {
    address public ipId1;
    address public ipId2;
    address public ipId3;
    address public ipOwner1 = address(0x111);
    address public ipOwner2 = address(0x222);
    address public ipOwner3 = address(0x333);
    uint256 public tokenId1;
    uint256 public tokenId2;
    uint256 public tokenId3;

    function setUp() public override {
        super.setUp();
        tokenId1 = mockNft.mint(ipOwner1);
        tokenId2 = mockNft.mint(ipOwner2);
        tokenId3 = mockNft.mint(ipOwner3);
        ipId1 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId1);
        ipId2 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId2);
        ipId3 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId3);
        vm.label(ipId1, "IPAccount1");
        vm.label(ipId2, "IPAccount2");
        vm.label(ipId3, "IPAccount3");
    }

    function test_TotalLicenseTokenLimitHook_setLimit() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        TotalLicenseTokenLimitHook totalLimitHook = new TotalLicenseTokenLimitHook(
            address(licenseRegistry),
            address(licenseToken),
            address(accessController),
            address(ipAssetRegistry)
        );

        vm.prank(u.admin);
        moduleRegistry.registerModule("TotalLicenseTokenLimitHook", address(totalLimitHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(totalLimitHook),
            hookData: "",
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0) // not allowed to be added to any group
        });

        vm.startPrank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);
        totalLimitHook.setTotalLicenseTokenLimit(ipId1, address(pilTemplate), socialRemixTermsId, 10);
        assertEq(totalLimitHook.getTotalLicenseTokenLimit(ipId1, address(pilTemplate), socialRemixTermsId), 10);
        vm.stopPrank();

        vm.startPrank(ipOwner2);
        licensingModule.setLicensingConfig(ipId2, address(0), 0, licensingConfig);
        totalLimitHook.setTotalLicenseTokenLimit(ipId2, address(pilTemplate), socialRemixTermsId, 20);
        assertEq(totalLimitHook.getTotalLicenseTokenLimit(ipId2, address(pilTemplate), socialRemixTermsId), 20);
        vm.stopPrank();

        vm.startPrank(ipOwner3);
        licensingModule.setLicensingConfig(ipId3, address(pilTemplate), socialRemixTermsId, licensingConfig);
        assertEq(totalLimitHook.getTotalLicenseTokenLimit(ipId3, address(pilTemplate), socialRemixTermsId), 0);
        vm.stopPrank();

        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: socialRemixTermsId,
            amount: 10,
            receiver: u.alice,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: socialRemixTermsId,
            amount: 20,
            receiver: u.alice,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId3,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: socialRemixTermsId,
            amount: 10,
            receiver: u.alice,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                TotalLicenseTokenLimitHook.TotalLicenseTokenLimitHook_TotalLicenseTokenLimitExceeded.selector,
                10,
                5,
                10
            )
        );
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: socialRemixTermsId,
            amount: 5,
            receiver: u.alice,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                TotalLicenseTokenLimitHook.TotalLicenseTokenLimitHook_TotalLicenseTokenLimitExceeded.selector,
                20,
                5,
                20
            )
        );
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: socialRemixTermsId,
            amount: 5,
            receiver: u.alice,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    function test_TotalLicenseTokenLimitHook_revert_nonIpOwner_setLimit() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        TotalLicenseTokenLimitHook totalLimitHook = new TotalLicenseTokenLimitHook(
            address(licenseRegistry),
            address(licenseToken),
            address(accessController),
            address(ipAssetRegistry)
        );

        vm.prank(u.admin);
        moduleRegistry.registerModule("TotalLicenseTokenLimitHook", address(totalLimitHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(totalLimitHook),
            hookData: "",
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0) // not allowed to be added to any group
        });

        vm.startPrank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);
        totalLimitHook.setTotalLicenseTokenLimit(ipId1, address(pilTemplate), socialRemixTermsId, 10);
        assertEq(totalLimitHook.getTotalLicenseTokenLimit(ipId1, address(pilTemplate), socialRemixTermsId), 10);
        vm.stopPrank();

        vm.startPrank(ipOwner2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                ipId1,
                ipOwner2,
                address(totalLimitHook),
                totalLimitHook.setTotalLicenseTokenLimit.selector
            )
        );
        totalLimitHook.setTotalLicenseTokenLimit(ipId1, address(pilTemplate), socialRemixTermsId, 20);
    }

    function test_TotalLicenseTokenLimitHook_revert_limitLowerThanTotalSupply_setLimit() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        TotalLicenseTokenLimitHook totalLimitHook = new TotalLicenseTokenLimitHook(
            address(licenseRegistry),
            address(licenseToken),
            address(accessController),
            address(ipAssetRegistry)
        );

        vm.prank(u.admin);
        moduleRegistry.registerModule("TotalLicenseTokenLimitHook", address(totalLimitHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(totalLimitHook),
            hookData: "",
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0) // not allowed to be added to any group
        });

        vm.startPrank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);
        totalLimitHook.setTotalLicenseTokenLimit(ipId1, address(pilTemplate), socialRemixTermsId, 10);
        assertEq(totalLimitHook.getTotalLicenseTokenLimit(ipId1, address(pilTemplate), socialRemixTermsId), 10);

        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: socialRemixTermsId,
            amount: 10,
            receiver: u.alice,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                TotalLicenseTokenLimitHook.TotalLicenseTokenLimitHook_LimitLowerThanTotalSupply.selector,
                10,
                5
            )
        );
        totalLimitHook.setTotalLicenseTokenLimit(ipId1, address(pilTemplate), socialRemixTermsId, 5);
    }
}
