// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";
import { EvenSplitGroupPool } from "@storyprotocol/core/modules/grouping/EvenSplitGroupPool.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IGroupIPAssetRegistry.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
/* solhint-disable max-line-length */
import { IGraphAwareRoyaltyPolicy } from "@storyprotocol/core/interfaces/modules/royalty/policies/IGraphAwareRoyaltyPolicy.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { LicensingHelper } from "../../../contracts/lib/LicensingHelper.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

contract GroupingIntegration is BaseIntegration {
    using Strings for uint256;

    ISPGNFT private spgNftContract;
    address private groupId;
    address private testLicenseTemplate;
    uint256 private testLicenseTermsId;
    uint32 private revShare;
    uint256 private numIps = 10;
    address[] private ipIds;

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/GroupingIntegration.t.sol:GroupingIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();
        _setUpTest();
        _test_GroupingIntegration_mintAndRegisterIpAndAttachLicenseAndAddToGroup();
        _test_GroupingIntegration_registerIpAndAttachLicenseAndAddToGroup();
        _test_GroupingIntegration_registerGroupAndAttachLicense();
        _test_GroupingIntegration_registerGroupAndAttachLicenseAndAddIps();
        _test_GroupingIntegration_collectRoyaltiesAndClaimReward();
        _test_GroupingIntegration_multicall_mintAndRegisterIpAndAttachLicenseAndAddToGroup();
        _test_GroupingIntegration_multicall_registerIpAndAttachLicenseAndAddToGroup();
        _endBroadcast();
    }

    function _test_GroupingIntegration_mintAndRegisterIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_mintAndRegisterIpAndAttachLicenseAndAddToGroup")
    {
        uint256 deadline = block.timestamp + 1000;

        // Get the signature for executing `addIp` function in `GroupingModule` on behalf of the Group IP owner
        (bytes memory sigAddToGroup, bytes32 expectedState) = _getSigForExecuteWithSig({
            ipId: groupId,
            to: accessControllerAddr,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            data: abi.encodeWithSelector(
                IAccessController.setPermission.selector,
                groupId,
                groupingWorkflowsAddr,
                groupingModuleAddr,
                IGroupingModule.addIp.selector,
                AccessPermission.ALLOW
            ),
            signerSk: testSenderSk
        });

        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);
        (address ipId, uint256 tokenId) = groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup({
            spgNftContract: address(spgNftContract),
            groupId: groupId,
            recipient: testSender,
            ipMetadata: testIpMetadata,
            licenseTemplate: testLicenseTemplate,
            licenseTermsId: testLicenseTermsId,
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigAddToGroup
            }),
            allowDuplicates: true
        });

        assertEq(IIPAccount(payable(groupId)).state(), expectedState);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(groupId, ipId));
        assertEq(spgNftContract.tokenURI(tokenId), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
        assertMetadata(ipId, testIpMetadata);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
        assertEq(licenseTemplate, testLicenseTemplate);
        assertEq(licenseTermsId, testLicenseTermsId);
    }

    function _test_GroupingIntegration_registerIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_registerIpAndAttachLicenseAndAddToGroup")
    {
        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);
        uint256 tokenId = spgNftContract.mint({
            to: testSender,
            nftMetadataURI: testIpMetadata.nftMetadataURI,
            nftMetadataHash: testIpMetadata.nftMetadataHash,
            allowDuplicates: true
        });

        // get the expected IP ID
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId);

        WorkflowStructs.SignatureData memory sigMetadataData;
        WorkflowStructs.SignatureData memory sigAttachData;
        WorkflowStructs.SignatureData memory sigAddToGroupData;

        {
            uint256 deadline = block.timestamp + 1000;
            // Get the signature for executing `setAll` (IP metadata) and `attachLicenseTerms`
            // functions in `coreMetadataModule` and `licensingModule` on behalf of the IP owner
            (bytes memory sigMetadata, bytes32 expectedState) = _getSigForExecuteWithSig({
                ipId: expectedIpId,
                to: coreMetadataModuleAddr,
                deadline: deadline,
                state: bytes32(0),
                data: abi.encodeWithSelector(
                    ICoreMetadataModule.setAll.selector,
                    expectedIpId,
                    testIpMetadata.ipMetadataURI,
                    testIpMetadata.ipMetadataHash,
                    testIpMetadata.nftMetadataHash
                ),
                signerSk: testSenderSk
            });
            (bytes memory sigAttach, ) = _getSigForExecuteWithSig({
                ipId: expectedIpId,
                to: licensingModuleAddr,
                deadline: deadline,
                state: expectedState,
                data: abi.encodeWithSelector(
                    ILicensingModule.attachLicenseTerms.selector,
                    expectedIpId,
                    testLicenseTemplate,
                    testLicenseTermsId
                ),
                signerSk: testSenderSk
            });

            // Get the signature for executing `addIp` function in `GroupingModule` on behalf of the Group IP owner
            (bytes memory sigAddToGroup, ) = _getSigForExecuteWithSig({
                ipId: groupId,
                to: groupingModuleAddr,
                deadline: deadline,
                state: IIPAccount(payable(groupId)).state(),
                data: abi.encodeWithSelector(IGroupingModule.addIp.selector, groupId, expectedIpId),
                signerSk: testSenderSk
            });

            sigMetadataData = WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadata
            });
            sigAttachData = WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigAttach
            });
            sigAddToGroupData = WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigAddToGroup
            });
        }

        address ipId = groupingWorkflows.registerIpAndAttachLicenseAndAddToGroup({
            nftContract: address(spgNftContract),
            tokenId: tokenId,
            groupId: groupId,
            licenseTemplate: testLicenseTemplate,
            licenseTermsId: testLicenseTermsId,
            ipMetadata: testIpMetadata,
            sigMetadata: sigMetadataData,
            sigAttach: sigAttachData,
            sigAddToGroup: sigAddToGroupData
        });

        assertEq(ipId, expectedIpId);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(groupId, ipId));
        assertMetadata(ipId, testIpMetadata);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
        assertEq(licenseTemplate, testLicenseTemplate);
        assertEq(licenseTermsId, testLicenseTermsId);
    }

    function _test_GroupingIntegration_registerGroupAndAttachLicense()
        private
        logTest("test_GroupingIntegration_registerGroupAndAttachLicense")
    {
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicense({
            groupPool: evenSplitGroupPoolAddr,
            licenseTemplate: testLicenseTemplate,
            licenseTermsId: testLicenseTermsId
        });

        // check the group IPA is registered
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).isRegisteredGroup(newGroupId));

        // check the license terms is correctly attached to the group IPA
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(newGroupId, 0);
        assertEq(licenseTemplate, testLicenseTemplate);
        assertEq(licenseTermsId, testLicenseTermsId);
    }

    function _test_GroupingIntegration_registerGroupAndAttachLicenseAndAddIps()
        private
        logTest("test_GroupingIntegration_registerGroupAndAttachLicenseAndAddIps")
    {
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: evenSplitGroupPoolAddr,
            ipIds: ipIds,
            licenseTemplate: testLicenseTemplate,
            licenseTermsId: testLicenseTermsId
        });

        // check the group IPA is registered
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).isRegisteredGroup(newGroupId));

        // check all the individual IPs are added to the new group
        assertEq(IGroupIPAssetRegistry(ipAssetRegistryAddr).totalMembers(newGroupId), ipIds.length);
        for (uint256 i = 0; i < ipIds.length; i++) {
            assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(newGroupId, ipIds[i]));
        }

        // check the license terms is correctly attached to the group IPA
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(newGroupId, 0);
        assertEq(licenseTemplate, testLicenseTemplate);
        assertEq(licenseTermsId, testLicenseTermsId);
    }

    function _test_GroupingIntegration_collectRoyaltiesAndClaimReward()
        private
        logTest("test_GroupingIntegration_collectRoyaltiesAndClaimReward")
    {
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: evenSplitGroupPoolAddr,
            ipIds: ipIds,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: testLicenseTermsId
        });

        assertEq(IGroupIPAssetRegistry(ipAssetRegistryAddr).totalMembers(newGroupId), numIps);
        assertEq(EvenSplitGroupPool(evenSplitGroupPoolAddr).getTotalIps(newGroupId), numIps);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = newGroupId;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = testLicenseTermsId;

        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);
        (address ipId1, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(spgNftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTermsIds: licenseTermsIds,
                licenseTemplate: address(pilTemplate),
                royaltyContext: "",
                maxMintingFee: 0
            }),
            ipMetadata: testIpMetadata,
            recipient: testSender,
            allowDuplicates: true
        });

        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);
        (address ipId2, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(spgNftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTermsIds: licenseTermsIds,
                licenseTemplate: address(pilTemplate),
                royaltyContext: "",
                maxMintingFee: 0
            }),
            ipMetadata: testIpMetadata,
            recipient: testSender,
            allowDuplicates: true
        });

        uint256 amount1 = 1_000 * 10 ** StoryUSD.decimals(); // 1,000 tokens
        StoryUSD.mint(testSender, amount1);
        StoryUSD.approve(address(royaltyModule), amount1);
        royaltyModule.payRoyaltyOnBehalf(ipId1, testSender, address(StoryUSD), amount1);
        IGraphAwareRoyaltyPolicy(royaltyPolicyLAPAddr).transferToVault(
            ipId1,
            newGroupId,
            address(StoryUSD),
            (amount1 * revShare) / royaltyModule.maxPercent()
        );

        uint256 amount2 = 10_000 * 10 ** StoryUSD.decimals(); // 10,000 tokens
        StoryUSD.mint(testSender, amount2);
        StoryUSD.approve(address(royaltyModule), amount2);
        royaltyModule.payRoyaltyOnBehalf(ipId2, testSender, address(StoryUSD), amount2);
        IGraphAwareRoyaltyPolicy(royaltyPolicyLAPAddr).transferToVault(
            ipId2,
            newGroupId,
            address(StoryUSD),
            (amount2 * revShare) / royaltyModule.maxPercent()
        );

        address[] memory royaltyTokens = new address[](1);
        royaltyTokens[0] = address(StoryUSD);

        uint256[] memory collectedRoyalties = groupingWorkflows.collectRoyaltiesAndClaimReward(
            newGroupId,
            royaltyTokens,
            ipIds
        );

        assertEq(collectedRoyalties.length, 1);
        assertEq(
            collectedRoyalties[0],
            (amount1 * revShare) / royaltyModule.maxPercent() + (amount2 * revShare) / royaltyModule.maxPercent()
        );

        // check each member IP received the reward in their IP royalty vault
        for (uint256 i = 0; i < ipIds.length; i++) {
            assertEq(StoryUSD.balanceOf(royaltyModule.ipRoyaltyVaults(ipIds[i])), collectedRoyalties[0] / ipIds.length);
        }
    }

    function _test_GroupingIntegration_multicall_mintAndRegisterIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_multicall_mintAndRegisterIpAndAttachLicenseAndAddToGroup")
    {
        uint256 deadline = block.timestamp + 1000;
        uint256 numCalls = 10;
        // Get the signatures for executing `addIp` function in `GroupingModule` on behalf of the IP owner
        bytes[] memory sigsAddToGroup = new bytes[](numCalls);
        bytes32 expectedStates = IIPAccount(payable(groupId)).state();
        for (uint256 i = 0; i < numCalls; i++) {
            (sigsAddToGroup[i], expectedStates) = _getSigForExecuteWithSig({
                ipId: groupId,
                to: accessControllerAddr,
                deadline: deadline,
                state: expectedStates,
                data: abi.encodeWithSelector(
                    IAccessController.setPermission.selector,
                    groupId,
                    address(groupingWorkflows),
                    groupingModuleAddr,
                    IGroupingModule.addIp.selector,
                    AccessPermission.ALLOW
                ),
                signerSk: testSenderSk
            });
        }

        // setup call data for batch calling `numCalls` `mintAndRegisterIpAndAttachLicenseAndAddToGroup`
        bytes[] memory data = new bytes[](numCalls);
        for (uint256 i = 0; i < numCalls; i++) {
            data[i] = abi.encodeWithSelector(
                groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup.selector,
                address(spgNftContract),
                groupId,
                testSender,
                testLicenseTemplate,
                testLicenseTermsId,
                testIpMetadata,
                WorkflowStructs.SignatureData({ signer: testSender, deadline: deadline, signature: sigsAddToGroup[i] })
            );
        }

        StoryUSD.mint(testSender, testMintFee * numCalls);
        StoryUSD.approve(address(spgNftContract), testMintFee * numCalls);

        // batch call `mintAndRegisterIpAndAttachLicenseAndAddToGroup`
        bytes[] memory results = groupingWorkflows.multicall(data);

        // check each IP is registered, added to the group, and metadata is set, license terms are attached
        address ipId;
        uint256 tokenId;
        for (uint256 i = 0; i < numCalls; i++) {
            (ipId, tokenId) = abi.decode(results[i], (address, uint256));
            assertTrue(ipAssetRegistry.isRegistered(ipId));
            assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(groupId, ipId));
            assertEq(spgNftContract.tokenURI(tokenId), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId, testIpMetadata);
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
            assertEq(licenseTemplate, testLicenseTemplate);
            assertEq(licenseTermsId, testLicenseTermsId);
        }
    }

    function _test_GroupingIntegration_multicall_registerIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_multicall_registerIpAndAttachLicenseAndAddToGroup")
    {
        uint256 numCalls = 10;

        StoryUSD.mint(testSender, testMintFee * numCalls);
        StoryUSD.approve(address(spgNftContract), testMintFee * numCalls);
        // mint a NFT from the spgNftContract
        uint256[] memory tokenIds = new uint256[](numCalls);
        for (uint256 i = 0; i < numCalls; i++) {
            tokenIds[i] = spgNftContract.mint({
                to: testSender,
                nftMetadataURI: testIpMetadata.nftMetadataURI,
                nftMetadataHash: testIpMetadata.nftMetadataHash,
                allowDuplicates: true
            });
        }

        // get the expected IP ID
        address[] memory expectedIpIds = new address[](numCalls);
        for (uint256 i = 0; i < numCalls; i++) {
            expectedIpIds[i] = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenIds[i]);
        }

        uint256 deadline = block.timestamp + 1000;

        WorkflowStructs.SignatureData[] memory sigMetadataData = new WorkflowStructs.SignatureData[](numCalls);
        WorkflowStructs.SignatureData[] memory sigAttachData = new WorkflowStructs.SignatureData[](numCalls);
        WorkflowStructs.SignatureData[] memory sigAddToGroupData = new WorkflowStructs.SignatureData[](numCalls);

        {
            bytes memory sigMetadata;
            bytes memory sigAttach;
            bytes32 expectedState;
            for (uint256 i = 0; i < numCalls; i++) {
                // Get the signature for executing `setAll` function in `CoreMetadataModule` on behalf of the IP owner
                (sigMetadata, expectedState) = _getSigForExecuteWithSig({
                    ipId: expectedIpIds[i],
                    to: coreMetadataModuleAddr,
                    deadline: deadline,
                    state: bytes32(0),
                    data: abi.encodeWithSelector(
                        ICoreMetadataModule.setAll.selector,
                        expectedIpIds[i],
                        testIpMetadata.ipMetadataURI,
                        testIpMetadata.ipMetadataHash,
                        testIpMetadata.nftMetadataHash
                    ),
                    signerSk: testSenderSk
                });

                // Get the signature for executing `attachLicenseTerms` function in `LicensingModule` on behalf of the IP owner
                (sigAttach, ) = _getSigForExecuteWithSig({
                    ipId: expectedIpIds[i],
                    to: licensingModuleAddr,
                    deadline: deadline,
                    state: bytes32(0),
                    data: abi.encodeWithSelector(
                        ILicensingModule.attachLicenseTerms.selector,
                        expectedIpIds[i],
                        testLicenseTemplate,
                        testLicenseTermsId
                    ),
                    signerSk: testSenderSk
                });

                sigMetadataData[i] = WorkflowStructs.SignatureData({
                    signer: testSender,
                    deadline: deadline,
                    signature: sigMetadata
                });

                sigAttachData[i] = WorkflowStructs.SignatureData({
                    signer: testSender,
                    deadline: deadline,
                    signature: sigAttach
                });
            }

            // Get the signatures for executing `addIp` function in `GroupingModule` on behalf of the IP owner
            bytes memory sigsAddToGroup;
            expectedState = IIPAccount(payable(groupId)).state();
            address[] memory ipIdArr = new address[](1);
            for (uint256 i = 0; i < numCalls; i++) {
                ipIdArr[0] = expectedIpIds[i];
                (sigsAddToGroup, expectedState) = _getSigForExecuteWithSig({
                    ipId: groupId,
                    to: groupingModuleAddr,
                    deadline: deadline,
                    state: expectedState,
                    data: abi.encodeWithSelector(IGroupingModule.addIp.selector, groupId, ipIdArr),
                    signerSk: testSenderSk
                });

                sigAddToGroupData[i] = WorkflowStructs.SignatureData({
                    signer: testSender,
                    deadline: deadline,
                    signature: sigsAddToGroup
                });
            }
        }

        // setup call data for batch calling 10 `registerIpAndAttachLicenseAndAddToGroup`
        bytes[] memory data = new bytes[](numCalls);
        for (uint256 i = 0; i < numCalls; i++) {
            data[i] = abi.encodeWithSelector(
                groupingWorkflows.registerIpAndAttachLicenseAndAddToGroup.selector,
                address(spgNftContract),
                tokenIds[i],
                groupId,
                testLicenseTemplate,
                testLicenseTermsId,
                testIpMetadata,
                sigMetadataData[i],
                sigAttachData[i],
                sigAddToGroupData[i]
            );
        }

        // batch call `registerIpAndAttachLicenseAndAddToGroup`
        bytes[] memory results = groupingWorkflows.multicall(data);

        // check each IP is registered, added to the group, and metadata is set, license terms are attached
        address ipId;
        for (uint256 i = 0; i < numCalls; i++) {
            ipId = abi.decode(results[i], (address));
            assertEq(ipId, expectedIpIds[i]);
            assertTrue(ipAssetRegistry.isRegistered(ipId));
            assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(groupId, ipId));
            assertMetadata(ipId, testIpMetadata);
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
            assertEq(licenseTemplate, testLicenseTemplate);
            assertEq(licenseTermsId, testLicenseTermsId);
        }
    }

    function _setUpTest() private {
        revShare = 10 * 10 ** 6; // 10%
        testLicenseTemplate = pilTemplateAddr;
        testLicenseTermsId = pilTemplate.registerLicenseTerms(
            // minting fee is set to 0 beacause currently core protocol requires group IP's minting fee to be 0
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: revShare,
                royaltyPolicy: royaltyPolicyLAPAddr,
                currencyToken: address(StoryUSD)
            })
        );

        // setup a group
        {
            groupId = groupingModule.registerGroup(evenSplitGroupPoolAddr);
            LicensingHelper.attachLicenseTerms(groupId, licensingModuleAddr, testLicenseTemplate, testLicenseTermsId);
        }

        // setup a collection and IPs
        {
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

            bytes[] memory data = new bytes[](numIps);
            for (uint256 i = 0; i < numIps; i++) {
                data[i] = abi.encodeWithSelector(
                    registrationWorkflows.mintAndRegisterIp.selector,
                    address(spgNftContract),
                    testSender,
                    testIpMetadata
                );
            }

            StoryUSD.mint(testSender, testMintFee * numIps);
            StoryUSD.approve(address(spgNftContract), testMintFee * numIps);

            // batch call `mintAndRegisterIp`
            bytes[] memory results = registrationWorkflows.multicall(data);

            // decode the multicall results to get the IP IDs
            ipIds = new address[](numIps);
            for (uint256 i = 0; i < numIps; i++) {
                (ipIds[i], ) = abi.decode(results[i], (address, uint256));
            }

            // attach license terms to the IPs
            for (uint256 i = 0; i < numIps; i++) {
                LicensingHelper.attachLicenseTerms(ipIds[i], licensingModuleAddr, pilTemplateAddr, testLicenseTermsId);
            }
        }
    }
}
