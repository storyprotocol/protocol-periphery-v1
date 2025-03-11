// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { IPAccountStorageOps } from "@storyprotocol/core/lib/IPAccountStorageOps.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { Errors } from "../../../contracts/lib/Errors.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";
import { OwnableERC20 } from "../../../contracts/modules/tokenizer/OwnableERC20.sol";
import { IOwnableERC20 } from "../../../contracts/interfaces/modules/tokenizer/IOwnableERC20.sol";
import { ITokenizerModule } from "../../../contracts/interfaces/modules/tokenizer/ITokenizerModule.sol";

import { BaseTest } from "../../utils/BaseTest.t.sol";

contract TokenizerModuleTest is BaseTest {
    using IPAccountStorageOps for IIPAccount;

    function setUp() public override {
        super.setUp();
    }

    function test_TokenizerModule_whitelistTokenTemplate() public {
        address tokenTemplate1 = address(new OwnableERC20(address(ownableERC20Beacon)));
        address tokenTemplate2 = address(new OwnableERC20(address(ownableERC20Beacon)));
        address tokenTemplate3 = address(new OwnableERC20(address(ownableERC20Beacon)));

        vm.startPrank(u.admin);
        vm.expectEmit(true, true, true, true);
        emit ITokenizerModule.TokenTemplateWhitelisted(tokenTemplate1, true);
        tokenizerModule.whitelistTokenTemplate(tokenTemplate1, true);
        vm.expectEmit(true, true, true, true);
        emit ITokenizerModule.TokenTemplateWhitelisted(tokenTemplate2, true);
        tokenizerModule.whitelistTokenTemplate(tokenTemplate2, true);
        vm.expectEmit(true, true, true, true);
        emit ITokenizerModule.TokenTemplateWhitelisted(tokenTemplate3, true);
        tokenizerModule.whitelistTokenTemplate(tokenTemplate3, true);
        vm.stopPrank();

        assertTrue(tokenizerModule.isWhitelistedTokenTemplate(tokenTemplate1));
        assertTrue(tokenizerModule.isWhitelistedTokenTemplate(tokenTemplate2));
        assertTrue(tokenizerModule.isWhitelistedTokenTemplate(tokenTemplate3));
    }

    function test_TokenizerModule_revert_whitelistTokenTemplate_UnsupportedERC20() public {
        vm.startPrank(u.admin);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.TokenizerModule__UnsupportedOwnableERC20.selector, address(spgNftImpl))
        );
        tokenizerModule.whitelistTokenTemplate(address(spgNftImpl), true);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.TokenizerModule__UnsupportedOwnableERC20.selector, address(mockToken))
        );
        tokenizerModule.whitelistTokenTemplate(address(mockToken), true);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.TokenizerModule__UnsupportedOwnableERC20.selector, address(mockNft))
        );
        tokenizerModule.whitelistTokenTemplate(address(mockNft), true);
        vm.stopPrank();
    }

    function test_TokenizerModule_tokenize() public {
        mockToken.mint(address(this), 3 * 10 ** mockToken.decimals());
        mockToken.approve(address(spgNftPublic), 3 * 10 ** mockToken.decimals());

        (address ipId1, ) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            allowDuplicates: true
        });

        (address ipId2, ) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftPublic),
            recipient: u.bob,
            ipMetadata: ipMetadataEmpty,
            allowDuplicates: true
        });

        (address ipId3, ) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftPublic),
            recipient: u.carl,
            ipMetadata: ipMetadataDefault,
            allowDuplicates: true
        });

        vm.prank(u.alice);
        vm.expectEmit(true, false, false, false);
        emit ITokenizerModule.IPTokenized(ipId1, address(0));
        OwnableERC20 token1 = OwnableERC20(
            tokenizerModule.tokenize(
                ipId1,
                address(ownableERC20Template),
                abi.encode(IOwnableERC20.InitData({ cap: 1000, name: "Test1", symbol: "T1", initialOwner: u.alice }))
            )
        );

        vm.prank(u.bob);
        vm.expectEmit(true, false, false, false);
        emit ITokenizerModule.IPTokenized(ipId2, address(0));
        OwnableERC20 token2 = OwnableERC20(
            tokenizerModule.tokenize(
                ipId2,
                address(ownableERC20Template),
                abi.encode(IOwnableERC20.InitData({ cap: 1000000, name: "Test2", symbol: "T2", initialOwner: u.bob }))
            )
        );

        vm.prank(u.carl);
        vm.expectEmit(true, false, false, false);
        emit ITokenizerModule.IPTokenized(ipId3, address(0));
        OwnableERC20 token3 = OwnableERC20(
            tokenizerModule.tokenize(
                ipId3,
                address(ownableERC20Template),
                abi.encode(IOwnableERC20.InitData({ cap: 99999, name: "Test3", symbol: "T3", initialOwner: u.carl }))
            )
        );

        assertEq(tokenizerModule.getFractionalizedToken(ipId1), address(token1));
        assertEq(tokenizerModule.getFractionalizedToken(ipId2), address(token2));
        assertEq(tokenizerModule.getFractionalizedToken(ipId3), address(token3));

        assertEq(token1.name(), "Test1");
        assertEq(token1.symbol(), "T1");
        assertEq(token1.cap(), 1000);
        assertEq(token1.ipId(), ipId1);
        assertEq(token1.owner(), u.alice);

        assertEq(token2.name(), "Test2");
        assertEq(token2.symbol(), "T2");
        assertEq(token2.cap(), 1000000);
        assertEq(token2.ipId(), ipId2);
        assertEq(token2.owner(), u.bob);

        assertEq(token3.name(), "Test3");
        assertEq(token3.symbol(), "T3");
        assertEq(token3.cap(), 99999);
        assertEq(token3.ipId(), ipId3);
        assertEq(token3.owner(), u.carl);
    }

    function test_TokenizerModule_revert_tokenize_DisputedIpId() public {
        vm.prank(u.admin);
        disputeModule.whitelistDisputeTag("PLAGIARISM", true);

        mockToken.mint(address(this), 1 * 10 ** mockToken.decimals());
        mockToken.approve(address(spgNftPublic), 1 * 10 ** mockToken.decimals());
        (address ipId, ) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            allowDuplicates: true
        });

        uint256 disputeId = disputeModule.raiseDispute({
            targetIpId: ipId,
            disputeEvidenceHash: bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef),
            targetTag: "PLAGIARISM",
            data: ""
        });

        vm.prank(u.admin);
        disputeModule.setDisputeJudgement(disputeId, true, "");

        vm.prank(u.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenizerModule__DisputedIpId.selector, ipId));
        tokenizerModule.tokenize(
            ipId,
            address(ownableERC20Template),
            abi.encode(IOwnableERC20.InitData({ cap: 1000, name: "Test1", symbol: "T1", initialOwner: u.alice }))
        );
    }

    function test_TokenizerModule_revert_tokenize_IpNotRegistered() public {
        address ipId = ipAssetRegistry.ipId(block.chainid, address(spgNftPublic), 1);
        vm.prank(u.alice);
        vm.expectRevert(abi.encodeWithSelector(CoreErrors.AccessControlled__NotIpAccount.selector, ipId));
        tokenizerModule.tokenize(
            ipId,
            address(ownableERC20Template),
            abi.encode(IOwnableERC20.InitData({ cap: 1000, name: "Test1", symbol: "T1", initialOwner: u.alice }))
        );
    }

    function test_TokenizerModule_revert_tokenize_callerNotIpOwner() public {
        mockToken.mint(address(this), 1 * 10 ** mockToken.decimals());
        mockToken.approve(address(spgNftPublic), 1 * 10 ** mockToken.decimals());
        (address ipId, ) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            allowDuplicates: true
        });

        vm.prank(u.bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                CoreErrors.AccessController__PermissionDenied.selector,
                ipId,
                u.bob,
                address(tokenizerModule),
                tokenizerModule.tokenize.selector
            )
        );
        tokenizerModule.tokenize(
            ipId,
            address(ownableERC20Template),
            abi.encode(IOwnableERC20.InitData({ cap: 1000, name: "Test1", symbol: "T1", initialOwner: u.bob }))
        );
    }

    function test_TokenizerModule_revert_tokenize_IpExpired() public {
        WorkflowStructs.LicenseTermsData[] memory termsData = new WorkflowStructs.LicenseTermsData[](1);
        termsData[0] = WorkflowStructs.LicenseTermsData({
            terms: PILTerms({
                transferable: true,
                royaltyPolicy: address(royaltyPolicyLAP),
                defaultMintingFee: 0,
                expiration: 10 days,
                commercialUse: true,
                commercialAttribution: true,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 0,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativeRevCeiling: 0,
                currency: address(mockToken),
                uri: ""
            }),
            licensingConfig: Licensing.LicensingConfig({
                isSet: false,
                mintingFee: 0,
                licensingHook: address(0),
                hookData: "",
                commercialRevShare: 0,
                disabled: false,
                expectMinimumGroupRewardShare: 0,
                expectGroupRewardPool: address(0)
            })
        });

        mockToken.mint(address(this), 2 * 10 ** mockToken.decimals());
        mockToken.approve(address(spgNftPublic), 2 * 10 ** mockToken.decimals());
        (address ipId1, , uint256[] memory licenseIds) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            licenseTermsData: termsData,
            allowDuplicates: true
        });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;
        (address ipId2, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(spgNftPublic),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseIds,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: 0,
                maxRevenueShare: 0
            }),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            allowDuplicates: true
        });

        vm.warp(11 days);
        vm.prank(u.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenizerModule__IpExpired.selector, ipId2));
        tokenizerModule.tokenize(
            ipId2,
            address(ownableERC20Template),
            abi.encode(IOwnableERC20.InitData({ cap: 1000, name: "Test1", symbol: "T1", initialOwner: u.alice }))
        );
    }

    function test_TokenizerModule_revert_tokenize_IpAlreadyTokenized() public {
        mockToken.mint(address(this), 1 * 10 ** mockToken.decimals());
        mockToken.approve(address(spgNftPublic), 1 * 10 ** mockToken.decimals());
        (address ipId, ) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftPublic),
            recipient: u.alice,
            ipMetadata: ipMetadataDefault,
            allowDuplicates: true
        });

        vm.prank(u.alice);
        address token = tokenizerModule.tokenize(
            ipId,
            address(ownableERC20Template),
            abi.encode(IOwnableERC20.InitData({ cap: 1000, name: "Test1", symbol: "T1", initialOwner: u.alice }))
        );

        vm.prank(u.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenizerModule__IpAlreadyTokenized.selector, ipId, token));
        tokenizerModule.tokenize(
            ipId,
            address(ownableERC20Template),
            abi.encode(IOwnableERC20.InitData({ cap: 1000, name: "Test1", symbol: "T1", initialOwner: u.alice }))
        );
    }

    function test_TokenizerModule_upgradeWhitelistedTokenTemplate() public {
        address newTokenTemplateImpl = address(new OwnableERC20(address(ownableERC20Beacon)));

        vm.startPrank(u.admin);
        vm.expectEmit();
        emit UpgradeableBeacon.Upgraded(address(newTokenTemplateImpl));
        tokenizerModule.upgradeWhitelistedTokenTemplate(address(ownableERC20Template), newTokenTemplateImpl);
        vm.stopPrank();

        assertEq(UpgradeableBeacon(ownableERC20Beacon).implementation(), newTokenTemplateImpl);
    }

    function test_TokenizerModule_revert_upgradeWhitelistedTokenTemplate_NotWhitelisted() public {
        address newTokenTemplateImpl = address(new OwnableERC20(address(ownableERC20Beacon)));

        vm.startPrank(u.admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenizerModule__TokenTemplateNotWhitelisted.selector, address(0x1234)));
        tokenizerModule.upgradeWhitelistedTokenTemplate(address(0x1234), address(newTokenTemplateImpl));
        vm.stopPrank();
    }
}
