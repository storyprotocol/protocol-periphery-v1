// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";

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
    WorkflowStructs.LicenseTermsData[] internal licenseTermsData;
    uint32 private revShare;

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
        wrappedIP.deposit{ value: testMintFee * 2 }(); // wrapping native IP
        wrappedIP.approve(address(spgNftContract), testMintFee); // for nft minting fee
        wrappedIP.approve(derivativeWorkflowsAddr, testMintFee); // for derivative minting fee
        (address childIpId, uint256 childTokenId) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(spgNftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: parentLicenseTemplate,
                licenseTermsIds: parentLicenseTermIds,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: testIpMetadata,
            recipient: testSender,
            allowDuplicates: true
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
            parentIpId: parentIpIds[0],
            childIpId: childIpId,
            expectedParentCount: parentIpIds.length,
            expectedParentIndex: 0
        });
    }

    function _test_registerIpAndMakeDerivative()
        private
        logTest("test_DerivativeIntegration_registerIpAndMakeDerivative")
    {
        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee); // for nft minting fee

        uint256 childTokenId = spgNftContract.mint({
            to: testSender,
            nftMetadataURI: testIpMetadata.nftMetadataURI,
            nftMetadataHash: testIpMetadata.nftMetadataHash,
            allowDuplicates: true
        });
        address childIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), childTokenId);

        uint256 deadline = block.timestamp + 1000;

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

        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(derivativeWorkflowsAddr, testMintFee); // for derivative minting fee
        derivativeWorkflows.registerIpAndMakeDerivative({
            nftContract: address(spgNftContract),
            tokenId: childTokenId,
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: parentLicenseTemplate,
                licenseTermsIds: parentLicenseTermIds,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: testIpMetadata,
            sigMetadataAndRegister: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: signatureMetadataAndRegister
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
        bytes[] memory calldataSequence = new bytes[](2);
        calldataSequence[0] = abi.encodeWithSelector(ICoreMetadataModule.setAll.selector, childIpId, testIpMetadata);
        calldataSequence[1] = abi.encodeWithSelector(
            ILicensingModule.attachLicenseTerms.selector,
            childIpId,
            parentLicenseTemplate,
            parentLicenseTermIds[0]
        );

        assertParentChild({
            parentIpId: parentIpIds[0],
            childIpId: childIpId,
            expectedParentCount: parentIpIds.length,
            expectedParentIndex: 0
        });
    }

    function _test_mintAndRegisterIpAndMakeDerivativeWithLicenseTokens()
        private
        logTest("test_DerivativeIntegration_mintAndRegisterIpAndMakeDerivativeWithLicenseTokens")
    {
        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(royaltyModuleAddr, testMintFee); // for license token minting fee
        uint256 startLicenseTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: parentIpIds[0],
            licenseTemplate: parentLicenseTemplate,
            licenseTermsId: parentLicenseTermIds[0],
            amount: 1,
            receiver: testSender,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        // Need so that derivative workflows can transfer the license tokens
        licenseToken.approve(derivativeWorkflowsAddr, startLicenseTokenId);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee); // for nft minting fee
        (address childIpId, uint256 childTokenId) = derivativeWorkflows
            .mintAndRegisterIpAndMakeDerivativeWithLicenseTokens({
                spgNftContract: address(spgNftContract),
                licenseTokenIds: licenseTokenIds,
                royaltyContext: "",
                maxRts: revShare,
                ipMetadata: testIpMetadata,
                recipient: testSender,
                allowDuplicates: true
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
            parentIpId: parentIpIds[0],
            childIpId: childIpId,
            expectedParentCount: parentIpIds.length,
            expectedParentIndex: 0
        });
    }

    function _test_registerIpAndMakeDerivativeWithLicenseTokens()
        private
        logTest("test_DerivativeIntegration_registerIpAndMakeDerivativeWithLicenseTokens")
    {
        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee); // for nft minting fee
        uint256 childTokenId = spgNftContract.mint({
            to: testSender,
            nftMetadataURI: testIpMetadata.nftMetadataURI,
            nftMetadataHash: testIpMetadata.nftMetadataHash,
            allowDuplicates: true
        });
        address childIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), childTokenId);

        uint256 deadline = block.timestamp + 1000;

        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(royaltyModuleAddr, testMintFee); // for license token minting fee
        uint256 startLicenseTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: parentIpIds[0],
            licenseTemplate: parentLicenseTemplate,
            licenseTermsId: parentLicenseTermIds[0],
            amount: 1,
            receiver: testSender,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;
        licenseToken.approve(derivativeWorkflowsAddr, startLicenseTokenId);

        (bytes memory signatureMetadataAndRegister, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: childIpId,
            permissionList: _getMetadataAndDerivativeRegistrationPermissionList(
                childIpId,
                address(derivativeWorkflows),
                true
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: testSenderSk
        });

        derivativeWorkflows.registerIpAndMakeDerivativeWithLicenseTokens({
            nftContract: address(spgNftContract),
            tokenId: childTokenId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            maxRts: revShare,
            ipMetadata: testIpMetadata,
            sigMetadataAndRegister: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: signatureMetadataAndRegister
            })
        });

        assertTrue(ipAssetRegistry.isRegistered(childIpId));
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
            parentIpId: parentIpIds[0],
            childIpId: childIpId,
            expectedParentCount: parentIpIds.length,
            expectedParentIndex: 0
        });
    }

    function _test_multicall_mintAndRegisterIpAndMakeDerivative()
        private
        logTest("test_DerivativeIntegration_multicall_mintAndRegisterIpAndMakeDerivative")
    {
        uint256 numCalls = 2;
        bytes[] memory data = new bytes[](numCalls);
        for (uint256 i = 0; i < numCalls; i++) {
            data[i] = abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "mintAndRegisterIpAndMakeDerivative(address,(address[],address,uint256[],bytes,uint256,uint32,uint32),(string,bytes32,string,bytes32),address,bool)"
                    )
                ),
                address(spgNftContract),
                WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: parentLicenseTemplate,
                    licenseTermsIds: parentLicenseTermIds,
                    royaltyContext: "",
                    maxMintingFee: 0,
                    maxRts: revShare,
                    maxRevenueShare: 0
                }),
                testIpMetadata,
                testSender,
                true
            );
        }

        wrappedIP.deposit{ value: testMintFee * numCalls * 2 }();
        wrappedIP.approve(address(spgNftContract), testMintFee * numCalls);
        wrappedIP.approve(derivativeWorkflowsAddr, testMintFee * numCalls);

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
                parentIpId: parentIpIds[0],
                childIpId: childIpId,
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

        revShare = 10 * 10 ** 6; // 10%

        licenseTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: testMintFee,
                    commercialRevShare: revShare,
                    royaltyPolicy: royaltyPolicyLRPAddr,
                    currencyToken: testMintFeeToken
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: revShare,
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );

        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);
        address parentIpId;
        (parentIpId, , parentLicenseTermIds) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(spgNftContract),
            recipient: testSender,
            ipMetadata: testIpMetadata,
            licenseTermsData: licenseTermsData,
            allowDuplicates: true
        });

        parentIpIds = new address[](1);
        parentIpIds[0] = parentIpId;

        parentLicenseTemplate = pilTemplateAddr;
    }
}
