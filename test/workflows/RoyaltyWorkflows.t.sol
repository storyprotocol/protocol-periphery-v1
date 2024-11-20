//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

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
    address internal grandChildIpId;

    uint256 internal commRemixTermsIdA;
    MockERC20 internal mockTokenA;
    uint256 internal defaultMintingFeeA = 1000 ether;
    uint32 internal defaultCommRevShareA = 10 * 10 ** 6; // 10%

    uint256 internal commRemixTermsIdC;
    MockERC20 internal mockTokenC;
    uint256 internal defaultMintingFeeC = 500 ether;
    uint32 internal defaultCommRevShareC = 20 * 10 ** 6; // 20%

    uint256 internal amountLicenseTokensToMint = 1;

    function setUp() public override {
        super.setUp();

        _setupCurrencyTokens();
    }

    function test_RoyaltyWorkflows_transferToVaultAndClaimByTokenBatch() public {
        _setupIpGraph();

        address[] memory childIpIds = new address[](4);
        address[] memory royaltyPolicies = new address[](4);
        address[] memory currencyTokens = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        childIpIds[0] = childIpIdA;
        royaltyPolicies[0] = address(royaltyPolicyLRP);
        currencyTokens[0] = address(mockTokenA);
        amounts[0] = 10 ether;

        childIpIds[1] = childIpIdB;
        royaltyPolicies[1] = address(royaltyPolicyLRP);
        currencyTokens[1] = address(mockTokenA);
        amounts[1] = 10 ether;

        childIpIds[2] = grandChildIpId;
        royaltyPolicies[2] = address(royaltyPolicyLRP);
        currencyTokens[2] = address(mockTokenA);
        amounts[2] = 1 ether;

        childIpIds[3] = childIpIdC;
        royaltyPolicies[3] = address(royaltyPolicyLAP);
        currencyTokens[3] = address(mockTokenC);
        amounts[3] = 10 ether;

        uint256 claimerBalanceABefore = mockTokenA.balanceOf(ancestorIpId);
        uint256 claimerBalanceCBefore = mockTokenC.balanceOf(ancestorIpId);

        uint256[] memory amountsClaimed = royaltyWorkflows.transferToVaultAndClaimByTokenBatch({
            ancestorIpId: ancestorIpId,
            claimer: ancestorIpId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens,
            amounts: amounts
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
                10 ether + // 10 currency tokens from childIpA transferred to vault
                10 ether + // 10 currency tokens from childIpB transferred to vault
                1 ether // 1 currency token from grandChildIp transferred to vault
        );
        assertEq(
            claimerBalanceCAfter - claimerBalanceCBefore,
            defaultMintingFeeC + 10 ether // 10 currency tokens from childIpC transferred to vault
        );
    }

    function test_RoyaltyWorkflows_claimAllRevenue() public {
        _setupIpGraph();

        address[] memory childIpIds = new address[](4);
        address[] memory royaltyPolicies = new address[](4);
        address[] memory currencyTokens = new address[](4);

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

        uint256 claimerBalanceABefore = mockTokenA.balanceOf(ancestorIpId);
        uint256 claimerBalanceCBefore = mockTokenC.balanceOf(ancestorIpId);

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
            // TODO: should be 20 but MockIPGraph currently only supports single-path calculation
        );
        assertEq(
            claimerBalanceCAfter - claimerBalanceCBefore,
            defaultMintingFeeC + (defaultMintingFeeC * defaultCommRevShareC) / royaltyModule.maxPercent() // 500 from from minting fee of childIpC, 500 * 20% = 100 royalty from childIpC
        );
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

    /// @dev Builds an IP graph as follows (TermsA is LRP, TermsC is LAP):
    ///                                        ancestorIp (root)
    ///                                (owner: admin，TermsA + TermsC)
    ///                      _________________________|___________________________
    ///                    /                          |                           \
    ///                   /                           |                            \
    ///                childIpA                   childIpB                      childIpC
    ///        (owner: alice, TermsA)        (owner: bob, TermsA)          (owner: carl, TermsC)
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
    /// - `grandChildIp`: It has all 3 license terms attached. It has 3 parents and 1 grandparent IPs.
    function _setupIpGraph() private {
        uint256 ancestorTokenId = mockNft.mint(u.admin);
        uint256 childTokenIdA = mockNft.mint(u.alice);
        uint256 childTokenIdB = mockNft.mint(u.bob);
        uint256 childTokenIdC = mockNft.mint(u.carl);
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

        // get the signature for executing `attachLicenseTerms` function in `LicensingModule` on behalf of the IP owner
        {
            // TODO: this is a hack to get the license terms id, we should refactor this in the next PR
            uint256 licenseTermsId = IPILicenseTemplate(pilTemplate).registerLicenseTerms(
                PILFlavors.commercialRemix({
                    mintingFee: defaultMintingFeeA,
                    commercialRevShare: defaultCommRevShareA,
                    royaltyPolicy: address(royaltyPolicyLRP),
                    currencyToken: address(mockTokenA)
                })
            );
            (bytes memory signatureA, ) = _getSigForExecuteWithSig({
                ipId: ancestorIpId,
                to: address(licensingModule),
                deadline: deadline,
                state: IIPAccount(payable(ancestorIpId)).state(),
                data: abi.encodeWithSelector(
                    ILicensingModule.attachLicenseTerms.selector,
                    ancestorIpId,
                    pilTemplate,
                    licenseTermsId
                ),
                signerSk: sk.admin
            });

            // register and attach Terms A and C to ancestor IP
            commRemixTermsIdA = licenseAttachmentWorkflows.registerPILTermsAndAttach({
                ipId: ancestorIpId,
                terms: PILFlavors.commercialRemix({
                    mintingFee: defaultMintingFeeA,
                    commercialRevShare: defaultCommRevShareA,
                    royaltyPolicy: address(royaltyPolicyLRP),
                    currencyToken: address(mockTokenA)
                }),
                sigAttach: WorkflowStructs.SignatureData({ signer: u.admin, deadline: deadline, signature: signatureA })
            });
        }

        {
            // TODO: this is a hack to get the license terms id, we should refactor this in the next PR
            uint256 licenseTermsId = IPILicenseTemplate(pilTemplate).registerLicenseTerms(
                PILFlavors.commercialRemix({
                    mintingFee: defaultMintingFeeC,
                    commercialRevShare: defaultCommRevShareC,
                    royaltyPolicy: address(royaltyPolicyLAP),
                    currencyToken: address(mockTokenC)
                })
            );
            (bytes memory signatureC, ) = _getSigForExecuteWithSig({
                ipId: ancestorIpId,
                to: address(licensingModule),
                deadline: deadline,
                state: IIPAccount(payable(ancestorIpId)).state(),
                data: abi.encodeWithSelector(
                    ILicensingModule.attachLicenseTerms.selector,
                    ancestorIpId,
                    pilTemplate,
                    licenseTermsId
                ),
                signerSk: sk.admin
            });

            commRemixTermsIdC = licenseAttachmentWorkflows.registerPILTermsAndAttach({
                ipId: ancestorIpId,
                terms: PILFlavors.commercialRemix({
                    mintingFee: defaultMintingFeeC,
                    commercialRevShare: defaultCommRevShareC,
                    royaltyPolicy: address(royaltyPolicyLAP),
                    currencyToken: address(mockTokenC)
                }),
                sigAttach: WorkflowStructs.SignatureData({ signer: u.admin, deadline: deadline, signature: signatureC })
            });
        }

        // register childIpA as derivative of ancestorIp under Terms A
        {
            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdA;

            childIpIdA = ipAssetRegistry.ipId(block.chainid, address(mockNft), childTokenIdA);

            (bytes memory sigMintingFee, bytes32 expectedState) = _getSigForExecuteWithSig({
                ipId: childIpIdA,
                to: address(mockTokenA),
                deadline: deadline,
                state: bytes32(0),
                data: abi.encodeWithSelector(IERC20.approve.selector, address(royaltyModule), defaultMintingFeeA),
                signerSk: sk.alice
            });

            (bytes memory sigRegisterAlice, ) = _getSigForExecuteWithSig({
                ipId: childIpIdA,
                to: address(licensingModule),
                deadline: deadline,
                state: expectedState,
                data: abi.encodeWithSelector(
                    ILicensingModule.registerDerivative.selector,
                    childIpIdA,
                    parentIpIds,
                    licenseTermsIds,
                    address(pilTemplate),
                    "",
                    0
                ),
                signerSk: sk.alice
            });

            vm.startPrank(u.alice);
            // transfer the minting fee to childA IP account
            mockTokenA.approve(address(derivativeWorkflows), defaultMintingFeeA);

            childIpIdA = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(mockNft),
                tokenId: childTokenIdA,
                derivData: WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadata: emptySigData,
                sigMintingFee: WorkflowStructs.SignatureData({
                    signer: u.alice,
                    deadline: deadline,
                    signature: sigMintingFee
                }),
                sigRegister: WorkflowStructs.SignatureData({
                    signer: u.alice,
                    deadline: deadline,
                    signature: sigRegisterAlice
                })
            });
            vm.stopPrank();
            vm.label(childIpIdA, "ChildIpA");
        }

        // register childIpB as derivative of ancestorIp under Terms A
        {
            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdA;

            childIpIdB = ipAssetRegistry.ipId(block.chainid, address(mockNft), childTokenIdB);

            (bytes memory sigMintingFee, bytes32 expectedState) = _getSigForExecuteWithSig({
                ipId: childIpIdB,
                to: address(mockTokenA),
                deadline: deadline,
                state: bytes32(0),
                data: abi.encodeWithSelector(IERC20.approve.selector, address(royaltyModule), defaultMintingFeeA),
                signerSk: sk.bob
            });

            (bytes memory sigRegisterBob, ) = _getSigForExecuteWithSig({
                ipId: childIpIdB,
                to: address(licensingModule),
                deadline: deadline,
                state: expectedState,
                data: abi.encodeWithSelector(
                    ILicensingModule.registerDerivative.selector,
                    childIpIdB,
                    parentIpIds,
                    licenseTermsIds,
                    address(pilTemplate),
                    "",
                    0
                ),
                signerSk: sk.bob
            });

            vm.startPrank(u.bob);
            // transfer the minting fee to childB IP account
            mockTokenA.approve(address(derivativeWorkflows), defaultMintingFeeA);

            childIpIdB = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(mockNft),
                tokenId: childTokenIdB,
                derivData: WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadata: emptySigData,
                sigMintingFee: WorkflowStructs.SignatureData({
                    signer: u.bob,
                    deadline: deadline,
                    signature: sigMintingFee
                }),
                sigRegister: WorkflowStructs.SignatureData({
                    signer: u.bob,
                    deadline: deadline,
                    signature: sigRegisterBob
                })
            });
            vm.stopPrank();
            vm.label(childIpIdB, "ChildIpB");
        }

        /// register childIpC as derivative of ancestorIp under Terms C
        {
            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdC;

            childIpIdC = ipAssetRegistry.ipId(block.chainid, address(mockNft), childTokenIdC);

            (bytes memory sigMintingFee, bytes32 expectedState) = _getSigForExecuteWithSig({
                ipId: childIpIdC,
                to: address(mockTokenC),
                deadline: deadline,
                state: bytes32(0),
                data: abi.encodeWithSelector(IERC20.approve.selector, address(royaltyModule), defaultMintingFeeC),
                signerSk: sk.carl
            });

            (bytes memory sigRegisterCarl, ) = _getSigForExecuteWithSig({
                ipId: childIpIdC,
                to: address(licensingModule),
                deadline: deadline,
                state: expectedState,
                data: abi.encodeWithSelector(
                    ILicensingModule.registerDerivative.selector,
                    childIpIdC,
                    parentIpIds,
                    licenseTermsIds,
                    address(pilTemplate),
                    "",
                    0
                ),
                signerSk: sk.carl
            });

            vm.startPrank(u.carl);
            // transfer the minting fee to childC IP account
            mockTokenC.approve(address(derivativeWorkflows), defaultMintingFeeC);

            childIpIdC = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(mockNft),
                tokenId: childTokenIdC,
                derivData: WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadata: emptySigData,
                sigMintingFee: WorkflowStructs.SignatureData({
                    signer: u.carl,
                    deadline: deadline,
                    signature: sigMintingFee
                }),
                sigRegister: WorkflowStructs.SignatureData({
                    signer: u.carl,
                    deadline: deadline,
                    signature: sigRegisterCarl
                })
            });
            vm.stopPrank();
            vm.label(childIpIdC, "ChildIpC");
        }

        // register grandChildIp as derivative for childIp A and B under Terms A
        {
            address[] memory parentIpIds = new address[](2);
            uint256[] memory licenseTermsIds = new uint256[](2);
            parentIpIds[0] = childIpIdA;
            parentIpIds[1] = childIpIdB;
            for (uint256 i = 0; i < licenseTermsIds.length; i++) {
                licenseTermsIds[i] = commRemixTermsIdA;
            }

            grandChildIpId = ipAssetRegistry.ipId(block.chainid, address(mockNft), grandChildTokenId);

            (bytes memory sigMintingFee, bytes32 expectedState) = _getSigForExecuteWithSig({
                ipId: grandChildIpId,
                to: address(mockTokenA),
                deadline: deadline,
                state: bytes32(0),
                data: abi.encodeWithSelector(
                    IERC20.approve.selector,
                    address(royaltyModule),
                    defaultMintingFeeA * parentIpIds.length
                ),
                signerSk: sk.dan
            });

            (bytes memory sigRegisterDan, ) = _getSigForExecuteWithSig({
                ipId: grandChildIpId,
                to: address(licensingModule),
                deadline: deadline,
                state: expectedState,
                data: abi.encodeWithSelector(
                    ILicensingModule.registerDerivative.selector,
                    grandChildIpId,
                    parentIpIds,
                    licenseTermsIds,
                    address(pilTemplate),
                    "",
                    0
                ),
                signerSk: sk.dan
            });

            vm.startPrank(u.dan);
            // transfer the minting fee to grandChild IP account
            mockTokenA.approve(address(derivativeWorkflows), defaultMintingFeeA * parentIpIds.length);

            grandChildIpId = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(mockNft),
                tokenId: grandChildTokenId,
                derivData: WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadata: emptySigData,
                sigMintingFee: WorkflowStructs.SignatureData({
                    signer: u.dan,
                    deadline: deadline,
                    signature: sigMintingFee
                }),
                sigRegister: WorkflowStructs.SignatureData({
                    signer: u.dan,
                    deadline: deadline,
                    signature: sigRegisterDan
                })
            });
            vm.stopPrank();
            vm.label(grandChildIpId, "GrandChildIp");
        }

        // uesr 0xbeef mints `amountLicenseTokensToMint` grandChildIp and childIpC license tokens
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
                maxMintingFee: 0
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
                maxMintingFee: 0
            });
            vm.stopPrank();
        }
    }
}
