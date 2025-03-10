// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
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
    uint256 internal defaultMintingFeeA = 1 * 10 ** wrappedIP.decimals(); // 1 WIP
    uint32 internal defaultCommRevShareA = 10 * 10 ** 6; // 10%

    uint256 internal commRemixTermsIdC;
    uint256 internal defaultMintingFeeC = 2 * 10 ** wrappedIP.decimals(); // 2 WIP
    uint32 internal defaultCommRevShareC = 20 * 10 ** 6; // 20%

    WorkflowStructs.LicenseTermsData[] internal commTermsData;

    uint256 internal amountLicenseTokensToMint = 1;

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/RoyaltyIntegration.t.sol:RoyaltyIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();
        _setupTest();
        _test_RoyaltyIntegration_claimAllRevenue();
        _endBroadcast();
    }

    function _test_RoyaltyIntegration_claimAllRevenue() private logTest("test_RoyaltyIntegration_claimAllRevenue") {
        // setup IP graph
        _setupIpGraph();

        address[] memory childIpIds = new address[](4);
        address[] memory royaltyPolicies = new address[](4);
        address[] memory currencyTokens = new address[](4);

        childIpIds[0] = childIpIdA;
        royaltyPolicies[0] = royaltyPolicyLRPAddr;
        currencyTokens[0] = address(wrappedIP);

        childIpIds[1] = childIpIdB;
        royaltyPolicies[1] = royaltyPolicyLRPAddr;
        currencyTokens[1] = address(wrappedIP);

        childIpIds[2] = grandChildIpId;
        royaltyPolicies[2] = royaltyPolicyLRPAddr;
        currencyTokens[2] = address(wrappedIP);

        childIpIds[3] = childIpIdC;
        royaltyPolicies[3] = royaltyPolicyLAPAddr;
        currencyTokens[3] = address(wrappedIP);

        uint256 claimerBalanceBefore = wrappedIP.balanceOf(ancestorIpId);

        uint256[] memory amountsClaimed = royaltyWorkflows.claimAllRevenue({
            ancestorIpId: ancestorIpId,
            claimer: ancestorIpId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });

        uint256 claimerBalanceAfter = wrappedIP.balanceOf(ancestorIpId);

        assertEq(amountsClaimed.length, 1); // there is 1 currency token
        assertEq(claimerBalanceAfter - claimerBalanceBefore, amountsClaimed[0]);
        assertEq(
            claimerBalanceAfter - claimerBalanceBefore,
            defaultMintingFeeA +
                defaultMintingFeeA + // 1 + 1 from minting fee of childIpA and childIpB
                (defaultMintingFeeA * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1 * 10% = 0.1 royalty from childIpA
                (defaultMintingFeeA * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1 * 10% = 0.1 royalty from childIpB
                (((defaultMintingFeeA * defaultCommRevShareA) / royaltyModule.maxPercent()) * defaultCommRevShareA) /
                royaltyModule.maxPercent() + // 1 * 10% * 10% * 2 = 0.02 royalty from grandChildIp
                defaultMintingFeeC +
                (defaultMintingFeeC * defaultCommRevShareC) /
                royaltyModule.maxPercent() // 2 from from minting fee of childIpC,2 * 20% = 0.4 royalty from childIpC
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

        {
            commTermsData.push(
                WorkflowStructs.LicenseTermsData({
                    terms: PILFlavors.commercialRemix({
                        mintingFee: defaultMintingFeeA,
                        commercialRevShare: defaultCommRevShareA,
                        royaltyPolicy: royaltyPolicyLRPAddr,
                        currencyToken: address(wrappedIP)
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
                        royaltyPolicy: royaltyPolicyLAPAddr,
                        currencyToken: address(wrappedIP)
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

            // set permission for licensing module to attach license terms to ancestor IP
            (bytes memory signature, , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: ancestorIpId,
                permissionList: _getAttachTermsAndConfigPermissionList(ancestorIpId, licenseAttachmentWorkflowsAddr),
                deadline: deadline,
                state: bytes32(0),
                signerSk: testSenderSk
            });

            uint256[] memory licenseTermsIds = licenseAttachmentWorkflows.registerPILTermsAndAttach({
                ipId: ancestorIpId,
                licenseTermsData: commTermsData,
                sigAttachAndConfig: WorkflowStructs.SignatureData({
                    signer: testSender,
                    deadline: deadline,
                    signature: signature
                })
            });

            commRemixTermsIdA = licenseTermsIds[0];
            commRemixTermsIdC = licenseTermsIds[1];
        }

        // register childIpA as derivative of ancestorIp under Terms A
        {
            address childIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), childTokenIdA);
            (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: childIpId,
                permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                    childIpId,
                    address(derivativeWorkflows),
                    false
                ),
                deadline: deadline,
                state: bytes32(0),
                signerSk: testSenderSk
            });

            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdA;

            wrappedIP.deposit{ value: defaultMintingFeeA }();
            wrappedIP.approve(derivativeWorkflowsAddr, defaultMintingFeeA);
            childIpIdA = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(spgNftContract),
                tokenId: childTokenIdA,
                derivData: WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: pilTemplateAddr,
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0,
                    maxRts: defaultCommRevShareA,
                    maxRevenueShare: 0
                }),
                ipMetadata: emptyIpMetadata,
                sigMetadataAndRegister: WorkflowStructs.SignatureData({
                    signer: testSender,
                    deadline: deadline,
                    signature: signatureMetadataAndRegister
                })
            });
            vm.label(childIpIdA, "ChildIpA");
        }

        // register childIpB as derivative of ancestorIp under Terms A
        {
            address childIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), childTokenIdB);
            (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: childIpId,
                permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                    childIpId,
                    address(derivativeWorkflows),
                    false
                ),
                deadline: deadline,
                state: bytes32(0),
                signerSk: testSenderSk
            });

            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdA;

            wrappedIP.deposit{ value: defaultMintingFeeA }();
            wrappedIP.approve(derivativeWorkflowsAddr, defaultMintingFeeA);
            childIpIdB = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(spgNftContract),
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
                    signer: testSender,
                    deadline: deadline,
                    signature: signatureMetadataAndRegister
                })
            });
            vm.label(childIpIdB, "ChildIpB");
        }

        /// register childIpC as derivative of ancestorIp under Terms C
        {
            address childIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), childTokenIdC);
            (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: childIpId,
                permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                    childIpId,
                    address(derivativeWorkflows),
                    false
                ),
                deadline: deadline,
                state: bytes32(0),
                signerSk: testSenderSk
            });

            address[] memory parentIpIds = new address[](1);
            uint256[] memory licenseTermsIds = new uint256[](1);
            parentIpIds[0] = ancestorIpId;
            licenseTermsIds[0] = commRemixTermsIdC;

            wrappedIP.deposit{ value: defaultMintingFeeC }();
            wrappedIP.approve(derivativeWorkflowsAddr, defaultMintingFeeC);
            childIpIdC = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(spgNftContract),
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
                    signer: testSender,
                    deadline: deadline,
                    signature: signatureMetadataAndRegister
                })
            });
            vm.label(childIpIdC, "ChildIpC");
        }

        // register grandChildIp as derivative for childIp A and B under Terms A
        {
            address childIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), grandChildTokenId);
            (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: childIpId,
                permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                    childIpId,
                    address(derivativeWorkflows),
                    false
                ),
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

            wrappedIP.deposit{ value: defaultMintingFeeA * parentIpIds.length }();
            wrappedIP.approve(derivativeWorkflowsAddr, defaultMintingFeeA * parentIpIds.length);
            grandChildIpId = derivativeWorkflows.registerIpAndMakeDerivative({
                nftContract: address(spgNftContract),
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
                    signer: testSender,
                    deadline: deadline,
                    signature: signatureMetadataAndRegister
                })
            });
            vm.label(grandChildIpId, "GrandChildIp");
        }

        // mints `amountLicenseTokensToMint` grandChildIp and childIpC license tokens
        {
            wrappedIP.deposit{ value: (defaultMintingFeeA + defaultMintingFeeC) * amountLicenseTokensToMint }();
            wrappedIP.approve(royaltyModuleAddr, (defaultMintingFeeA + defaultMintingFeeC) * amountLicenseTokensToMint);

            // mint `amountLicenseTokensToMint` grandChildIp's license tokens
            licensingModule.mintLicenseTokens({
                licensorIpId: grandChildIpId,
                licenseTemplate: pilTemplateAddr,
                licenseTermsId: commRemixTermsIdA,
                amount: amountLicenseTokensToMint,
                receiver: testSender,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRevenueShare: 0
            });

            // mint `amountLicenseTokensToMint` childIpC's license tokens
            licensingModule.mintLicenseTokens({
                licensorIpId: childIpIdC,
                licenseTemplate: pilTemplateAddr,
                licenseTermsId: commRemixTermsIdC,
                amount: amountLicenseTokensToMint,
                receiver: testSender,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRevenueShare: 0
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
