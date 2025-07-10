//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
// contracts
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

contract RoyaltyWorkflowsTest is BaseTest {
    using Strings for uint256;

    address internal ancestorIpId;
    address internal childIpIdA;
    address internal childIpIdB;
    address internal childIpIdC;
    address internal childIpIdD;
    address internal grandChildIpId;

    uint256 internal commRemixTermsIdA;
    MockERC20 internal mockTokenA;
    uint256 internal defaultMintingFeeA = 1000 ether;
    uint32 internal defaultCommRevShareA = 10 * 10 ** 6; // 10%

    uint256 internal commRemixTermsIdC;
    MockERC20 internal mockTokenC;
    uint256 internal defaultMintingFeeC = 500 ether;
    uint32 internal defaultCommRevShareC = 20 * 10 ** 6; // 20%

    uint256 internal commRemixTermsIdD;
    uint256 internal defaultMintingFeeD = 0;
    uint32 internal defaultCommRevShareD = 0; // 0%

    WorkflowStructs.LicenseTermsData[] internal commTermsData;

    uint256 internal amountLicenseTokensToMint = 1;

    function setUp() public override {
        super.setUp();

        _setupCurrencyTokens();
    }

    function test_RoyaltyWorkflows_claimAllRevenue() public {
        _setupIpGraph();

        address[] memory childIpIds = new address[](5);
        address[] memory royaltyPolicies = new address[](5);
        address[] memory currencyTokens = new address[](5);

        childIpIds[0] = childIpIdA;
        royaltyPolicies[0] = address(royaltyPolicyLRP);
        currencyTokens[0] = address(mockTokenA);

        childIpIds[1] = childIpIdB;
        royaltyPolicies[1] = address(royaltyPolicyLRP);
        currencyTokens[1] = address(mockTokenA);

        childIpIds[2] = grandChildIpId;
        royaltyPolicies[2] = address(royaltyPolicyLRP);
        currencyTokens[2] = address(mockTokenA);

        childIpIds[3] = childIpIdC;
        royaltyPolicies[3] = address(royaltyPolicyLAP);
        currencyTokens[3] = address(mockTokenC);

        childIpIds[4] = childIpIdD;
        royaltyPolicies[4] = address(royaltyPolicyLAP);
        currencyTokens[4] = address(mockTokenA);

        uint256 claimerBalanceABefore = mockTokenA.balanceOf(ancestorIpId);
        uint256 claimerBalanceCBefore = mockTokenC.balanceOf(ancestorIpId);

        // Expect the call to succeed although childIpD has no claimable royalty
        uint256[] memory amountsClaimed = royaltyWorkflows.claimAllRevenue({
            ancestorIpId: ancestorIpId,
            claimer: ancestorIpId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });

        uint256 claimerBalanceAAfter = mockTokenA.balanceOf(ancestorIpId);
        uint256 claimerBalanceCAfter = mockTokenC.balanceOf(ancestorIpId);

        assertEq(amountsClaimed.length, 2); // there are 2 currency tokens
        assertEq(claimerBalanceAAfter - claimerBalanceABefore, amountsClaimed[0]);
        assertEq(claimerBalanceCAfter - claimerBalanceCBefore, amountsClaimed[1]);
        assertEq(
            claimerBalanceAAfter - claimerBalanceABefore,
            defaultMintingFeeA +
                defaultMintingFeeA + // 1000 + 1000 from minting fee of childIpA and childIpB
                (defaultMintingFeeA * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1000 * 10% = 100 royalty from childIpA
                (defaultMintingFeeA * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1000 * 10% = 100 royalty from childIpB
                (((defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent()) * defaultCommRevShareA) /
                royaltyModule.maxPercent() // 1000 * 10% * 10% = 10 royalty from grandChildIp
            // TODO(SP-XXX): Value should be 20 but MockIPGraph in @storyprotocol/test currently only supports
            // single-path calculation. This needs to be updated once MockIPGraph supports multi-path calculations.
        );
        assertEq(
            claimerBalanceCAfter - claimerBalanceCBefore,
            defaultMintingFeeC + (defaultMintingFeeC * defaultCommRevShareC) / royaltyModule.maxPercent() // 500 from from minting fee of childIpC, 500 * 20% = 100 royalty from childIpC
        );
    }

    function test_RoyaltyWorkflows_claimAllRevenue_withClaimRevenueData() public {
        _setupIpGraph();

        WorkflowStructs.ClaimRevenueData[] memory claimRevenueData = new WorkflowStructs.ClaimRevenueData[](5);

        claimRevenueData[0] = WorkflowStructs.ClaimRevenueData({
            childIpId: childIpIdA,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA)
        });

        claimRevenueData[1] = WorkflowStructs.ClaimRevenueData({
            childIpId: childIpIdB,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA)
        });

        claimRevenueData[2] = WorkflowStructs.ClaimRevenueData({
            childIpId: grandChildIpId,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA)
        });

        claimRevenueData[3] = WorkflowStructs.ClaimRevenueData({
            childIpId: childIpIdC,
            royaltyPolicy: address(royaltyPolicyLAP),
            currencyToken: address(mockTokenC)
        });

        claimRevenueData[4] = WorkflowStructs.ClaimRevenueData({
            childIpId: childIpIdD,
            royaltyPolicy: address(royaltyPolicyLAP),
            currencyToken: address(mockTokenA)
        });

        uint256 claimerBalanceABefore = mockTokenA.balanceOf(ancestorIpId);
        uint256 claimerBalanceCBefore = mockTokenC.balanceOf(ancestorIpId);

        // Expect the call to succeed although childIpD has no claimable royalty
        uint256[] memory amountsClaimed = royaltyWorkflows.claimAllRevenue({
            ancestorIpId: ancestorIpId,
            claimer: ancestorIpId,
            claimRevenueData: claimRevenueData
        });

        uint256 claimerBalanceAAfter = mockTokenA.balanceOf(ancestorIpId);
        uint256 claimerBalanceCAfter = mockTokenC.balanceOf(ancestorIpId);

        assertEq(amountsClaimed.length, 2); // there are 2 currency tokens
        assertEq(claimerBalanceAAfter - claimerBalanceABefore, amountsClaimed[0]);
        assertEq(claimerBalanceCAfter - claimerBalanceCBefore, amountsClaimed[1]);
        assertEq(
            claimerBalanceAAfter - claimerBalanceABefore,
            defaultMintingFeeA +
                defaultMintingFeeA + // 1000 + 1000 from minting fee of childIpA and childIpB
                (defaultMintingFeeA * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1000 * 10% = 100 royalty from childIpA
                (defaultMintingFeeA * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1000 * 10% = 100 royalty from childIpB
                (((defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent()) * defaultCommRevShareA) /
                royaltyModule.maxPercent() // 1000 * 10% * 10% = 10 royalty from grandChildIp
            // TODO(SP-XXX): Value should be 20 but MockIPGraph in @storyprotocol/test currently only supports
            // single-path calculation. This needs to be updated once MockIPGraph supports multi-path calculations.
        );
        assertEq(
            claimerBalanceCAfter - claimerBalanceCBefore,
            defaultMintingFeeC + (defaultMintingFeeC * defaultCommRevShareC) / royaltyModule.maxPercent() // 500 from from minting fee of childIpC, 500 * 20% = 100 royalty from childIpC
        );
    }

    // This test is to ensure that the claimAllRevenue function reverts when the transferToVault function reverts with an error that is not that the royalty policy has no claimable royalty
    function test_RoyaltyWorkflows_claimAllRevenue_revert_RoyaltyPolicyLAP__SameIpTransfer() public {
        _setupIpGraph();

        address[] memory childIpIds = new address[](1);
        address[] memory royaltyPolicies = new address[](1);
        address[] memory currencyTokens = new address[](1);

        childIpIds[0] = ancestorIpId;
        royaltyPolicies[0] = address(royaltyPolicyLAP);
        currencyTokens[0] = address(mockTokenA);

        vm.expectRevert(abi.encodeWithSelector(CoreErrors.RoyaltyPolicyLAP__SameIpTransfer.selector, ancestorIpId));
        royaltyWorkflows.claimAllRevenue({
            ancestorIpId: ancestorIpId,
            claimer: ancestorIpId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });
    }

    // This test is to ensure that the claimAllRevenue function reverts when the transferToVault function reverts with an error that is not that the royalty policy has no claimable royalty
    function test_RoyaltyWorkflows_claimAllRevenue_withClaimRevenueData_revert_RoyaltyPolicyLAP__SameIpTransfer()
        public
    {
        _setupIpGraph();

        WorkflowStructs.ClaimRevenueData[] memory claimRevenueData = new WorkflowStructs.ClaimRevenueData[](1);

        claimRevenueData[0] = WorkflowStructs.ClaimRevenueData({
            childIpId: ancestorIpId,
            royaltyPolicy: address(royaltyPolicyLAP),
            currencyToken: address(mockTokenA)
        });

        vm.expectRevert(abi.encodeWithSelector(CoreErrors.RoyaltyPolicyLAP__SameIpTransfer.selector, ancestorIpId));
        royaltyWorkflows.claimAllRevenue({
            ancestorIpId: ancestorIpId,
            claimer: ancestorIpId,
            claimRevenueData: claimRevenueData
        });
    }

    function _setupCurrencyTokens() private {
        mockTokenA = new MockERC20("MockTokenA", "MTA");
        mockTokenC = new MockERC20("MockTokenC", "MTC");

        mockTokenA.mint(u.alice, 100_000 ether);
        mockTokenA.mint(u.bob, 100_000 ether);
        mockTokenA.mint(u.dan, 100_000 ether);
        mockTokenC.mint(u.carl, 100_000 ether);

        vm.label(address(mockTokenA), "MockTokenA");
        vm.label(address(mockTokenC), "MockTokenC");

        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(mockTokenA), true);
        royaltyModule.whitelistRoyaltyToken(address(mockTokenC), true);
    }

    /// @dev Builds an IP graph as follows (TermsA is LRP, TermsC and TermsD are LAP):
    ///                                        ancestorIp (root)
    ///                                (owner: admin, TermsA + TermsC + TermsD)
    ///                      _________________________|______________________________________________________
    ///                    /                          |                           \                          \
    ///                   /                           |                            \                          \
    ///                childIpA                   childIpB                      childIpC                   childIpD
    ///        (owner: alice, TermsA)        (owner: bob, TermsA)          (owner: carl, TermsC)      (owner: dan, TermsD)
    ///                   \                          /                             /
    ///                    \________________________/                             /
    ///                                |                                         /
    ///                            grandChildIp                                 /
    ///                        (owner: dan, TermsA)                            /
    ///                                 \                                     /
    ///                                  \___________________________________/
    ///                                                    |
    ///    user 0xbeef mints `amountLicenseTokensToMint` grandChildIp and childIpC license tokens.
    ///
    /// - `ancestorIp`: It has 3 different commercial remix license terms attached. It has 3 child and 1 grandchild IPs.
    /// - `childIpA`: It has licenseTermsA attached, has 1 parent `ancestorIp`, and has 1 grandchild `grandChildIp`.
    /// - `childIpB`: It has licenseTermsA attached, has 1 parent `ancestorIp`, and has 1 grandchild `grandChildIp`.
    /// - `childIpC`: It has licenseTermsC attached, has 1 parent `ancestorIp`, and has 1 grandchild `grandChildIp`.
    /// - `grandChildIp`: It has licenseTermsA attached. It has 2 parents and 1 grandparent IPs.
    function _setupIpGraph() private {
        uint256 ancestorTokenId = mockNft.mint(u.admin);
        uint256 childTokenIdA = mockNft.mint(u.alice);
        uint256 childTokenIdB = mockNft.mint(u.bob);
        uint256 childTokenIdC = mockNft.mint(u.carl);
        uint256 childTokenIdD = mockNft.mint(u.dan);
        uint256 grandChildTokenId = mockNft.mint(u.dan);

        WorkflowStructs.IPMetadata memory emptyIpMetadata = WorkflowStructs.IPMetadata({
            ipMetadataURI: "",
            ipMetadataHash: "",
            nftMetadataURI: "",
            nftMetadataHash: ""
        });

        WorkflowStructs.SignatureData memory emptySigData = WorkflowStructs.SignatureData({
            signer: address(0),
            deadline: 0,
            signature: ""
        });

        // register ancestor IP
        ancestorIpId = ipAssetRegistry.register(block.chainid, address(mockNft), ancestorTokenId);
        vm.label(ancestorIpId, "AncestorIp");

        uint256 deadline = block.timestamp + 1000;

        // set permission for licensing module to attach license terms to ancestor IP
        {
            commTermsData.push(
                WorkflowStructs.LicenseTermsData({
                    terms: PILFlavors.commercialRemix({
                        mintingFee: defaultMintingFeeA,
                        commercialRevShare: defaultCommRevShareA,
                        royaltyPolicy: address(royaltyPolicyLRP),
                        currencyToken: address(mockTokenA)
                    }),
                    licensingConfig: Licensing.LicensingConfig({
                        isSet: true,
                        mintingFee: defaultMintingFeeA,
                        licensingHook: address(0),
                        hookData: "",
                        commercialRevShare: defaultCommRevShareA,
                        disabled: false,
                        expectMinimumGroupRewardShare: 0,
                        expectGroupRewardPool: evenSplitGroupPoolAddr
                    })
                })
            );
            commTermsData.push(
                WorkflowStructs.LicenseTermsData({
                    terms: PILFlavors.commercialRemix({
                        mintingFee: defaultMintingFeeC,
                        commercialRevShare: defaultCommRevShareC,
                        royaltyPolicy: address(royaltyPolicyLAP),
                        currencyToken: address(mockTokenC)
                    }),
                    licensingConfig: Licensing.LicensingConfig({
                        isSet: true,
                        mintingFee: defaultMintingFeeC,
                        licensingHook: address(0),
                        hookData: "",
                        commercialRevShare: defaultCommRevShareC,
                        disabled: false,
                        expectMinimumGroupRewardShare: 0,
                        expectGroupRewardPool: evenSplitGroupPoolAddr
                    })
                })
            );
            commTermsData.push(
                WorkflowStructs.LicenseTermsData({
                    terms: PILFlavors.commercialRemix({
                        mintingFee: defaultMintingFeeD,
                        commercialRevShare: defaultCommRevShareD,
                        royaltyPolicy: address(royaltyPolicyLAP),
                        currencyToken: address(mockTokenA)
                    }),
                    licensingConfig: Licensing.LicensingConfig({
                        isSet: true,
                        mintingFee: defaultMintingFeeD,
                        licensingHook: address(0),
                        hookData: "",
                        commercialRevShare: defaultCommRevShareD,
                        disabled: false,
                        expectMinimumGroupRewardShare: 0,
                        expectGroupRewardPool: evenSplitGroupPoolAddr
                    })
                })
            );

            (bytes memory signature, , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: ancestorIpId,
                permissionList: _getAttachTermsAndConfigPermissionList(
                    ancestorIpId,
                    address(licenseAttachmentWorkflows)
                ),
                deadline: deadline,
                state: bytes32(0),
                signerSk: sk.admin
            });

            // register and attach Terms A, C and D to ancestor IP
            uint256[] memory licenseTermsIds = licenseAttachmentWorkflows.registerPILTermsAndAttach({
                ipId: ancestorIpId,
                licenseTermsData: commTermsData,
                sigAttachAndConfig: WorkflowStructs.SignatureData({
                    signer: u.admin,
                    deadline: deadline,
                    signature: signature
                })
            });
            commRemixTermsIdA = licenseTermsIds[0];
            commRemixTermsIdC = licenseTermsIds[1];
            commRemixTermsIdD = licenseTermsIds[2];
        }

        // register childIpA as derivative of ancestorIp under Terms A
        {
            address childIpId = ipAssetRegistry.ipId(block.chainid, address(mockNft), childTokenIdA);
            (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: childIpId,
                permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                    childIpId,
                    address(derivativeWorkflows),
                    false
                ),
                deadline: deadline,
                state: bytes32(0),
                signerSk: sk.alice
            });

            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdA;

            vm.startPrank(u.alice);
            mockTokenA.approve(address(derivativeWorkflows), defaultMintingFeeA);
            childIpIdA = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(mockNft),
                tokenId: childTokenIdA,
                derivData: WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0,
                    maxRts: defaultCommRevShareA,
                    maxRevenueShare: 0
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadataAndRegister: WorkflowStructs.SignatureData({
                    signer: u.alice,
                    deadline: deadline,
                    signature: signatureMetadataAndRegister
                })
            });
            vm.stopPrank();
            vm.label(childIpIdA, "ChildIpA");
        }

        // register childIpB as derivative of ancestorIp under Terms A
        {
            address childIpId = ipAssetRegistry.ipId(block.chainid, address(mockNft), childTokenIdB);
            (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: childIpId,
                permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                    childIpId,
                    address(derivativeWorkflows),
                    false
                ),
                deadline: deadline,
                state: bytes32(0),
                signerSk: sk.bob
            });

            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdA;

            vm.startPrank(u.bob);
            mockTokenA.approve(address(derivativeWorkflows), defaultMintingFeeA);
            childIpIdB = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(mockNft),
                tokenId: childTokenIdB,
                derivData: WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0,
                    maxRts: defaultCommRevShareA,
                    maxRevenueShare: 0
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadataAndRegister: WorkflowStructs.SignatureData({
                    signer: u.bob,
                    deadline: deadline,
                    signature: signatureMetadataAndRegister
                })
            });
            vm.stopPrank();
            vm.label(childIpIdB, "ChildIpB");
        }

        /// register childIpC as derivative of ancestorIp under Terms C
        {
            address childIpId = ipAssetRegistry.ipId(block.chainid, address(mockNft), childTokenIdC);
            (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: childIpId,
                permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                    childIpId,
                    address(derivativeWorkflows),
                    false
                ),
                deadline: deadline,
                state: bytes32(0),
                signerSk: sk.carl
            });

            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdC;

            vm.startPrank(u.carl);
            mockTokenC.approve(address(derivativeWorkflows), defaultMintingFeeC);
            childIpIdC = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(mockNft),
                tokenId: childTokenIdC,
                derivData: WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0,
                    maxRts: defaultCommRevShareC,
                    maxRevenueShare: 0
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadataAndRegister: WorkflowStructs.SignatureData({
                    signer: u.carl,
                    deadline: deadline,
                    signature: signatureMetadataAndRegister
                })
            });
            vm.stopPrank();
            vm.label(childIpIdC, "ChildIpC");
        }

        // register childIpD as derivative of ancestorIp under Terms D
        {
            address childIpId = ipAssetRegistry.ipId(block.chainid, address(mockNft), childTokenIdD);
            (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: childIpId,
                permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                    childIpId,
                    address(derivativeWorkflows),
                    false
                ),
                deadline: deadline,
                state: bytes32(0),
                signerSk: sk.dan
            });

            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdD;

            vm.startPrank(u.dan);
            mockTokenA.approve(address(derivativeWorkflows), defaultMintingFeeD);
            childIpIdD = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(mockNft),
                tokenId: childTokenIdD,
                derivData: WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0,
                    maxRts: defaultCommRevShareD,
                    maxRevenueShare: 0
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadataAndRegister: WorkflowStructs.SignatureData({
                    signer: u.dan,
                    deadline: deadline,
                    signature: signatureMetadataAndRegister
                })
            });
            vm.stopPrank();
            vm.label(childIpIdD, "ChildIpD");
        }

        // register grandChildIp as derivative for childIp A and B under Terms A
        {
            address childIpId = ipAssetRegistry.ipId(block.chainid, address(mockNft), grandChildTokenId);
            (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: childIpId,
                permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                    childIpId,
                    address(derivativeWorkflows),
                    false
                ),
                deadline: deadline,
                state: bytes32(0),
                signerSk: sk.dan
            });

            address[] memory parentIpIds = new address[](2);
            uint256[] memory licenseTermsIds = new uint256[](2);
            parentIpIds[0] = childIpIdA;
            parentIpIds[1] = childIpIdB;
            for (uint256 i = 0; i < licenseTermsIds.length; i++) {
                licenseTermsIds[i] = commRemixTermsIdA;
            }

            vm.startPrank(u.dan);
            mockTokenA.approve(address(derivativeWorkflows), defaultMintingFeeA * parentIpIds.length);
            grandChildIpId = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(mockNft),
                tokenId: grandChildTokenId,
                derivData: WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0,
                    maxRts: uint32(defaultCommRevShareA * parentIpIds.length),
                    maxRevenueShare: 0
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadataAndRegister: WorkflowStructs.SignatureData({
                    signer: u.dan,
                    deadline: deadline,
                    signature: signatureMetadataAndRegister
                })
            });
            vm.stopPrank();
            vm.label(grandChildIpId, "GrandChildIp");
        }

        // user 0xbeef mints `amountLicenseTokensToMint` grandChildIp and childIpC license tokens
        {
            vm.startPrank(address(0xbeef));
            mockTokenA.mint(address(0xbeef), defaultMintingFeeA * amountLicenseTokensToMint);
            mockTokenA.approve(address(royaltyModule), defaultMintingFeeA * amountLicenseTokensToMint);

            // mint `amountLicenseTokensToMint` grandChildIp's license tokens
            licensingModule.mintLicenseTokens({
                licensorIpId: grandChildIpId,
                licenseTemplate: address(pilTemplate),
                licenseTermsId: commRemixTermsIdA,
                amount: amountLicenseTokensToMint,
                receiver: address(0xbeef),
                royaltyContext: "",
                maxMintingFee: 0,
                maxRevenueShare: 0
            });

            mockTokenC.mint(address(0xbeef), defaultMintingFeeC * amountLicenseTokensToMint);
            mockTokenC.approve(address(royaltyModule), defaultMintingFeeC * amountLicenseTokensToMint);

            // mint `amountLicenseTokensToMint` childIpC's license tokens
            licensingModule.mintLicenseTokens({
                licensorIpId: childIpIdC,
                licenseTemplate: address(pilTemplate),
                licenseTermsId: commRemixTermsIdC,
                amount: amountLicenseTokensToMint,
                receiver: address(0xbeef),
                royaltyContext: "",
                maxMintingFee: 0,
                maxRevenueShare: 0
            });
            vm.stopPrank();
        }
    }
}
