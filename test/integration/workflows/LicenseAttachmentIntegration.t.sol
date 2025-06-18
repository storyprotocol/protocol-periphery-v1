// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";
import { TotalLicenseTokenLimitHook } from "../../../contracts/hooks/TotalLicenseTokenLimitHook.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

contract LicenseAttachmentIntegration is BaseIntegration {
    using Strings for uint256;

    event DebugLog(string label, address addr);
    event DebugLogBytes32(string label, bytes32 value);
    event DebugLogUint(string label, uint256 value);
    error MintingDidNotRevert();
    error RevertReasonMismatch(bytes actual, bytes expected);

    ISPGNFT private spgNftContract;
    WorkflowStructs.LicenseTermsData[] private commTermsData;

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/LicenseAttachmentIntegration.t.sol:LicenseAttachmentIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();

        // Transaction 1: Setup and all successful tests.
        _beginBroadcast();
        _setUpTest();
        _test_LicenseAttachmentIntegration_registerPILTermsAndAttach();
        _test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachPILTerms();
        _test_LicenseAttachmentIntegration_registerIpAndAttachPILTerms();
        _test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachDefaultTerms();
        _test_LicenseAttachmentIntegration_registerIpAndAttachDefaultTerms();
        _endBroadcast();

        // Transaction 2: The isolated revert test.
        _beginBroadcast();
        _setUpTest();
        _test_revert_TotalLicenseTokenLimitHook();
        _endBroadcast();
    }

    function _test_LicenseAttachmentIntegration_registerPILTermsAndAttach()
        private
        logTest("test_LicenseAttachmentIntegration_registerPILTermsAndAttach")
    {
        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);

        (address ipId, ) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftContract),
            recipient: testSender,
            ipMetadata: testIpMetadata,
            allowDuplicates: true
        });

        uint256 deadline = block.timestamp + 1000;
        (bytes memory signature, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getAttachTermsAndConfigPermissionList(ipId, licenseAttachmentWorkflowsAddr),
            deadline: deadline,
            state: IIPAccount(payable(ipId)).state(),
            signerSk: testSenderSk
        });

        uint256[] memory licenseTermsIds = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: signature
            })
        });

        for (uint256 i = 0; i < licenseTermsIds.length; i++) {
            assertEq(licenseTermsIds[i], pilTemplate.getLicenseTermsId(commTermsData[i].terms));
        }
    }

    function _test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachPILTerms()
        private
        logTest("test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachPILTerms")
    {
        // IP 1
        {
            wrappedIP.deposit{ value: testMintFee }();
            wrappedIP.approve(address(spgNftContract), testMintFee);

            (address ipId1, uint256 tokenId1, uint256[] memory licenseTermsIds1) = licenseAttachmentWorkflows
                .mintAndRegisterIpAndAttachPILTerms({
                    spgNftContract: address(spgNftContract),
                    recipient: testSender,
                    ipMetadata: testIpMetadata,
                    licenseTermsData: commTermsData,
                    allowDuplicates: true
                });
            assertTrue(ipAssetRegistry.isRegistered(ipId1));
            assertEq(tokenId1, spgNftContract.totalSupply());
            assertEq(spgNftContract.tokenURI(tokenId1), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId1, testIpMetadata);
            for (uint256 i = 0; i < licenseTermsIds1.length; i++) {
                (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, i);
                assertEq(licenseTemplate, pilTemplateAddr);
                assertEq(licenseTermsId, licenseTermsIds1[i]);
                assertEq(licenseTermsId, pilTemplate.getLicenseTermsId(commTermsData[i].terms));
            }
        }

        // IP 2
        {
            wrappedIP.deposit{ value: testMintFee }();
            wrappedIP.approve(address(spgNftContract), testMintFee);

            (address ipId2, uint256 tokenId2, uint256[] memory licenseTermsIds2) = licenseAttachmentWorkflows
                .mintAndRegisterIpAndAttachPILTerms({
                    spgNftContract: address(spgNftContract),
                    recipient: testSender,
                    ipMetadata: testIpMetadata,
                    licenseTermsData: commTermsData,
                    allowDuplicates: true
                });
            assertTrue(ipAssetRegistry.isRegistered(ipId2));
            assertEq(tokenId2, spgNftContract.totalSupply());
            assertEq(spgNftContract.tokenURI(tokenId2), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId2, testIpMetadata);
            for (uint256 i = 0; i < licenseTermsIds2.length; i++) {
                (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, i);
                assertEq(licenseTemplate, pilTemplateAddr);
                assertEq(licenseTermsIds2[i], licenseTermsId);
                assertEq(licenseTermsId, pilTemplate.getLicenseTermsId(commTermsData[i].terms));
            }
        }
    }

    function _test_LicenseAttachmentIntegration_registerIpAndAttachPILTerms()
        private
        logTest("test_LicenseAttachmentIntegration_registerIpAndAttachPILTerms")
    {
        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);

        uint256 tokenId = spgNftContract.mint({
            to: testSender,
            nftMetadataURI: "",
            nftMetadataHash: bytes32(0),
            allowDuplicates: true
        });
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadataAndAttachAndConfig, bytes32 expectedState, ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndAttachTermsAndConfigPermissionList(
                expectedIpId,
                licenseAttachmentWorkflowsAddr
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: testSenderSk
        });

        (address ipId, uint256[] memory licenseTermsIds) = licenseAttachmentWorkflows.registerIpAndAttachPILTerms({
            nftContract: address(spgNftContract),
            tokenId: tokenId,
            ipMetadata: testIpMetadata,
            licenseTermsData: commTermsData,
            sigMetadataAndAttachAndConfig: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadataAndAttachAndConfig
            })
        });

        assertEq(ipId, expectedIpId);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        bytes[] memory calldataSequence = new bytes[](3);
        calldataSequence[0] = abi.encodeWithSelector(ICoreMetadataModule.setAll.selector, ipId, testIpMetadata);
        calldataSequence[1] = abi.encodeWithSelector(
            ILicensingModule.attachLicenseTerms.selector,
            ipId,
            pilTemplateAddr,
            licenseTermsIds[0]
        );
        calldataSequence[2] = abi.encodeWithSelector(
            ILicensingModule.setLicensingConfig.selector,
            ipId,
            commTermsData[0].licensingConfig
        );
        for (uint256 i = 0; i < licenseTermsIds.length; i++) {
            (address expectedLicenseTemplate, uint256 expectedLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(
                expectedIpId,
                i
            );
            assertEq(expectedLicenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsIds[i], expectedLicenseTermsId);
            assertEq(expectedLicenseTermsId, pilTemplate.getLicenseTermsId(commTermsData[i].terms));
        }
    }

    function _test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachDefaultTerms()
        private
        logTest("test_LicenseAttachmentWorkflows_mintAndRegisterIpAndAttachDefaultTerms")
    {
        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);

        (address ipId1, uint256 tokenId1) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachDefaultTerms({
            spgNftContract: address(spgNftContract),
            recipient: testSender,
            ipMetadata: testIpMetadata,
            allowDuplicates: true
        });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, spgNftContract.totalSupply());
        assertEq(spgNftContract.tokenURI(tokenId1), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
        assertMetadata(ipId1, testIpMetadata);
        (address defaultLicenseTemplate, uint256 defaultLicenseTermsId) = licenseRegistry.getDefaultLicenseTerms();
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(defaultLicenseTemplate, defaultLicenseTemplate);
        assertEq(defaultLicenseTermsId, defaultLicenseTermsId);
        assertEq(licenseTermsId, defaultLicenseTermsId);
    }

    function _test_LicenseAttachmentIntegration_registerIpAndAttachDefaultTerms()
        private
        logTest("test_LicenseAttachmentWorkflows_registerIpAndAttachDefaultTerms")
    {
        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);

        uint256 tokenId = spgNftContract.mint({
            to: testSender,
            nftMetadataURI: "",
            nftMetadataHash: bytes32(0),
            allowDuplicates: true
        });
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadataAndDefaultTerms, bytes32 expectedState, ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndDefaultTermsPermissionList(expectedIpId, licenseAttachmentWorkflowsAddr),
            deadline: deadline,
            state: bytes32(0),
            signerSk: testSenderSk
        });

        address ipId = licenseAttachmentWorkflows.registerIpAndAttachDefaultTerms({
            nftContract: address(spgNftContract),
            tokenId: tokenId,
            ipMetadata: testIpMetadata,
            sigMetadataAndDefaultTerms: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadataAndDefaultTerms
            })
        });

        assertEq(ipId, expectedIpId);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        (address defaultLicenseTemplate, uint256 defaultLicenseTermsId) = licenseRegistry.getDefaultLicenseTerms();
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
        assertEq(defaultLicenseTemplate, defaultLicenseTemplate);
        assertEq(defaultLicenseTermsId, defaultLicenseTermsId);
        assertEq(licenseTermsId, defaultLicenseTermsId);
        bytes[] memory calldataSequence = new bytes[](2);
        calldataSequence[0] = abi.encodeWithSelector(ICoreMetadataModule.setAll.selector, ipId, testIpMetadata);
        calldataSequence[1] = abi.encodeWithSelector(
            ILicensingModule.attachLicenseTerms.selector,
            ipId,
            defaultLicenseTemplate,
            defaultLicenseTermsId
        );
    }

    function _test_revert_TotalLicenseTokenLimitHook() private logTest("_test_revert_TotalLicenseTokenLimitHook") {
        // 1. register IP
        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);
        (address ipId, ) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftContract),
            recipient: testSender,
            ipMetadata: testIpMetadata,
            allowDuplicates: true
        });

        // 2. register terms and attach to IP
        uint256 deadline = block.timestamp + 1000;
        (bytes memory signature, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getAttachTermsAndConfigPermissionList(ipId, licenseAttachmentWorkflowsAddr),
            deadline: deadline,
            state: IIPAccount(payable(ipId)).state(),
            signerSk: testSenderSk
        });

        uint256[] memory licenseTermsIds = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: signature
            })
        });

        // 3. set limit
        address licenseTemplate = pilTemplateAddr;
        uint256 licenseTermsId = licenseTermsIds[0]; // use the ID returned after registration
        totalLicenseTokenLimitHook.setTotalLicenseTokenLimit(ipId, licenseTemplate, licenseTermsId, 2);

        emit DebugLog("Hook address", address(totalLicenseTokenLimitHook));
        emit DebugLog("License Template", licenseTemplate);
        emit DebugLog("IP ID", ipId);
        emit DebugLogUint("License Terms ID", licenseTermsId);

        // 4. record the number of tokens before minting
        uint256 supplyBefore = totalLicenseTokenLimitHook.getTotalLicenseTokenSupply(
            ipId,
            licenseTemplate,
            licenseTermsId
        );
        emit DebugLogUint("Supply Before", supplyBefore);

        // 5. mint tokens
        wrappedIP.deposit{ value: testMintFee * 3 }();
        wrappedIP.approve(royaltyModuleAddr, testMintFee * 3);

        licensingModule.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: licenseTemplate,
            licenseTermsId: licenseTermsId,
            amount: 2,
            receiver: testSender,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        // 6. record the number of tokens after minting
        uint256 supplyAfter = totalLicenseTokenLimitHook.getTotalLicenseTokenSupply(
            ipId,
            licenseTemplate,
            licenseTermsId
        );
        emit DebugLogUint("Supply After", supplyAfter);

        // 7. verify the number of tokens increased
        assertEq(supplyAfter, supplyBefore + 2, "Supply should increase by 2");

        // 8. test exceeding the limit using try/catch for live network testing
        bytes memory expectedError = abi.encodeWithSelector(
            TotalLicenseTokenLimitHook.TotalLicenseTokenLimitHook_TotalLicenseTokenLimitExceeded.selector,
            2, // currentSupply (after minting 2 tokens)
            1, // amount trying to mint
            2 // limit we set
        );

        try
            licensingModule.mintLicenseTokens{ gas: 500000 }({
                licensorIpId: ipId,
                licenseTemplate: licenseTemplate,
                licenseTermsId: licenseTermsId,
                amount: 1,
                receiver: testSender,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRevenueShare: 0
            })
        {
            // If this block is reached, the transaction did not revert, which is an error in our test logic.
            revert MintingDidNotRevert();
        } catch (bytes memory reason) {
            // The call reverted as expected. Now, we check if it's the correct error.
            if (keccak256(reason) != keccak256(expectedError)) {
                revert RevertReasonMismatch(reason, expectedError);
            }
            // If we reach here, it means the revert was correct. Log success.
            emit log_string("SUCCESS: Correctly reverted when exceeding the token limit.");
        }

        // Add a final, successful state change to signal a successful script execution to Forge.
        emit DebugLog("Revert test completed successfully", address(0));
    }

    function _setUpTest() private {
        delete commTermsData;

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

        assertTrue(address(spgNftContract) != address(0), "createCollection returned address(0)");

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialUse({
                    mintingFee: testMintFee,
                    currencyToken: testMintFeeToken,
                    royaltyPolicy: royaltyPolicyLRPAddr
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    // licensingHook: address(0),
                    licensingHook: address(totalLicenseTokenLimitHook),
                    hookData: "",
                    commercialRevShare: 0,
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialUse({
                    mintingFee: testMintFee,
                    currencyToken: testMintFeeToken,
                    royaltyPolicy: royaltyPolicyLAPAddr
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: false,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 0,
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: testMintFee,
                    commercialRevShare: 5_000_000, // 5%
                    royaltyPolicy: royaltyPolicyLRPAddr,
                    currencyToken: testMintFeeToken
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 5_000_000, // 5%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: testMintFee,
                    commercialRevShare: 8_000_000, // 8%
                    royaltyPolicy: royaltyPolicyLAPAddr,
                    currencyToken: testMintFeeToken
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 8_000_000, // 8%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );
    }
}
