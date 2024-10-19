// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

import { BaseTest } from "../utils/BaseTest.t.sol";
import { LockLicenseHook } from "../../contracts/hooks/LockLicenseHook.sol";

contract LockLicenseHookTest is BaseTest {
    address public ipId;
    address public ipOwner;

    function setUp() public override {
        super.setUp();
        ipOwner = u.alice;
        uint256 tokenId = mockNft.mint(ipOwner);
        ipId = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId);
        vm.label(ipId, "IPAccount");
    }

    function test_LockLicenseHook_revert_beforeMintLicenseTokens() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        LockLicenseHook lockLicenseHook = new LockLicenseHook();
        vm.prank(u.admin);
        moduleRegistry.registerModule("LockLicenseHook", address(lockLicenseHook));

        vm.startPrank(ipOwner);
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(lockLicenseHook),
            hookData: "",
            commercialRevShare: 0
        });
        licensingModule.setLicensingConfig(ipId, address(pilTemplate), socialRemixTermsId, licensingConfig);
        vm.stopPrank();

        vm.startPrank(u.bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                LockLicenseHook.LockLicenseHook_LicenseLocked.selector,
                ipId,
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: socialRemixTermsId,
            amount: 1,
            receiver: u.bob,
            royaltyContext: "",
            maxMintingFee: 0
        });
    }

    function test_LockLicenseHook_revert_beforeRegisterDerivative() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        LockLicenseHook lockLicenseHook = new LockLicenseHook();
        vm.prank(u.admin);
        moduleRegistry.registerModule("LockLicenseHook", address(lockLicenseHook));

        vm.startPrank(ipOwner);
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(lockLicenseHook),
            hookData: "",
            commercialRevShare: 0
        });
        licensingModule.setLicensingConfig(ipId, address(pilTemplate), socialRemixTermsId, licensingConfig);
        vm.stopPrank();

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = socialRemixTermsId;

        vm.startPrank(u.bob);
        address ipIdChild = ipAssetRegistry.register(block.chainid, address(mockNft), mockNft.mint(u.bob));
        vm.expectRevert(
            abi.encodeWithSelector(
                LockLicenseHook.LockLicenseHook_LicenseLocked.selector,
                ipId,
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.registerDerivative({
            childIpId: ipIdChild,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 0
        });
    }

    function test_LockLicenseHook_calculateMintingFee() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        LockLicenseHook lockLicenseHook = new LockLicenseHook();
        vm.prank(u.admin);
        moduleRegistry.registerModule("LockLicenseHook", address(lockLicenseHook));

        vm.startPrank(ipOwner);
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 1000,
            licensingHook: address(lockLicenseHook),
            hookData: "",
            commercialRevShare: 0
        });
        licensingModule.setLicensingConfig(ipId, address(pilTemplate), socialRemixTermsId, licensingConfig);
        vm.stopPrank();

        vm.startPrank(u.bob);
        (, uint256 mintingFee) = licensingModule.predictMintingLicenseFee({
            licensorIpId: ipId,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: socialRemixTermsId,
            amount: 1,
            receiver: u.bob,
            royaltyContext: ""
        });
        assertEq(mintingFee, 0);
    }
}
