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

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/RoyaltyIntegration.t.sol:RoyaltyIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();
        _setupTest();
        _test_RoyaltyIntegration_transferToVaultAndClaimByTokenBatch();
        _test_RoyaltyIntegration_claimAllRevenue();
        _endBroadcast();
    }

    function _test_RoyaltyIntegration_transferToVaultAndClaimByTokenBatch()
        private
        logTest("test_RoyaltyIntegration_transferToVaultAndClaimByTokenBatch")
    {
        // setup IP graph
        _setupIpGraph();

        address[] memory childIpIds = new address[](3);
        address[] memory royaltyPolicies = new address[](3);
        address[] memory currencyTokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        childIpIds[0] = childIpIdA;
        royaltyPolicies[0] = royaltyPolicyLRPAddr;
        currencyTokens[0] = address(StoryUSD);
        amounts[0] = 10 ether;

        childIpIds[1] = childIpIdB;
        royaltyPolicies[1] = royaltyPolicyLRPAddr;
        currencyTokens[1] = address(StoryUSD);
        amounts[1] = 10 ether;

        childIpIds[2] = grandChildIpId;
        royaltyPolicies[2] = royaltyPolicyLRPAddr;
        currencyTokens[2] = address(StoryUSD);
        amounts[2] = 2 ether;

        childIpIds[3] = childIpIdC;
        royaltyPolicies[3] = royaltyPolicyLAPAddr;
        currencyTokens[3] = address(StoryUSD);
        amounts[3] = 10 ether;

        uint256 claimerBalanceBefore = StoryUSD.balanceOf(ancestorIpId);

        uint256[] memory amountsClaimed = royaltyWorkflows.transferToVaultAndClaimByTokenBatch({
            ancestorIpId: ancestorIpId,
            claimer: ancestorIpId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens,
            amounts: amounts
        });

        uint256 claimerBalanceAfter = StoryUSD.balanceOf(ancestorIpId);

        assertEq(amountsClaimed.length, 1); // there is 1 currency token
        assertEq(claimerBalanceAfter - claimerBalanceBefore, amountsClaimed[0]);
        assertEq(
            claimerBalanceAfter - claimerBalanceBefore,
            defaultMintingFeeA +
                defaultMintingFeeA + // 1000 + 1000 from minting fee of childIpA and childIpB
                10 ether + // 10 currency tokens from childIpA transferred to vault
                10 ether + // 10 currency tokens from childIpB transferred to vault
                2 ether + // 2 currency tokens from grandChildIp transferred to vault
                10 ether // 10 currency tokens from childIpC transferred to vault
        );
    }

    function _test_RoyaltyIntegration_claimAllRevenue() private logTest("test_RoyaltyIntegration_claimAllRevenue") {
        // setup IP graph
        _setupIpGraph();

        address[] memory childIpIds = new address[](3);
        address[] memory royaltyPolicies = new address[](3);
        address[] memory currencyTokens = new address[](3);

        childIpIds[0] = childIpIdA;
        royaltyPolicies[0] = royaltyPolicyLRPAddr;
        currencyTokens[0] = address(StoryUSD);

        childIpIds[1] = childIpIdB;
        royaltyPolicies[1] = royaltyPolicyLRPAddr;
        currencyTokens[1] = address(StoryUSD);

        childIpIds[2] = grandChildIpId;
        royaltyPolicies[2] = royaltyPolicyLRPAddr;
        currencyTokens[2] = address(StoryUSD);

        childIpIds[3] = childIpIdC;
        royaltyPolicies[3] = royaltyPolicyLAPAddr;
        currencyTokens[3] = address(StoryUSD);

        uint256 claimerBalanceBefore = StoryUSD.balanceOf(ancestorIpId);

        uint256[] memory amountsClaimed = royaltyWorkflows.claimAllRevenue({
            ancestorIpId: ancestorIpId,
            claimer: ancestorIpId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });

        uint256 claimerBalanceAfter = StoryUSD.balanceOf(ancestorIpId);

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
    function _setupIpGraph() private {
        uint256 ancestorTokenId = spgNftContract.mint(testSender, "", bytes32(0), true);
        uint256 childTokenIdA = spgNftContract.mint(testSender, "", bytes32(0), true);
        uint256 childTokenIdB = spgNftContract.mint(testSender, "", bytes32(0), true);
        uint256 childTokenIdC = spgNftContract.mint(testSender, "", bytes32(0), true);
        uint256 grandChildTokenId = spgNftContract.mint(testSender, "", bytes32(0), true);

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
                    royaltyContext: "",
                    maxMintingFee: 0
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
                    royaltyContext: "",
                    maxMintingFee: 0
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
                    royaltyContext: "",
                    maxMintingFee: 0
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
                    royaltyContext: "",
                    maxMintingFee: 0
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
                royaltyContext: "",
                maxMintingFee: 0
            });

            // mint `amountLicenseTokensToMint` childIpC's license tokens
            licensingModule.mintLicenseTokens({
                licensorIpId: childIpIdC,
                licenseTemplate: pilTemplateAddr,
                licenseTermsId: commRemixTermsIdC,
                amount: amountLicenseTokensToMint,
                receiver: testSender,
                royaltyContext: "",
                maxMintingFee: 0
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
