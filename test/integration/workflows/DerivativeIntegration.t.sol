// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

contract DerivativeIntegration is BaseIntegration {
    using Strings for uint256;

    ISPGNFT private spgNftContract;
    address[] private parentIpIds;
    uint256[] private parentLicenseTermIds;
    address private parentLicenseTemplate;

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/DerivativeIntegration.t.sol:DerivativeIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();
        _setUpTest();
        _test_mintAndRegisterIpAndMakeDerivative();
        _test_registerIpAndMakeDerivative();
        _test_mintAndRegisterIpAndMakeDerivativeWithLicenseTokens();
        _test_registerIpAndMakeDerivativeWithLicenseTokens();
        _test_multicall_mintAndRegisterIpAndMakeDerivative();
        _endBroadcast();
    }

    function _test_mintAndRegisterIpAndMakeDerivative()
        private
        logTest("test_DerivativeIntegration_mintAndRegisterIpAndMakeDerivative")
    {
        StoryUSD.mint(testSender, testMintFee * 2);
        StoryUSD.approve(address(spgNftContract), testMintFee); // for nft minting fee
        StoryUSD.approve(derivativeWorkflowsAddr, testMintFee); // for derivative minting fee
        (address childIpId, uint256 childTokenId) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(spgNftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: parentLicenseTemplate,
                licenseTermsIds: parentLicenseTermIds,
                royaltyContext: "",
                maxMintingFee: 0
            }),
            ipMetadata: testIpMetadata,
            recipient: testSender
        });

        assertTrue(ipAssetRegistry.isRegistered(childIpId));
        assertEq(childTokenId, spgNftContract.totalSupply());
        assertEq(spgNftContract.tokenURI(childTokenId), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
        assertMetadata(childIpId, testIpMetadata);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            childIpId,
            0
        );
        assertEq(licenseTemplateChild, parentLicenseTemplate);
        assertEq(licenseTermsIdChild, parentLicenseTermIds[0]);
        assertEq(IIPAccount(payable(childIpId)).owner(), testSender);
        assertParentChild({
            ipIdParent: parentIpIds[0],
            ipIdChild: childIpId,
            expectedParentCount: parentIpIds.length,
            expectedParentIndex: 0
        });
    }

    function _test_registerIpAndMakeDerivative()
        private
        logTest("test_DerivativeIntegration_registerIpAndMakeDerivative")
    {
        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee); // for nft minting fee

        uint256 childTokenId = spgNftContract.mint(testSender, testIpMetadata.nftMetadataURI);
        address childIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), childTokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadata, bytes32 sigRegisterState, ) = _getSetPermissionSigForPeriphery({
            ipId: childIpId,
            to: derivativeWorkflowsAddr,
            module: coreMetadataModuleAddr,
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerSk: testSenderSk
        });

        (bytes memory sigRegister, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: childIpId,
            to: derivativeWorkflowsAddr,
            module: licensingModuleAddr,
            selector: ILicensingModule.registerDerivative.selector,
            deadline: deadline,
            state: sigRegisterState,
            signerSk: testSenderSk
        });

        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(derivativeWorkflowsAddr, testMintFee); // for derivative minting fee
        derivativeWorkflows.registerIpAndMakeDerivative({
            nftContract: address(spgNftContract),
            tokenId: childTokenId,
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: parentLicenseTemplate,
                licenseTermsIds: parentLicenseTermIds,
                royaltyContext: "",
                maxMintingFee: 0
            }),
            ipMetadata: testIpMetadata,
            sigMetadata: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadata
            }),
            sigRegister: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigRegister
            })
        });

        assertTrue(ipAssetRegistry.isRegistered(childIpId));
        assertEq(spgNftContract.tokenURI(childTokenId), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
        assertMetadata(childIpId, testIpMetadata);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            childIpId,
            0
        );
        assertEq(licenseTemplateChild, parentLicenseTemplate);
        assertEq(licenseTermsIdChild, parentLicenseTermIds[0]);
        assertEq(IIPAccount(payable(childIpId)).owner(), testSender);
        assertEq(IIPAccount(payable(childIpId)).state(), expectedState);
        assertParentChild({
            ipIdParent: parentIpIds[0],
            ipIdChild: childIpId,
            expectedParentCount: parentIpIds.length,
            expectedParentIndex: 0
        });
    }

    function _test_mintAndRegisterIpAndMakeDerivativeWithLicenseTokens()
        private
        logTest("test_DerivativeIntegration_mintAndRegisterIpAndMakeDerivativeWithLicenseTokens")
    {
        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(royaltyModuleAddr, testMintFee); // for license token minting fee
        uint256 startLicenseTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: parentIpIds[0],
            licenseTemplate: parentLicenseTemplate,
            licenseTermsId: parentLicenseTermIds[0],
            amount: 1,
            receiver: testSender,
            royaltyContext: "",
            maxMintingFee: 0
        });

        // Need so that derivative workflows can transfer the license tokens
        licenseToken.approve(derivativeWorkflowsAddr, startLicenseTokenId);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee); // for nft minting fee
        (address childIpId, uint256 childTokenId) = derivativeWorkflows
            .mintAndRegisterIpAndMakeDerivativeWithLicenseTokens({
                spgNftContract: address(spgNftContract),
                licenseTokenIds: licenseTokenIds,
                royaltyContext: "",
                ipMetadata: testIpMetadata,
                recipient: testSender
            });

        assertTrue(ipAssetRegistry.isRegistered(childIpId));
        assertEq(childTokenId, spgNftContract.totalSupply());
        assertEq(spgNftContract.tokenURI(childTokenId), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
        assertMetadata(childIpId, testIpMetadata);
        (address childLicenseTemplate, uint256 childLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(
            childIpId,
            0
        );
        assertEq(childLicenseTemplate, parentLicenseTemplate);
        assertEq(childLicenseTermsId, parentLicenseTermIds[0]);
        assertEq(IIPAccount(payable(childIpId)).owner(), testSender);

        assertParentChild({
            ipIdParent: parentIpIds[0],
            ipIdChild: childIpId,
            expectedParentCount: parentIpIds.length,
            expectedParentIndex: 0
        });
    }

    function _test_registerIpAndMakeDerivativeWithLicenseTokens()
        private
        logTest("test_DerivativeIntegration_registerIpAndMakeDerivativeWithLicenseTokens")
    {
        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee); // for nft minting fee
        uint256 childTokenId = spgNftContract.mint(testSender, testIpMetadata.nftMetadataURI);
        address childIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), childTokenId);

        uint256 deadline = block.timestamp + 1000;

        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(royaltyModuleAddr, testMintFee); // for license token minting fee
        uint256 startLicenseTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: parentIpIds[0],
            licenseTemplate: parentLicenseTemplate,
            licenseTermsId: parentLicenseTermIds[0],
            amount: 1,
            receiver: testSender,
            royaltyContext: "",
            maxMintingFee: 0
        });

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;
        licenseToken.approve(derivativeWorkflowsAddr, startLicenseTokenId);

        (bytes memory sigMetadata, bytes32 sigRegisterState, ) = _getSetPermissionSigForPeriphery({
            ipId: childIpId,
            to: derivativeWorkflowsAddr,
            module: coreMetadataModuleAddr,
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerSk: testSenderSk
        });
        (bytes memory sigRegister, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: childIpId,
            to: derivativeWorkflowsAddr,
            module: licensingModuleAddr,
            selector: ILicensingModule.registerDerivativeWithLicenseTokens.selector,
            deadline: deadline,
            state: sigRegisterState,
            signerSk: testSenderSk
        });

        derivativeWorkflows.registerIpAndMakeDerivativeWithLicenseTokens({
            nftContract: address(spgNftContract),
            tokenId: childTokenId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            ipMetadata: testIpMetadata,
            sigMetadata: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadata
            }),
            sigRegister: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigRegister
            })
        });

        assertTrue(ipAssetRegistry.isRegistered(childIpId));
        assertEq(IIPAccount(payable(childIpId)).state(), expectedState);
        assertMetadata(childIpId, testIpMetadata);
        {
            (address childLicenseTemplate, uint256 childLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(
                childIpId,
                0
            );
            assertEq(childLicenseTemplate, parentLicenseTemplate);
            assertEq(childLicenseTermsId, parentLicenseTermIds[0]);
        }
        assertParentChild({
            ipIdParent: parentIpIds[0],
            ipIdChild: childIpId,
            expectedParentCount: parentIpIds.length,
            expectedParentIndex: 0
        });
    }

    function _test_multicall_mintAndRegisterIpAndMakeDerivative()
        private
        logTest("test_DerivativeIntegration_multicall_mintAndRegisterIpAndMakeDerivative")
    {
        uint256 numCalls = 10;
        bytes[] memory data = new bytes[](numCalls);
        for (uint256 i = 0; i < numCalls; i++) {
            data[i] = abi.encodeWithSelector(
                derivativeWorkflows.mintAndRegisterIpAndMakeDerivative.selector,
                address(spgNftContract),
                WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: parentLicenseTemplate,
                    licenseTermsIds: parentLicenseTermIds,
                    royaltyContext: "",
                    maxMintingFee: 0
                }),
                testIpMetadata,
                testSender
            );
        }

        StoryUSD.mint(testSender, testMintFee * numCalls * 2);
        StoryUSD.approve(address(spgNftContract), testMintFee * numCalls);
        StoryUSD.approve(derivativeWorkflowsAddr, testMintFee * numCalls);

        bytes[] memory results = derivativeWorkflows.multicall(data);

        for (uint256 i = 0; i < numCalls; i++) {
            (address childIpId, uint256 childTokenId) = abi.decode(results[i], (address, uint256));
            assertTrue(ipAssetRegistry.isRegistered(childIpId));
            assertEq(childTokenId, spgNftContract.totalSupply() - numCalls + i + 1);
            assertEq(spgNftContract.tokenURI(childTokenId), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(childIpId, testIpMetadata);
            (address childLicenseTemplate, uint256 childLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(
                childIpId,
                0
            );
            assertEq(childLicenseTemplate, parentLicenseTemplate);
            assertEq(childLicenseTermsId, parentLicenseTermIds[0]);
            assertEq(IIPAccount(payable(childIpId)).owner(), testSender);
            assertParentChild({
                ipIdParent: parentIpIds[0],
                ipIdChild: childIpId,
                expectedParentCount: parentIpIds.length,
                expectedParentIndex: 0
            });
        }
    }

    function _setUpTest() private {
        spgNftContract = ISPGNFT(
            registrationWorkflows.createCollection(
                ISPGNFT.InitParams({
                    name: testCollectionName,
                    symbol: testCollectionSymbol,
                    baseURI: testBaseURI,
                    contractURI: testContractURI,
                    maxSupply: testMaxSupply,
                    mintFee: testMintFee,
                    mintFeeToken: testMintFeeToken,
                    mintFeeRecipient: testSender,
                    owner: testSender,
                    mintOpen: true,
                    isPublicMinting: true
                })
            )
        );

        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);
        (address parentIpId, , uint256 licenseTermsIdParent) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(spgNftContract),
                recipient: testSender,
                ipMetadata: testIpMetadata,
                terms: PILFlavors.commercialUse({
                    mintingFee: testMintFee,
                    currencyToken: testMintFeeToken,
                    royaltyPolicy: royaltyPolicyLRPAddr
                })
            });

        parentIpIds = new address[](1);
        parentIpIds[0] = parentIpId;

        parentLicenseTermIds = new uint256[](1);
        parentLicenseTermIds[0] = licenseTermsIdParent;
        parentLicenseTemplate = pilTemplateAddr;
    }

    /// @dev Assert parent and derivative relationship.
    function assertParentChild(
        address ipIdParent,
        address ipIdChild,
        uint256 expectedParentCount,
        uint256 expectedParentIndex
    ) internal view {
        assertTrue(licenseRegistry.hasDerivativeIps(ipIdParent));
        assertTrue(licenseRegistry.isDerivativeIp(ipIdChild));
        assertTrue(licenseRegistry.isParentIp({ parentIpId: ipIdParent, childIpId: ipIdChild }));
        assertEq(licenseRegistry.getParentIpCount(ipIdChild), expectedParentCount);
        assertEq(licenseRegistry.getParentIp(ipIdChild, expectedParentIndex), ipIdParent);
    }
}
