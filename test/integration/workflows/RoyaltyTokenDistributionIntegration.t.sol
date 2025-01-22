// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { MetaTx } from "@storyprotocol/core/lib/MetaTx.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

contract RoyaltyTokenDistributionIntegration is BaseIntegration {
    using Strings for uint256;
    using MessageHashUtils for bytes32;

    ISPGNFT private spgNftContract;

    uint256 private licenseMintingFee;

    WorkflowStructs.IPMetadata private ipMetadata;
    WorkflowStructs.MakeDerivative private derivativeData;
    WorkflowStructs.LicenseTermsData[] private commRemixTermsData;
    WorkflowStructs.RoyaltyShare[] private royaltyShares;

    // random addresses
    address private shareRecipientA=0xfD6BC5A922Df6Fa2034d97958C5401023B21641B;
    address private shareRecipientB=0x3D1f17203f8B6918D1B96CE195920e768AB7a9aB;
    address private shareRecipientC=0x021CBD607beeCA2ACecBD8533D822f5Ca70169f3;
    address private shareRecipientD=0x5Bf05b423a1D090522700a3D5609D1FBbD690e76;

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/RoyaltyTokenDistributionIntegration.t.sol:RoyaltyTokenDistributionIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();
        _setupTest();
        _test_RoyaltyTokenDistributionIntegration_mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens();
        _test_RoyaltyTokenDistributionIntegration_mintAndRegisterIpAndMakeDerivativeAndDistributeRoyaltyTokens();
        _test_RoyaltyTokenDistributionIntegration_registerIpAndAttachPILTermsAndDistributeRoyaltyTokens();
        _test_RoyaltyTokenDistributionIntegration_registerIpAndMakeDerivativeAndDistributeRoyaltyTokens();
        _endBroadcast();
    }

    function _test_RoyaltyTokenDistributionIntegration_mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens()
        private
        logTest("test_RoyaltyTokenDistributionIntegration_mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens")
    {
        (address ipId, uint256 tokenId, uint256[] memory licenseTermsIds) = royaltyTokenDistributionWorkflows
            .mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens({
                spgNftContract: address(spgNftContract),
                recipient: testSender,
                ipMetadata: ipMetadata,
                licenseTermsData: commRemixTermsData,
                royaltyShares: royaltyShares,
                allowDuplicates: true
            });

        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(spgNftContract.tokenURI(tokenId), string.concat(testBaseURI, ipMetadata.nftMetadataURI));
        assertMetadata(ipId, ipMetadata);
        _assertAttachedLicenseTerms(ipId, licenseTermsIds);
        _assertRoyaltyTokenDistribution(ipId);
    }

    function _test_RoyaltyTokenDistributionIntegration_mintAndRegisterIpAndMakeDerivativeAndDistributeRoyaltyTokens()
        private
        logTest("test_RoyaltyTokenDistributionIntegration_mintAndRegisterIpAndMakeDerivativeAndDistributeRoyaltyTokens")
    {
        StoryUSD.mint(testSender, licenseMintingFee);
        StoryUSD.approve(royaltyTokenDistributionWorkflowsAddr, licenseMintingFee);

        (address ipId, uint256 tokenId) = royaltyTokenDistributionWorkflows
            .mintAndRegisterIpAndMakeDerivativeAndDistributeRoyaltyTokens({
                spgNftContract: address(spgNftContract),
                recipient: testSender,
                ipMetadata: ipMetadata,
                derivData: derivativeData,
                royaltyShares: royaltyShares,
                allowDuplicates: true
            });

        assertEq(spgNftContract.tokenURI(tokenId), string.concat(testBaseURI, ipMetadata.nftMetadataURI));
        assertEq(ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId), ipId);
        assertMetadata(ipId, ipMetadata);
        assertParentChild({
            ipIdParent: derivativeData.parentIpIds[0],
            ipIdChild: ipId,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
        (address licenseTemplateAttached, uint256 licenseTermsIdAttached) = licenseRegistry.getAttachedLicenseTerms(
            ipId,
            0
        );
        assertEq(licenseTemplateAttached, address(pilTemplate));
        assertEq(licenseTermsIdAttached, derivativeData.licenseTermsIds[0]);
        _assertRoyaltyTokenDistribution(ipId);
    }

    function _test_RoyaltyTokenDistributionIntegration_registerIpAndAttachPILTermsAndDistributeRoyaltyTokens()
        private
        logTest("test_registerIpAndAttachPILTermsAndDistributeRoyaltyTokens")
    {
        uint256 tokenId = spgNftContract.mint(testSender, "", bytes32(0), true);
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory signatureMetadataAndAttachAndConfig, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndAttachTermsAndConfigPermissionList(
                expectedIpId,
                address(royaltyTokenDistributionWorkflows)
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: testSenderSk
        });

        // register IP, attach PIL terms, and deploy royalty vault
        (address ipId, uint256[] memory licenseTermsIds, address ipRoyaltyVault) = royaltyTokenDistributionWorkflows
            .registerIpAndAttachPILTermsAndDeployRoyaltyVault({
                nftContract: address(spgNftContract),
                tokenId: tokenId,
                ipMetadata: ipMetadata,
                licenseTermsData: commRemixTermsData,
                sigMetadataAndAttachAndConfig: WorkflowStructs.SignatureData({
                    signer: testSender,
                    deadline: deadline,
                    signature: signatureMetadataAndAttachAndConfig
                })
            });

        (bytes memory signatureApproveRoyaltyTokens, ) = _getSigForExecuteWithSig({
            ipId: ipId,
            to: ipRoyaltyVault,
            deadline: deadline,
            state: IIPAccount(payable(ipId)).state(),
            data: abi.encodeWithSelector(
                IERC20.approve.selector,
                address(royaltyTokenDistributionWorkflows),
                95_000_000 // 95%
            ),
            signerSk: testSenderSk
        });

        // distribute royalty tokens
        royaltyTokenDistributionWorkflows.distributeRoyaltyTokens({
            ipId: ipId,
            royaltyShares: royaltyShares,
            sigApproveRoyaltyTokens: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: signatureApproveRoyaltyTokens
            })
        });

        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertMetadata(ipId, ipMetadata);
        _assertAttachedLicenseTerms(ipId, licenseTermsIds);
        _assertRoyaltyTokenDistribution(ipId);
    }

    function _test_RoyaltyTokenDistributionIntegration_registerIpAndMakeDerivativeAndDistributeRoyaltyTokens()
        private
        logTest("test_registerIpAndMakeDerivativeAndDistributeRoyaltyTokens")
    {
        uint256 tokenId = spgNftContract.mint(testSender, "", bytes32(0), true);
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                expectedIpId,
                address(royaltyTokenDistributionWorkflows),
                false
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: testSenderSk
        });

        // register IP, make derivative, and deploy royalty vault
        StoryUSD.mint(testSender, licenseMintingFee);
        StoryUSD.approve(address(royaltyTokenDistributionWorkflows), licenseMintingFee);
        (address ipId, address ipRoyaltyVault) = royaltyTokenDistributionWorkflows
            .registerIpAndMakeDerivativeAndDeployRoyaltyVault({
                nftContract: address(spgNftContract),
                tokenId: tokenId,
                ipMetadata: ipMetadata,
                derivData: derivativeData,
                sigMetadataAndRegister: WorkflowStructs.SignatureData({
                    signer: testSender,
                    deadline: deadline,
                    signature: signatureMetadataAndRegister
                })
            });

        // get signature for approving royalty tokens
        (bytes memory signatureApproveRoyaltyTokens, ) = _getSigForExecuteWithSig({
            ipId: ipId,
            to: ipRoyaltyVault,
            deadline: deadline,
            state: IIPAccount(payable(ipId)).state(),
            data: abi.encodeWithSelector(
                IERC20.approve.selector,
                address(royaltyTokenDistributionWorkflows),
                95_000_000 // 95%
            ),
            signerSk: testSenderSk
        });

        // distribute royalty tokens
        royaltyTokenDistributionWorkflows.distributeRoyaltyTokens({
            ipId: ipId,
            royaltyShares: royaltyShares,
            sigApproveRoyaltyTokens: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: signatureApproveRoyaltyTokens
            })
        });

        assertEq(ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId), ipId);
        assertMetadata(ipId, ipMetadata);
        assertParentChild({
            ipIdParent: derivativeData.parentIpIds[0],
            ipIdChild: ipId,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
        (address licenseTemplateAttached, uint256 licenseTermsIdAttached) = licenseRegistry.getAttachedLicenseTerms(
            ipId,
            0
        );
        assertEq(licenseTemplateAttached, address(pilTemplate));
        assertEq(licenseTermsIdAttached, derivativeData.licenseTermsIds[0]);
        _assertRoyaltyTokenDistribution(ipId);
    }

    function _setupTest() private {
        ipMetadata = WorkflowStructs.IPMetadata({
            ipMetadataURI: "test-ip-uri",
            ipMetadataHash: "test-ip-hash",
            nftMetadataURI: "test-nft-uri",
            nftMetadataHash: "test-nft-hash"
        });

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

        licenseMintingFee = 10 * 10 ** StoryUSD.decimals(); // 10 SUSD

        uint32 testCommRevShare = 5 * 10 ** 6; // 5%

        commRemixTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: licenseMintingFee,
                    commercialRevShare: testCommRevShare,
                    royaltyPolicy: royaltyPolicyLRPAddr,
                    currencyToken: address(StoryUSD)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: licenseMintingFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: testCommRevShare, // 5%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );

        commRemixTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: licenseMintingFee,
                    commercialRevShare: 5_000_000, // 5%
                    royaltyPolicy: royaltyPolicyLRPAddr,
                    currencyToken: address(StoryUSD)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: licenseMintingFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 5_000_000, // 5%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );

        commRemixTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: licenseMintingFee,
                    commercialRevShare: 8_000_000, // 8%
                    royaltyPolicy: royaltyPolicyLAPAddr,
                    currencyToken: address(StoryUSD)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: licenseMintingFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 8_000_000, // 8%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );

        address[] memory ipIdParent = new address[](1);
        uint256[] memory licenseTermsIds;
        StoryUSD.mint(testSender, licenseMintingFee);
        StoryUSD.approve(address(spgNftContract), licenseMintingFee);
        (ipIdParent[0], , licenseTermsIds) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(spgNftContract),
            recipient: testSender,
            ipMetadata: ipMetadata,
            licenseTermsData: commRemixTermsData,
            allowDuplicates: true
        });

        uint256[] memory licenseTermsIdsParent = new uint256[](1);
        licenseTermsIdsParent[0] = licenseTermsIds[0];

        derivativeData = WorkflowStructs.MakeDerivative({
            parentIpIds: ipIdParent,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIdsParent,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRts: testCommRevShare,
            maxRevenueShare: 0
        });

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                recipient: shareRecipientA,
                percentage: 50_000_000 // 50%
            })
        );

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                recipient: shareRecipientB,
                percentage: 20_000_000 // 20%
            })
        );

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                recipient: shareRecipientC,
                percentage: 20_000_000 // 20%
            })
        );

        royaltyShares.push(
            WorkflowStructs.RoyaltyShare({
                recipient: shareRecipientD,
                percentage: 5_000_000 // 5%
            })
        );
    }

    function _assertAttachedLicenseTerms(address ipId, uint256[] memory licenseTermsIds) private {
        for (uint256 i = 0; i < commRemixTermsData.length; i++) {
            assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId, address(pilTemplate), licenseTermsIds[i]));
        }
    }

    /// @dev Assert that the royalty tokens have been distributed correctly.
    /// @param ipId The ID of the IP whose royalty tokens to check.
    function _assertRoyaltyTokenDistribution(address ipId) private {
        address royaltyVault = royaltyModule.ipRoyaltyVaults(ipId);
        IERC20 royaltyToken = IERC20(royaltyVault);

        for (uint256 i; i < royaltyShares.length; i++) {
            assertEq(royaltyToken.balanceOf(royaltyShares[i].recipient), royaltyShares[i].percentage);
        }
    }

    /// @dev Get the signature for executing a function on behalf of the IP via {IIPAccount.executeWithSig}.
    /// @param ipId The ID of the IP whose account will execute the function.
    /// @param to The address of the contract to execute the function on.
    /// @param deadline The deadline for the signature.
    /// @param state IPAccount's internal nonce
    /// @param data the call data for the function.
    /// @param signerSk The secret key of the signer.
    /// @return signature The signature for executing the function.
    /// @return expectedState The expected IPAccount's state after executing the function.
    function _getSigForExecuteWithSig(
        address ipId,
        address to,
        uint256 deadline,
        bytes32 state,
        bytes memory data,
        uint256 signerSk
    ) internal view returns (bytes memory signature, bytes32 expectedState) {
        expectedState = keccak256(
            abi.encode(
                state, // ipAccount.state()
                abi.encodeWithSelector(
                    IIPAccount.execute.selector,
                    to, // to
                    0, // value
                    data
                )
            )
        );

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(ipId),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({ to: to, value: 0, data: data, nonce: expectedState, deadline: deadline })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
