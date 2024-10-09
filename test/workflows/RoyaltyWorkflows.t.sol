//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { IpRoyaltyVault } from "@storyprotocol/core/modules/royalty/policies/IpRoyaltyVault.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

// contracts
import { IRoyaltyWorkflows } from "../../contracts/interfaces/workflows/IRoyaltyWorkflows.sol";
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

    uint256[] internal unclaimedSnapshotIds;

    function setUp() public override {
        super.setUp();

        _setupCurrencyTokens();
    }

    function test_RoyaltyWorkflows_transferToVaultAndSnapshotAndClaimByTokenBatch() public {
        // setup IP graph with no snapshot
        uint256 numSnapshots = 0;
        _setupIpGraph(numSnapshots);

        IRoyaltyWorkflows.RoyaltyClaimDetails[] memory claimDetails = new IRoyaltyWorkflows.RoyaltyClaimDetails[](4);
        claimDetails[0] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdA,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA),
            amount: (defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% = 100
        });

        claimDetails[1] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdB,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA),
            amount: (defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% = 100
        });

        claimDetails[2] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: grandChildIpId,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA),
            amount: (((defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent()) *
                defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% * 10% = 10
            // TODO: should be (1000 * 10% * 10%) * 2 = 20 but MockIPGraph currently only supports single-path calculation
        });

        claimDetails[3] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdC,
            royaltyPolicy: address(royaltyPolicyLAP),
            currencyToken: address(mockTokenC),
            amount: (defaultMintingFeeC * defaultCommRevShareC) / royaltyModule.maxPercent() // 500 * 20% = 100
        });

        uint256 claimerBalanceABefore = mockTokenA.balanceOf(u.admin);
        uint256 claimerBalanceCBefore = mockTokenC.balanceOf(u.admin);

        (uint256 snapshotId, uint256[] memory amountsClaimed) = royaltyWorkflows
            .transferToVaultAndSnapshotAndClaimByTokenBatch({
                ancestorIpId: ancestorIpId,
                claimer: u.admin,
                royaltyClaimDetails: claimDetails
            });

        uint256 claimerBalanceAAfter = mockTokenA.balanceOf(u.admin);
        uint256 claimerBalanceCAfter = mockTokenC.balanceOf(u.admin);

        assertEq(snapshotId, numSnapshots + 1);
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
            defaultMintingFeeC + (defaultMintingFeeC * defaultCommRevShareC) / royaltyModule.maxPercent() // 500 from from minting fee of childIpC // 500 * 20% = 100 royalty from childIpC
        );
    }

    function test_RoyaltyWorkflows_transferToVaultAndSnapshotAndClaimBySnapshotBatch() public {
        // setup IP graph and takes 3 snapshots of ancestor IP's royalty vault
        uint256 numSnapshots = 3;
        _setupIpGraph(numSnapshots);

        IRoyaltyWorkflows.RoyaltyClaimDetails[] memory claimDetails = new IRoyaltyWorkflows.RoyaltyClaimDetails[](4);
        claimDetails[0] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdA,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA),
            amount: (defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% = 100
        });

        claimDetails[1] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdB,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA),
            amount: (defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% = 100
        });

        claimDetails[2] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: grandChildIpId,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA),
            amount: (((defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent()) *
                defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% * 10% = 10
        });

        claimDetails[3] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdC,
            royaltyPolicy: address(royaltyPolicyLAP),
            currencyToken: address(mockTokenC),
            amount: (defaultMintingFeeC * defaultCommRevShareC) / royaltyModule.maxPercent() // 500 * 20% = 100
        });

        uint256 claimerBalanceABefore = mockTokenA.balanceOf(u.admin);
        uint256 claimerBalanceCBefore = mockTokenC.balanceOf(u.admin);

        (uint256 snapshotId, uint256[] memory amountsClaimed) = royaltyWorkflows
            .transferToVaultAndSnapshotAndClaimBySnapshotBatch({
                ancestorIpId: ancestorIpId,
                claimer: u.admin,
                unclaimedSnapshotIds: unclaimedSnapshotIds,
                royaltyClaimDetails: claimDetails
            });

        uint256 claimerBalanceAAfter = mockTokenA.balanceOf(u.admin);
        uint256 claimerBalanceCAfter = mockTokenC.balanceOf(u.admin);

        assertEq(snapshotId, numSnapshots + 1);
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
        );
        assertEq(
            claimerBalanceCAfter - claimerBalanceCBefore,
            defaultMintingFeeC + (defaultMintingFeeC * defaultCommRevShareC) / royaltyModule.maxPercent() // 500 from minting fee of childIpC // 500 * 20% = 100 royalty from childIpC
        );
    }

    function test_RoyaltyWorkflows_revert_transferToVaultAndSnapshotAndClaimBySnapshotBatch() public {
        // setup IP graph and takes 3 snapshots of ancestor IP's royalty vault
        uint256 numSnapshots = 3;
        _setupIpGraph(numSnapshots);

        IRoyaltyWorkflows.RoyaltyClaimDetails[] memory claimDetails = new IRoyaltyWorkflows.RoyaltyClaimDetails[](4);
        claimDetails[0] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdA,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA),
            amount: (defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% = 100
        });

        claimDetails[1] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdB,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA),
            amount: (defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% = 100
        });

        claimDetails[2] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: grandChildIpId,
            royaltyPolicy: address(royaltyPolicyLRP),
            currencyToken: address(mockTokenA),
            amount: (((defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent()) *
                defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% * 10% = 10
        });

        claimDetails[3] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdC,
            royaltyPolicy: address(royaltyPolicyLAP),
            currencyToken: address(mockTokenC),
            amount: (defaultMintingFeeC * defaultCommRevShareC) / royaltyModule.maxPercent() // 500 * 20% = 100
        });

        address ancestorVault = royaltyModule.ipRoyaltyVaults(ancestorIpId);

        vm.expectRevert(CoreErrors.IpRoyaltyVault__VaultsMustClaimAsSelf.selector);
        royaltyWorkflows.transferToVaultAndSnapshotAndClaimBySnapshotBatch({
            ancestorIpId: ancestorIpId,
            claimer: ancestorVault,
            unclaimedSnapshotIds: unclaimedSnapshotIds,
            royaltyClaimDetails: claimDetails
        });
    }

    function test_RoyaltyWorkflows_snapshotAndClaimByTokenBatch() public {
        // setup IP graph with no snapshot
        uint256 numSnapshots = 0;
        _setupIpGraph(numSnapshots);

        address[] memory currencyTokens = new address[](2);
        currencyTokens[0] = address(mockTokenA);
        currencyTokens[1] = address(mockTokenC);

        uint256 claimerBalanceABefore = mockTokenA.balanceOf(u.admin);
        uint256 claimerBalanceCBefore = mockTokenC.balanceOf(u.admin);

        (uint256 snapshotId, uint256[] memory amountsClaimed) = royaltyWorkflows.snapshotAndClaimByTokenBatch({
            ipId: ancestorIpId,
            claimer: u.admin,
            currencyTokens: currencyTokens
        });

        uint256 claimerBalanceAAfter = mockTokenA.balanceOf(u.admin);
        uint256 claimerBalanceCAfter = mockTokenC.balanceOf(u.admin);

        assertEq(snapshotId, numSnapshots + 1);
        assertEq(amountsClaimed.length, 2); // there are 2 currency tokens
        assertEq(claimerBalanceAAfter - claimerBalanceABefore, amountsClaimed[0]);
        assertEq(claimerBalanceCAfter - claimerBalanceCBefore, amountsClaimed[1]);
        assertEq(
            claimerBalanceAAfter - claimerBalanceABefore,
            defaultMintingFeeA + defaultMintingFeeA // 1000 + 1000 from minting fee of childIpA and childIpB
        );
        assertEq(
            claimerBalanceCAfter - claimerBalanceCBefore,
            defaultMintingFeeC // 500 from from minting fee of childIpC
        );
    }

    function test_RoyaltyWorkflows_snapshotAndClaimBySnapshotBatch() public {
        // setup IP graph and takes 1 snapshot of ancestor IP's royalty vault
        uint256 numSnapshots = 1;
        _setupIpGraph(numSnapshots);

        address[] memory currencyTokens = new address[](2);
        currencyTokens[0] = address(mockTokenA);
        currencyTokens[1] = address(mockTokenC);

        uint256 claimerBalanceABefore = mockTokenA.balanceOf(u.admin);
        uint256 claimerBalanceCBefore = mockTokenC.balanceOf(u.admin);

        (uint256 snapshotId, uint256[] memory amountsClaimed) = royaltyWorkflows.snapshotAndClaimBySnapshotBatch({
            ipId: ancestorIpId,
            claimer: u.admin,
            unclaimedSnapshotIds: unclaimedSnapshotIds,
            currencyTokens: currencyTokens
        });

        uint256 claimerBalanceAAfter = mockTokenA.balanceOf(u.admin);
        uint256 claimerBalanceCAfter = mockTokenC.balanceOf(u.admin);

        assertEq(snapshotId, numSnapshots + 1);
        assertEq(amountsClaimed.length, 2); // there are 2 currency tokens
        assertEq(claimerBalanceAAfter - claimerBalanceABefore, amountsClaimed[0]);
        assertEq(claimerBalanceCAfter - claimerBalanceCBefore, amountsClaimed[1]);
        assertEq(
            claimerBalanceAAfter - claimerBalanceABefore,
            defaultMintingFeeA + defaultMintingFeeA // 1000 + 1000 from minting fee of childIpA and childIpB
        );
        assertEq(
            claimerBalanceCAfter - claimerBalanceCBefore,
            defaultMintingFeeC // 500 from from minting fee of childIpC
        );
    }

    function test_RoyaltyWorkflows_revert_snapshotAndClaimBySnapshotBatch() public {
        // setup IP graph and takes 1 snapshot of ancestor IP's royalty vault
        uint256 numSnapshots = 1;
        _setupIpGraph(numSnapshots);

        address[] memory currencyTokens = new address[](2);
        currencyTokens[0] = address(mockTokenA);
        currencyTokens[1] = address(mockTokenC);

        address ancestorVault = royaltyModule.ipRoyaltyVaults(ancestorIpId);

        vm.expectRevert(CoreErrors.IpRoyaltyVault__VaultsMustClaimAsSelf.selector);
        royaltyWorkflows.snapshotAndClaimBySnapshotBatch({
            ipId: ancestorIpId,
            claimer: ancestorVault,
            unclaimedSnapshotIds: unclaimedSnapshotIds,
            currencyTokens: currencyTokens
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
    /// @param numSnapshots The number of snapshots to take of the ancestor IP's royalty vault.
    function _setupIpGraph(uint256 numSnapshots) private {
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

        unclaimedSnapshotIds = new uint256[](numSnapshots);

        // register ancestor IP
        ancestorIpId = ipAssetRegistry.register(block.chainid, address(mockNft), ancestorTokenId);
        vm.label(ancestorIpId, "AncestorIp");

        uint256 deadline = block.timestamp + 1000;

        // set permission for licensing module to attach license terms to ancestor IP
        {
            (bytes memory signatureA, , ) = _getSetPermissionSigForPeriphery({
                ipId: ancestorIpId,
                to: address(licenseAttachmentWorkflows),
                module: address(licensingModule),
                selector: licensingModule.attachLicenseTerms.selector,
                deadline: deadline,
                state: IIPAccount(payable(ancestorIpId)).state(),
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
            (bytes memory signatureC, , ) = _getSetPermissionSigForPeriphery({
                ipId: ancestorIpId,
                to: address(licenseAttachmentWorkflows),
                module: address(licensingModule),
                selector: licensingModule.attachLicenseTerms.selector,
                deadline: deadline,
                state: IIPAccount(payable(ancestorIpId)).state(),
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
            (bytes memory sigRegisterAlice, , ) = _getSetPermissionSigForPeriphery({
                ipId: ipAssetRegistry.ipId(block.chainid, address(mockNft), childTokenIdA),
                to: address(derivativeWorkflows),
                module: address(licensingModule),
                selector: licensingModule.registerDerivative.selector,
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
                    royaltyContext: ""
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadata: emptySigData,
                sigRegister: WorkflowStructs.SignatureData({
                    signer: u.alice,
                    deadline: deadline,
                    signature: sigRegisterAlice
                })
            });
            vm.stopPrank();
            vm.label(childIpIdA, "ChildIpA");
        }

        IpRoyaltyVault ancestorIpRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(ancestorIpId));

        // transfer all ancestor royalties tokens to the claimer of the ancestor IP
        {
            vm.startPrank(ancestorIpId);
            ancestorIpRoyaltyVault.transfer(u.admin, ancestorIpRoyaltyVault.totalSupply());
            vm.stopPrank();
        }

        // takes a snapshot of the ancestor IP's royalty vault and populates unclaimedSnapshotIds
        // In this snapshot:
        // - admin has all the royalty tokens from ancestorIp
        // - ancestorIp's royalty vault has `defaultMintingFeeA` tokens from alice for registering childIpA
        // as derivative of ancestorIp under Terms A
        if (numSnapshots >= 1) {
            unclaimedSnapshotIds[0] = ancestorIpRoyaltyVault.snapshot();
            numSnapshots--;
        }

        // register childIpB as derivative of ancestorIp under Terms A
        {
            (bytes memory sigRegisterBob, , ) = _getSetPermissionSigForPeriphery({
                ipId: ipAssetRegistry.ipId(block.chainid, address(mockNft), childTokenIdB),
                to: address(derivativeWorkflows),
                module: address(licensingModule),
                selector: licensingModule.registerDerivative.selector,
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
                    royaltyContext: ""
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadata: emptySigData,
                sigRegister: WorkflowStructs.SignatureData({
                    signer: u.bob,
                    deadline: deadline,
                    signature: sigRegisterBob
                })
            });
            vm.stopPrank();
            vm.label(childIpIdB, "ChildIpB");
        }

        // takes a snapshot of the ancestor IP's royalty vault and populates unclaimedSnapshotIds
        // In this snapshot:
        // - admin has all the royalty tokens from ancestorIp
        // - ancestorIp's royalty vault has `defaultMintingFeeA` tokens from bob for registering childIpB
        // as derivative of ancestorIp under Terms A
        if (numSnapshots >= 1) {
            unclaimedSnapshotIds[1] = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(ancestorIpId)).snapshot();
            numSnapshots--;
        }

        /// register childIpC as derivative of ancestorIp under Terms C
        {
            (bytes memory sigRegisterCarl, , ) = _getSetPermissionSigForPeriphery({
                ipId: ipAssetRegistry.ipId(block.chainid, address(mockNft), childTokenIdC),
                to: address(derivativeWorkflows),
                module: address(licensingModule),
                selector: licensingModule.registerDerivative.selector,
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
                    royaltyContext: ""
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadata: emptySigData,
                sigRegister: WorkflowStructs.SignatureData({
                    signer: u.carl,
                    deadline: deadline,
                    signature: sigRegisterCarl
                })
            });
            vm.stopPrank();
            vm.label(childIpIdC, "ChildIpC");
        }

        // takes a snapshot of the ancestor IP's royalty vault and populates unclaimedSnapshotIds
        // In this snapshot:
        // - admin has all the royalty tokens from ancestorIp
        // - ancestorIp's royalty vault has `defaultMintingFeeC` tokens from carl for registering childIpC
        // as derivative of ancestorIp under Terms C
        if (numSnapshots >= 1) {
            unclaimedSnapshotIds[2] = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(ancestorIpId)).snapshot();
            numSnapshots--;
        }

        // register grandChildIp as derivative for childIp A and B under Terms A
        {
            (bytes memory sigRegisterDan, , ) = _getSetPermissionSigForPeriphery({
                ipId: ipAssetRegistry.ipId(block.chainid, address(mockNft), grandChildTokenId),
                to: address(derivativeWorkflows),
                module: address(licensingModule),
                selector: licensingModule.registerDerivative.selector,
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
                    royaltyContext: ""
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadata: emptySigData,
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
                royaltyContext: ""
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
                royaltyContext: ""
            });
            vm.stopPrank();
        }
    }
}
