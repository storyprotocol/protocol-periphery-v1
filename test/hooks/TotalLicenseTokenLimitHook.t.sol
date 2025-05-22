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
    uint256 public commUseTermsId;

    function setUp() public override {
        super.setUp();
        commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse(0, address(mockToken), address(royaltyPolicyLAP))
        );
        tokenId1 = mockNft.mint(ipOwner1);
        tokenId2 = mockNft.mint(ipOwner2);
        tokenId3 = mockNft.mint(ipOwner3);
        ipId1 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId1);
        ipId2 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId2);
        ipId3 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId3);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commUseTermsId);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commUseTermsId);
        vm.prank(ipOwner3);
        licensingModule.attachLicenseTerms(ipId3, address(pilTemplate), commUseTermsId);
        vm.label(ipId1, "IPAccount1");
        vm.label(ipId2, "IPAccount2");
        vm.label(ipId3, "IPAccount3");
    }

    function test_TotalLicenseTokenLimitHook_setLimit() public {
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(totalLicenseTokenLimitHook),
            hookData: "",
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0) // not allowed to be added to any group
        });

        vm.startPrank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), commUseTermsId, licensingConfig);
        totalLicenseTokenLimitHook.setTotalLicenseTokenLimit(ipId1, address(pilTemplate), commUseTermsId, 10);
        assertEq(totalLicenseTokenLimitHook.getTotalLicenseTokenLimit(ipId1, address(pilTemplate), commUseTermsId), 10);
        vm.stopPrank();

        vm.startPrank(ipOwner2);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), commUseTermsId, licensingConfig);
        totalLicenseTokenLimitHook.setTotalLicenseTokenLimit(ipId2, address(pilTemplate), commUseTermsId, 20);
        assertEq(totalLicenseTokenLimitHook.getTotalLicenseTokenLimit(ipId2, address(pilTemplate), commUseTermsId), 20);
        vm.stopPrank();

        vm.startPrank(ipOwner3);
        licensingModule.setLicensingConfig(ipId3, address(pilTemplate), commUseTermsId, licensingConfig);
        assertEq(totalLicenseTokenLimitHook.getTotalLicenseTokenLimit(ipId3, address(pilTemplate), commUseTermsId), 0);
        vm.stopPrank();

        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId,
            amount: 10,
            receiver: u.alice,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId,
            amount: 20,
            receiver: u.alice,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId3,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId,
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
            licenseTermsId: commUseTermsId,
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
            licenseTermsId: commUseTermsId,
            amount: 5,
            receiver: u.alice,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    function test_TotalLicenseTokenLimitHook_revert_nonIpOwner_setLimit() public {
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(totalLicenseTokenLimitHook),
            hookData: "",
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0) // not allowed to be added to any group
        });

        vm.startPrank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), commUseTermsId, licensingConfig);
        totalLicenseTokenLimitHook.setTotalLicenseTokenLimit(ipId1, address(pilTemplate), commUseTermsId, 10);
        assertEq(totalLicenseTokenLimitHook.getTotalLicenseTokenLimit(ipId1, address(pilTemplate), commUseTermsId), 10);
        vm.stopPrank();

        vm.startPrank(ipOwner2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                ipId1,
                ipOwner2,
                address(totalLicenseTokenLimitHook),
                totalLicenseTokenLimitHook.setTotalLicenseTokenLimit.selector
            )
        );
        totalLicenseTokenLimitHook.setTotalLicenseTokenLimit(ipId1, address(pilTemplate), commUseTermsId, 20);
    }

    function test_TotalLicenseTokenLimitHook_revert_limitLowerThanTotalSupply_setLimit() public {
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(totalLicenseTokenLimitHook),
            hookData: "",
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0) // not allowed to be added to any group
        });

        vm.startPrank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), commUseTermsId, licensingConfig);
        totalLicenseTokenLimitHook.setTotalLicenseTokenLimit(ipId1, address(pilTemplate), commUseTermsId, 10);
        assertEq(totalLicenseTokenLimitHook.getTotalLicenseTokenLimit(ipId1, address(pilTemplate), commUseTermsId), 10);

        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId,
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
        totalLicenseTokenLimitHook.setTotalLicenseTokenLimit(ipId1, address(pilTemplate), commUseTermsId, 5);
    }

    function test_TotalLicenseTokenLimitHook_PerIpPerLicenseLimit() public {
        // Rename for clarity in this specific test
        uint256 commUseTermsId1 = commUseTermsId;

        // Register a second set of license terms with a different minting fee to ensure uniqueness
        uint256 commUseTermsId2 = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse(0, address(mockToken), address(royaltyPolicyLRP)) // Changed mintingFee from 0 to 1
        );

        // Configure Licensing for ipId1, commUseTermsId1
        Licensing.LicensingConfig memory licensingConfig1 = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(totalLicenseTokenLimitHook),
            hookData: "",
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });

        vm.startPrank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), commUseTermsId1, licensingConfig1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commUseTermsId2);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), commUseTermsId2, licensingConfig1);
        vm.stopPrank();

        // Configure Licensing for ipId2, commUseTermsId1
        vm.startPrank(ipOwner2);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), commUseTermsId1, licensingConfig1);
        vm.stopPrank();

        // Set Limits
        uint256 limitIp1Terms1 = 10;
        uint256 limitIp1Terms2 = 15;
        uint256 limitIp2Terms1 = 20;

        vm.startPrank(ipOwner1);
        totalLicenseTokenLimitHook.setTotalLicenseTokenLimit(
            ipId1,
            address(pilTemplate),
            commUseTermsId1,
            limitIp1Terms1
        );
        totalLicenseTokenLimitHook.setTotalLicenseTokenLimit(
            ipId1,
            address(pilTemplate),
            commUseTermsId2,
            limitIp1Terms2
        );
        vm.stopPrank();

        vm.startPrank(ipOwner2);
        totalLicenseTokenLimitHook.setTotalLicenseTokenLimit(
            ipId2,
            address(pilTemplate),
            commUseTermsId1,
            limitIp2Terms1
        );
        vm.stopPrank();

        // --- Test Minting for ipId1, commUseTermsId1 ---
        // Mint up to limit
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId1,
            amount: limitIp1Terms1,
            receiver: u.alice,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
        assertEq(
            totalLicenseTokenLimitHook.getTotalLicenseTokenSupply(ipId1, address(pilTemplate), commUseTermsId1),
            limitIp1Terms1
        );

        // Attempt to mint over limit
        vm.expectRevert(
            abi.encodeWithSelector(
                TotalLicenseTokenLimitHook.TotalLicenseTokenLimitHook_TotalLicenseTokenLimitExceeded.selector,
                limitIp1Terms1, // current total supply
                1, // amount to mint
                limitIp1Terms1 // limit
            )
        );
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId1,
            amount: 1,
            receiver: u.alice,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        // --- Test Minting for ipId1, commUseTermsId2 ---
        // Mint up to limit
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId2,
            amount: limitIp1Terms2,
            receiver: u.bob, // different receiver for clarity
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
        assertEq(
            totalLicenseTokenLimitHook.getTotalLicenseTokenSupply(ipId1, address(pilTemplate), commUseTermsId2),
            limitIp1Terms2
        );

        // Attempt to mint over limit
        vm.expectRevert(
            abi.encodeWithSelector(
                TotalLicenseTokenLimitHook.TotalLicenseTokenLimitHook_TotalLicenseTokenLimitExceeded.selector,
                limitIp1Terms2, // current total supply
                1, // amount to mint
                limitIp1Terms2 // limit
            )
        );
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId2,
            amount: 1,
            receiver: u.bob,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        // --- Test Minting for ipId2, commUseTermsId1 ---
        // Mint up to limit
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId1,
            amount: limitIp2Terms1,
            receiver: u.carl, // different receiver for clarity
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
        assertEq(
            totalLicenseTokenLimitHook.getTotalLicenseTokenSupply(ipId2, address(pilTemplate), commUseTermsId1),
            limitIp2Terms1
        );

        // Attempt to mint over limit
        vm.expectRevert(
            abi.encodeWithSelector(
                TotalLicenseTokenLimitHook.TotalLicenseTokenLimitHook_TotalLicenseTokenLimitExceeded.selector,
                limitIp2Terms1, // current total supply
                1, // amount to mint
                limitIp2Terms1 // limit
            )
        );
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId1,
            amount: 1,
            receiver: u.carl,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        // Verify that ipId1, commUseTermsId1 supply is unchanged
        uint256 supplyIp1Terms1 = totalLicenseTokenLimitHook.getTotalLicenseTokenSupply(
            ipId1,
            address(pilTemplate),
            commUseTermsId1
        );
        assertEq(supplyIp1Terms1, limitIp1Terms1);
        // Verify that ipId1, commUseTermsId2 supply is unchanged
        uint256 supplyIp1Terms2 = totalLicenseTokenLimitHook.getTotalLicenseTokenSupply(
            ipId1,
            address(pilTemplate),
            commUseTermsId2
        );
        assertEq(supplyIp1Terms2, limitIp1Terms2);
    }
}
