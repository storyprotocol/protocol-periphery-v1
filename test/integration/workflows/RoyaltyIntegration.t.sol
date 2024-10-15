// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { IpRoyaltyVault } from "@storyprotocol/core/modules/royalty/policies/IpRoyaltyVault.sol";
import { IVaultController } from "@storyprotocol/core/interfaces/modules/royalty/policies/IVaultController.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { IRoyaltyWorkflows } from "../../../contracts/interfaces/workflows/IRoyaltyWorkflows.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";
// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

contract RoyaltyIntegration is BaseIntegration {
    using Strings for uint256;

    ISPGNFT private spgNftContract;

    address internal ancestorIpId;
    address internal childIpIdA;
    address internal childIpIdB;
    address internal childIpIdC;
    address internal grandChildIpId;

    uint256 internal commRemixTermsIdA;
    uint256 internal defaultMintingFeeA = 1000 * 10 ** StoryUSD.decimals(); // 1000 SUSD
    uint32 internal defaultCommRevShareA = 10 * 10 ** 6; // 10%

    uint256 internal commRemixTermsIdC;
    uint256 internal defaultMintingFeeC = 500 * 10 ** StoryUSD.decimals(); // 500 SUSD
    uint32 internal defaultCommRevShareC = 20 * 10 ** 6; // 20%

    uint256 internal amountLicenseTokensToMint = 1;

    uint256[] internal unclaimedSnapshotIds;

    /// @notice This test can only be run when royalty module's snapshot interval is 0.
    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/RoyaltyIntegration.t.sol:RoyaltyIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();
        if (IVaultController(royaltyModuleAddr).snapshotInterval() != 0) {
            console2.log("RoyaltyIntegration did not run: snapshot interval is not zero");
            return;
        }
        _setupTest();
        _test_RoyaltyIntegration_transferToVaultAndSnapshotAndClaimByTokenBatch();
        _test_RoyaltyIntegration_snapshotAndClaimByTokenBatch();
        _test_RoyaltyIntegration_transferToVaultAndSnapshotAndClaimBySnapshotBatch();
        _test_RoyaltyIntegration_snapshotAndClaimBySnapshotBatch();
        _endBroadcast();
    }

    function _test_RoyaltyIntegration_transferToVaultAndSnapshotAndClaimByTokenBatch()
        private
        logTest("test_RoyaltyIntegration_transferToVaultAndSnapshotAndClaimByTokenBatch")
    {
        // setup IP graph with no snapshot
        uint256 numSnapshots = 0;
        _setupIpGraph(numSnapshots);

        IRoyaltyWorkflows.RoyaltyClaimDetails[] memory claimDetails = new IRoyaltyWorkflows.RoyaltyClaimDetails[](4);
        claimDetails[0] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdA,
            royaltyPolicy: royaltyPolicyLRPAddr,
            currencyToken: address(StoryUSD),
            amount: (defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% = 100
        });

        claimDetails[1] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdB,
            royaltyPolicy: royaltyPolicyLRPAddr,
            currencyToken: address(StoryUSD),
            amount: (defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% = 100
        });

        claimDetails[2] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: grandChildIpId,
            royaltyPolicy: royaltyPolicyLRPAddr,
            currencyToken: address(StoryUSD),
            amount: (((defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent()) *
                defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% * 10% * 2 = 20
        });

        claimDetails[3] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdC,
            royaltyPolicy: royaltyPolicyLAPAddr,
            currencyToken: address(StoryUSD),
            amount: (defaultMintingFeeC * defaultCommRevShareC) / royaltyModule.maxPercent() // 500 * 20% = 100
        });

        uint256 claimerBalanceBefore = StoryUSD.balanceOf(testSender);

        (uint256 snapshotId, uint256[] memory amountsClaimed) = royaltyWorkflows
            .transferToVaultAndSnapshotAndClaimByTokenBatch({
                ancestorIpId: ancestorIpId,
                claimer: testSender,
                royaltyClaimDetails: claimDetails
            });

        uint256 claimerBalanceAfter = StoryUSD.balanceOf(testSender);

        assertEq(snapshotId, numSnapshots + 1);
        assertEq(amountsClaimed.length, 1); // there is 1 currency token
        assertEq(claimerBalanceAfter - claimerBalanceBefore, amountsClaimed[0]);
        assertEq(
            claimerBalanceAfter - claimerBalanceBefore,
            defaultMintingFeeA +
                defaultMintingFeeA + // 1000 + 1000 from minting fee of childIpA and childIpB
                (defaultMintingFeeA * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1000 * 10% = 100 royalty from childIpA
                (defaultMintingFeeA * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1000 * 10% = 100 royalty from childIpB
                (((defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent()) * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1000 * 10% * 10% * 2 = 20 royalty from grandChildIp
                defaultMintingFeeC +
                (defaultMintingFeeC * defaultCommRevShareC) /
                royaltyModule.maxPercent() // 500 from from minting fee of childIpC,500 * 20% = 100 royalty from childIpC
        );
    }

    function _test_RoyaltyIntegration_transferToVaultAndSnapshotAndClaimBySnapshotBatch()
        private
        logTest("test_RoyaltyIntegration_transferToVaultAndSnapshotAndClaimBySnapshotBatch")
    {
        // setup IP graph and takes 3 snapshots of ancestor IP's royalty vault
        uint256 numSnapshots = 3;
        _setupIpGraph(numSnapshots);

        IRoyaltyWorkflows.RoyaltyClaimDetails[] memory claimDetails = new IRoyaltyWorkflows.RoyaltyClaimDetails[](4);
        claimDetails[0] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdA,
            royaltyPolicy: royaltyPolicyLRPAddr,
            currencyToken: address(StoryUSD),
            amount: (defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% = 100
        });

        claimDetails[1] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdB,
            royaltyPolicy: royaltyPolicyLRPAddr,
            currencyToken: address(StoryUSD),
            amount: (defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% = 100
        });

        claimDetails[2] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: grandChildIpId,
            royaltyPolicy: royaltyPolicyLRPAddr,
            currencyToken: address(StoryUSD),
            amount: (((defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent()) *
                defaultCommRevShareA) / royaltyModule.maxPercent() // 1000 * 10% * 10% = 10
        });

        claimDetails[3] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpIdC,
            royaltyPolicy: royaltyPolicyLAPAddr,
            currencyToken: address(StoryUSD),
            amount: (defaultMintingFeeC * defaultCommRevShareC) / royaltyModule.maxPercent() // 500 * 20% = 100
        });

        uint256 claimerBalanceBefore = StoryUSD.balanceOf(testSender);

        (uint256 snapshotId, uint256[] memory amountsClaimed) = royaltyWorkflows
            .transferToVaultAndSnapshotAndClaimBySnapshotBatch({
                ancestorIpId: ancestorIpId,
                claimer: testSender,
                unclaimedSnapshotIds: unclaimedSnapshotIds,
                royaltyClaimDetails: claimDetails
            });

        uint256 claimerBalanceAfter = StoryUSD.balanceOf(testSender);

        assertEq(snapshotId, numSnapshots + 1);
        assertEq(amountsClaimed.length, 1); // there is 1 currency token
        assertEq(claimerBalanceAfter - claimerBalanceBefore, amountsClaimed[0]);
        assertEq(
            claimerBalanceAfter - claimerBalanceBefore,
            defaultMintingFeeA +
                defaultMintingFeeA + // 1000 + 1000 from minting fee of childIpA and childIpB
                (defaultMintingFeeA * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1000 * 10% = 100 royalty from childIpA
                (defaultMintingFeeA * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1000 * 10% = 100 royalty from childIpB
                (((defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent()) * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1000 * 10% * 10% = 10 royalty from grandChildIp
                defaultMintingFeeC +
                (defaultMintingFeeC * defaultCommRevShareC) /
                royaltyModule.maxPercent() // 500 from from minting fee of childIpC, 500 * 20% = 100 royalty from childIpC
        );
    }

    function _test_RoyaltyIntegration_snapshotAndClaimByTokenBatch()
        private
        logTest("test_RoyaltyIntegration_snapshotAndClaimByTokenBatch")
    {
        // setup IP graph with no snapshot
        uint256 numSnapshots = 0;
        _setupIpGraph(numSnapshots);

        address[] memory currencyTokens = new address[](1);
        currencyTokens[0] = address(StoryUSD);

        uint256 claimerBalanceBefore = StoryUSD.balanceOf(testSender);

        (uint256 snapshotId, uint256[] memory amountsClaimed) = royaltyWorkflows.snapshotAndClaimByTokenBatch({
            ipId: ancestorIpId,
            claimer: testSender,
            currencyTokens: currencyTokens
        });

        uint256 claimerBalanceAfter = StoryUSD.balanceOf(testSender);

        assertEq(snapshotId, numSnapshots + 1);
        assertEq(amountsClaimed.length, 1); // there is 1 currency token
        assertEq(claimerBalanceAfter - claimerBalanceBefore, amountsClaimed[0]);
        assertEq(
            claimerBalanceAfter - claimerBalanceBefore,
            // 1000 + 1000 + 500 from minting fee of childIpA, childIpB, and childIpC
            defaultMintingFeeA + defaultMintingFeeA + defaultMintingFeeC
        );
    }

    function _test_RoyaltyIntegration_snapshotAndClaimBySnapshotBatch()
        private
        logTest("test_RoyaltyIntegration_snapshotAndClaimBySnapshotBatch")
    {
        // setup IP graph and takes 1 snapshot of ancestor IP's royalty vault
        uint256 numSnapshots = 1;
        _setupIpGraph(numSnapshots);

        address[] memory currencyTokens = new address[](1);
        currencyTokens[0] = address(StoryUSD);

        uint256 claimerBalanceBefore = StoryUSD.balanceOf(testSender);

        (uint256 snapshotId, uint256[] memory amountsClaimed) = royaltyWorkflows.snapshotAndClaimBySnapshotBatch({
            ipId: ancestorIpId,
            claimer: testSender,
            unclaimedSnapshotIds: unclaimedSnapshotIds,
            currencyTokens: currencyTokens
        });

        uint256 claimerBalanceAfter = StoryUSD.balanceOf(testSender);

        assertEq(snapshotId, numSnapshots + 1);
        assertEq(amountsClaimed.length, 1); // there is 1 currency token
        assertEq(claimerBalanceAfter - claimerBalanceBefore, amountsClaimed[0]);
        assertEq(
            claimerBalanceAfter - claimerBalanceBefore,
            // 1000 + 1000 + 500 from minting fee of childIpA, childIpB, and childIpC
            defaultMintingFeeA + defaultMintingFeeA + defaultMintingFeeC
        );
    }

    /// @dev Builds an IP graph as follows (TermsA is LRP, TermsC is LAP):
    ///                                        ancestorIp (root)
    ///                                        (TermsA + TermsC)
    ///                      _________________________|___________________________
    ///                    /                          |                           \
    ///                   /                           |                            \
    ///                childIpA                   childIpB                      childIpC
    ///                (TermsA)                  (TermsA)                      (TermsC)
    ///                   \                          /                             /
    ///                    \________________________/                             /
    ///                                |                                         /
    ///                            grandChildIp                                 /
    ///                             (TermsA)                                   /
    ///                                 \                                     /
    ///                                  \___________________________________/
    ///                                                    |
    ///             mints `amountLicenseTokensToMint` grandChildIp and childIpC license tokens.
    ///
    /// - `ancestorIp`: It has 3 different commercial remix license terms attached. It has 3 child and 1 grandchild IPs.
    /// - `childIpA`: It has licenseTermsA attached, has 1 parent `ancestorIp`, and has 1 grandchild `grandChildIp`.
    /// - `childIpB`: It has licenseTermsA attached, has 1 parent `ancestorIp`, and has 1 grandchild `grandChildIp`.
    /// - `childIpC`: It has licenseTermsC attached, has 1 parent `ancestorIp`, and has 1 grandchild `grandChildIp`.
    /// - `grandChildIp`: It has all 3 license terms attached. It has 3 parents and 1 grandparent IPs.
    /// @param numSnapshots The number of snapshots to take of the ancestor IP's royalty vault.
    function _setupIpGraph(uint256 numSnapshots) private {
        uint256 ancestorTokenId = spgNftContract.mint(testSender, "");
        uint256 childTokenIdA = spgNftContract.mint(testSender, "");
        uint256 childTokenIdB = spgNftContract.mint(testSender, "");
        uint256 childTokenIdC = spgNftContract.mint(testSender, "");
        uint256 grandChildTokenId = spgNftContract.mint(testSender, "");

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
        ancestorIpId = ipAssetRegistry.register(block.chainid, address(spgNftContract), ancestorTokenId);
        vm.label(ancestorIpId, "AncestorIp");

        uint256 deadline = block.timestamp + 1000;

        // set permission for licensing module to attach license terms to ancestor IP
        (bytes memory signatureA, , ) = _getSetPermissionSigForPeriphery({
            ipId: ancestorIpId,
            to: licenseAttachmentWorkflowsAddr,
            module: licensingModuleAddr,
            selector: licensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(payable(ancestorIpId)).state(),
            signerSk: testSenderSk
        });

        // register and attach Terms A and C to ancestor IP
        commRemixTermsIdA = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ancestorIpId,
            terms: PILFlavors.commercialRemix({
                mintingFee: defaultMintingFeeA,
                commercialRevShare: defaultCommRevShareA,
                royaltyPolicy: royaltyPolicyLRPAddr,
                currencyToken: address(StoryUSD)
            }),
            sigAttach: WorkflowStructs.SignatureData({ signer: testSender, deadline: deadline, signature: signatureA })
        });

        // set permission for licensing module to attach license terms to ancestor IP
        (bytes memory signatureC, , ) = _getSetPermissionSigForPeriphery({
            ipId: ancestorIpId,
            to: licenseAttachmentWorkflowsAddr,
            module: licensingModuleAddr,
            selector: licensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(payable(ancestorIpId)).state(),
            signerSk: testSenderSk
        });

        commRemixTermsIdC = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ancestorIpId,
            terms: PILFlavors.commercialRemix({
                mintingFee: defaultMintingFeeC,
                commercialRevShare: defaultCommRevShareC,
                royaltyPolicy: royaltyPolicyLAPAddr,
                currencyToken: address(StoryUSD)
            }),
            sigAttach: WorkflowStructs.SignatureData({ signer: testSender, deadline: deadline, signature: signatureC })
        });

        // register childIpA as derivative of ancestorIp under Terms A
        {
            (bytes memory sigRegister, , ) = _getSetPermissionSigForPeriphery({
                ipId: ipAssetRegistry.ipId(block.chainid, address(spgNftContract), childTokenIdA),
                to: derivativeWorkflowsAddr,
                module: licensingModuleAddr,
                selector: licensingModule.registerDerivative.selector,
                deadline: deadline,
                state: bytes32(0),
                signerSk: testSenderSk
            });

            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdA;

            StoryUSD.mint(testSender, defaultMintingFeeA);
            StoryUSD.approve(derivativeWorkflowsAddr, defaultMintingFeeA);
            childIpIdA = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(spgNftContract),
                tokenId: childTokenIdA,
                derivData: WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: pilTemplateAddr,
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: ""
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadata: emptySigData,
                sigRegister: WorkflowStructs.SignatureData({
                    signer: testSender,
                    deadline: deadline,
                    signature: sigRegister
                })
            });
            vm.label(childIpIdA, "ChildIpA");
        }

        IpRoyaltyVault ancestorIpRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(ancestorIpId));

        // transfer all ancestor royalties tokens to the claimer of the ancestor IP
        {
            bytes memory data = abi.encodeWithSelector(
                ancestorIpRoyaltyVault.transfer.selector,
                testSender,
                ancestorIpRoyaltyVault.totalSupply()
            );

            IIPAccount(payable(ancestorIpId)).execute({ to: address(ancestorIpRoyaltyVault), value: 0, data: data });
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
            (bytes memory sigRegister, , ) = _getSetPermissionSigForPeriphery({
                ipId: ipAssetRegistry.ipId(block.chainid, address(spgNftContract), childTokenIdB),
                to: derivativeWorkflowsAddr,
                module: licensingModuleAddr,
                selector: licensingModule.registerDerivative.selector,
                deadline: deadline,
                state: bytes32(0),
                signerSk: testSenderSk
            });

            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdA;

            StoryUSD.mint(testSender, defaultMintingFeeA);
            StoryUSD.approve(derivativeWorkflowsAddr, defaultMintingFeeA);
            childIpIdB = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(spgNftContract),
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
                    signer: testSender,
                    deadline: deadline,
                    signature: sigRegister
                })
            });
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
            (bytes memory sigRegister, , ) = _getSetPermissionSigForPeriphery({
                ipId: ipAssetRegistry.ipId(block.chainid, address(spgNftContract), childTokenIdC),
                to: derivativeWorkflowsAddr,
                module: licensingModuleAddr,
                selector: licensingModule.registerDerivative.selector,
                deadline: deadline,
                state: bytes32(0),
                signerSk: testSenderSk
            });

            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdC;

            StoryUSD.mint(testSender, defaultMintingFeeC);
            StoryUSD.approve(derivativeWorkflowsAddr, defaultMintingFeeC);
            childIpIdC = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(spgNftContract),
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
                    signer: testSender,
                    deadline: deadline,
                    signature: sigRegister
                })
            });
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
            (bytes memory sigRegister, , ) = _getSetPermissionSigForPeriphery({
                ipId: ipAssetRegistry.ipId(block.chainid, address(spgNftContract), grandChildTokenId),
                to: derivativeWorkflowsAddr,
                module: address(licensingModule),
                selector: licensingModule.registerDerivative.selector,
                deadline: deadline,
                state: bytes32(0),
                signerSk: testSenderSk
            });

            address[] memory parentIpIds = new address[](2);
            uint256[] memory licenseTermsIds = new uint256[](2);
            parentIpIds[0] = childIpIdA;
            parentIpIds[1] = childIpIdB;
            for (uint256 i = 0; i < licenseTermsIds.length; i++) {
                licenseTermsIds[i] = commRemixTermsIdA;
            }

            StoryUSD.mint(testSender, defaultMintingFeeA * parentIpIds.length);
            StoryUSD.approve(derivativeWorkflowsAddr, defaultMintingFeeA * parentIpIds.length);
            grandChildIpId = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(spgNftContract),
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
                    signer: testSender,
                    deadline: deadline,
                    signature: sigRegister
                })
            });
            vm.label(grandChildIpId, "GrandChildIp");
        }

        // mints `amountLicenseTokensToMint` grandChildIp and childIpC license tokens
        {
            StoryUSD.mint(testSender, (defaultMintingFeeA + defaultMintingFeeC) * amountLicenseTokensToMint);
            StoryUSD.approve(royaltyModuleAddr, (defaultMintingFeeA + defaultMintingFeeC) * amountLicenseTokensToMint);

            // mint `amountLicenseTokensToMint` grandChildIp's license tokens
            licensingModule.mintLicenseTokens({
                licensorIpId: grandChildIpId,
                licenseTemplate: pilTemplateAddr,
                licenseTermsId: commRemixTermsIdA,
                amount: amountLicenseTokensToMint,
                receiver: testSender,
                royaltyContext: ""
            });

            // mint `amountLicenseTokensToMint` childIpC's license tokens
            licensingModule.mintLicenseTokens({
                licensorIpId: childIpIdC,
                licenseTemplate: pilTemplateAddr,
                licenseTermsId: commRemixTermsIdC,
                amount: amountLicenseTokensToMint,
                receiver: testSender,
                royaltyContext: ""
            });
        }
    }

    function _setupTest() private {
        spgNftContract = ISPGNFT(
            registrationWorkflows.createCollection(
                ISPGNFT.InitParams({
                    name: testCollectionName,
                    symbol: testCollectionSymbol,
                    baseURI: testBaseURI,
                    contractURI: testContractURI,
                    maxSupply: testMaxSupply,
                    mintFee: 0,
                    mintFeeToken: testMintFeeToken,
                    mintFeeRecipient: testSender,
                    owner: testSender,
                    mintOpen: true,
                    isPublicMinting: true
                })
            )
        );
    }
}
