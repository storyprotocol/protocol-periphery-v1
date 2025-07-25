// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { EvenSplitGroupPool } from "@storyprotocol/core/modules/grouping/EvenSplitGroupPool.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IGroupIPAssetRegistry.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
/* solhint-disable max-line-length */
import { IGraphAwareRoyaltyPolicy } from "@storyprotocol/core/interfaces/modules/royalty/policies/IGraphAwareRoyaltyPolicy.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { LicensingHelper } from "../../../contracts/lib/LicensingHelper.sol";
import { IGroupingWorkflows } from "../../../contracts/interfaces/workflows/IGroupingWorkflows.sol";
import { IRegistrationWorkflows } from "../../../contracts/interfaces/workflows/IRegistrationWorkflows.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

contract GroupingIntegration is BaseIntegration {
    using Strings for uint256;

    ISPGNFT private spgNftContract;
    address private groupId;
    WorkflowStructs.LicenseData[] private testLicensesData;
    WorkflowStructs.LicenseData[] internal testGroupLicenseData;
    uint32 private revShare;
    uint256 private numIps = 2;
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

        // Get the signature for setting the permission for calling `addIp` function in `GroupingModule`
        // from the Group IP owner
        (bytes memory sigAddToGroup, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: groupId,
            to: groupingWorkflowsAddr,
            module: groupingModuleAddr,
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerSk: testSenderSk
        });

        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);
        (address ipId, uint256 tokenId) = groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup({
            spgNftContract: address(spgNftContract),
            groupId: groupId,
            recipient: testSender,
            maxAllowedRewardShare: 100e6, // 100%
            ipMetadata: testIpMetadata,
            licensesData: testLicensesData,
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigAddToGroup
            }),
            allowDuplicates: true
        });

        address[] memory ipIdsForGroup = new address[](1);
        ipIdsForGroup[0] = ipId;
        assertEq(
            IIPAccount(payable(groupId)).state(),
            _predictNextState(
                address(groupingWorkflows),
                address(groupingModule),
                expectedState,
                abi.encodeWithSelector(IGroupingModule.addIp.selector, groupId, ipIdsForGroup, 100e6)
            )
        );
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(groupId, ipId));
        assertEq(spgNftContract.tokenURI(tokenId), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
        assertMetadata(ipId, testIpMetadata);
        for (uint256 j = 0; j < testLicensesData.length; j++) {
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, j);
            assertEq(licenseTemplate, testLicensesData[j].licenseTemplate);
            assertEq(licenseTermsId, testLicensesData[j].licenseTermsId);
        }
    }

    function _test_GroupingIntegration_registerIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_registerIpAndAttachLicenseAndAddToGroup")
    {
        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);
        uint256 tokenId = spgNftContract.mint({
            to: testSender,
            nftMetadataURI: testIpMetadata.nftMetadataURI,
            nftMetadataHash: testIpMetadata.nftMetadataHash,
            allowDuplicates: true
        });

        // get the expected IP ID
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        // Get the signature for setting the permission for calling `setAll` (IP metadata) and `attachLicenseTerms`
        // functions in `coreMetadataModule` and `licensingModule` from the IP owner
        (bytes memory sigMetadataAndAttachAndConfig, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndAttachTermsAndConfigPermissionList(expectedIpId, groupingWorkflowsAddr),
            deadline: deadline,
            state: bytes32(0),
            signerSk: testSenderSk
        });

        // Get the signature for setting the permission for calling `addIp` function in `GroupingModule`
        // from the Group IP owner
        (bytes memory sigAddToGroup, , ) = _getSetPermissionSigForPeriphery({
            ipId: groupId,
            to: groupingWorkflowsAddr,
            module: groupingModuleAddr,
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerSk: testSenderSk
        });

        address ipId = groupingWorkflows.registerIpAndAttachLicenseAndAddToGroup({
            nftContract: address(spgNftContract),
            tokenId: tokenId,
            groupId: groupId,
            maxAllowedRewardShare: 100e6, // 100%
            licensesData: testLicensesData,
            ipMetadata: testIpMetadata,
            sigMetadataAndAttachAndConfig: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadataAndAttachAndConfig
            }),
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigAddToGroup
            })
        });

        assertEq(ipId, expectedIpId);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(groupId, ipId));
        assertMetadata(ipId, testIpMetadata);
        for (uint256 j = 0; j < testLicensesData.length; j++) {
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, j);
            assertEq(licenseTemplate, testLicensesData[j].licenseTemplate);
            assertEq(licenseTermsId, testLicensesData[j].licenseTermsId);
        }
    }

    function _test_GroupingIntegration_registerGroupAndAttachLicense()
        private
        logTest("test_GroupingIntegration_registerGroupAndAttachLicense")
    {
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicense({
            groupPool: evenSplitGroupPoolAddr,
            licenseData: testGroupLicenseData[0]
        });

        // check the group IPA is registered
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).isRegisteredGroup(newGroupId));

        // check the license terms is correctly attached to the group IPA
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(newGroupId, 0);
        assertEq(licenseTemplate, testGroupLicenseData[0].licenseTemplate);
        assertEq(licenseTermsId, testGroupLicenseData[0].licenseTermsId);
    }

    function _test_GroupingIntegration_registerGroupAndAttachLicenseAndAddIps()
        private
        logTest("test_GroupingIntegration_registerGroupAndAttachLicenseAndAddIps")
    {
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: evenSplitGroupPoolAddr,
            ipIds: ipIds,
            maxAllowedRewardShare: 100e6, // 100%
            licenseData: testGroupLicenseData[0]
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
        assertEq(licenseTemplate, testGroupLicenseData[0].licenseTemplate);
        assertEq(licenseTermsId, testGroupLicenseData[0].licenseTermsId);
    }

    function _test_GroupingIntegration_collectRoyaltiesAndClaimReward()
        private
        logTest("test_GroupingIntegration_collectRoyaltiesAndClaimReward")
    {
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: evenSplitGroupPoolAddr,
            ipIds: ipIds,
            maxAllowedRewardShare: 100e6, // 100%
            licenseData: testGroupLicenseData[0]
        });

        assertEq(IGroupIPAssetRegistry(ipAssetRegistryAddr).totalMembers(newGroupId), numIps);
        assertEq(EvenSplitGroupPool(evenSplitGroupPoolAddr).getTotalIps(newGroupId), numIps);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = newGroupId;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = testLicensesData[0].licenseTermsId;

        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);
        (address ipId1, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(spgNftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTermsIds: licenseTermsIds,
                licenseTemplate: testLicensesData[0].licenseTemplate,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: testIpMetadata,
            recipient: testSender,
            allowDuplicates: true
        });

        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);
        (address ipId2, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(spgNftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTermsIds: licenseTermsIds,
                licenseTemplate: testLicensesData[0].licenseTemplate,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: testIpMetadata,
            recipient: testSender,
            allowDuplicates: true
        });

        uint256 amount1 = 1 * 10 ** wrappedIP.decimals(); // 1 token
        wrappedIP.deposit{ value: amount1 }();
        wrappedIP.approve(address(royaltyModule), amount1);
        royaltyModule.payRoyaltyOnBehalf(ipId1, testSender, address(wrappedIP), amount1);
        IGraphAwareRoyaltyPolicy(royaltyPolicyLRPAddr).transferToVault(ipId1, newGroupId, address(wrappedIP));

        uint256 amount2 = 2 * 10 ** wrappedIP.decimals(); // 2 tokens
        wrappedIP.deposit{ value: amount2 }();
        wrappedIP.approve(address(royaltyModule), amount2);
        royaltyModule.payRoyaltyOnBehalf(ipId2, testSender, address(wrappedIP), amount2);
        IGraphAwareRoyaltyPolicy(royaltyPolicyLRPAddr).transferToVault(ipId2, newGroupId, address(wrappedIP));

        address[] memory royaltyTokens = new address[](1);
        royaltyTokens[0] = address(wrappedIP);

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
            assertEq(
                wrappedIP.balanceOf(royaltyModule.ipRoyaltyVaults(ipIds[i])),
                collectedRoyalties[0] / ipIds.length
            );
        }
    }

    function _test_GroupingIntegration_multicall_mintAndRegisterIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_multicall_mintAndRegisterIpAndAttachLicenseAndAddToGroup")
    {
        uint256 deadline = block.timestamp + 1000;
        uint256 numCalls = 2;
        // Get the signatures for setting the permission for calling `addIp` function in `GroupingModule`
        // from the Group IP owner
        bytes[] memory sigsAddToGroup = new bytes[](numCalls);
        bytes32 expectedStates = IIPAccount(payable(groupId)).state();
        for (uint256 i = 0; i < numCalls; i++) {
            (sigsAddToGroup[i], expectedStates, ) = _getSetPermissionSigForPeriphery({
                ipId: groupId,
                to: groupingWorkflowsAddr,
                module: groupingModuleAddr,
                selector: IGroupingModule.addIp.selector,
                deadline: deadline,
                state: expectedStates,
                signerSk: testSenderSk
            });
            address[] memory predictedIpIdsForGroup = new address[](1);
            predictedIpIdsForGroup[0] = ipAssetRegistry.ipId(
                block.chainid,
                address(spgNftContract),
                spgNftContract.totalSupply() + i + 1
            );
            expectedStates = _predictNextState(
                address(groupingWorkflows),
                address(groupingModule),
                expectedStates,
                abi.encodeWithSelector(IGroupingModule.addIp.selector, groupId, predictedIpIdsForGroup, 100e6)
            );
        }

        // setup call data for batch calling `numCalls` `mintAndRegisterIpAndAttachLicenseAndAddToGroup`
        bytes[] memory data = new bytes[](numCalls);
        for (uint256 i = 0; i < numCalls; i++) {
            data[i] = abi.encodeWithSelector(
                IGroupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup.selector,
                address(spgNftContract),
                groupId,
                testSender,
                100e6, // 100%
                testLicensesData,
                testIpMetadata,
                WorkflowStructs.SignatureData({ signer: testSender, deadline: deadline, signature: sigsAddToGroup[i] })
            );
        }

        wrappedIP.deposit{ value: testMintFee * numCalls }();
        wrappedIP.approve(address(spgNftContract), testMintFee * numCalls);

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
            for (uint256 j = 0; j < testLicensesData.length; j++) {
                (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, j);
                assertEq(licenseTemplate, testLicensesData[j].licenseTemplate);
                assertEq(licenseTermsId, testLicensesData[j].licenseTermsId);
            }
        }
    }

    function _test_GroupingIntegration_multicall_registerIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_multicall_registerIpAndAttachLicenseAndAddToGroup")
    {
        uint256 numCalls = 2;

        wrappedIP.deposit{ value: testMintFee * numCalls }();
        wrappedIP.approve(address(spgNftContract), testMintFee * numCalls);
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

        // Get the signatures for setting the permission for calling `setAll` (IP metadata) and `attachLicenseTerms`
        // functions in `coreMetadataModule` and `licensingModule` from the IP owner
        bytes[] memory sigsMetadataAndAttach = new bytes[](numCalls);
        for (uint256 i = 0; i < numCalls; i++) {
            (sigsMetadataAndAttach[i], , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: expectedIpIds[i],
                permissionList: _getMetadataAndAttachTermsAndConfigPermissionList(
                    expectedIpIds[i],
                    address(groupingWorkflows)
                ),
                deadline: deadline,
                state: bytes32(0),
                signerSk: testSenderSk
            });
        }

        // Get the signatures for setting the permission for calling `addIp` function in `GroupingModule`
        // from the Group IP owner
        bytes[] memory sigsAddToGroup = new bytes[](numCalls);
        bytes32 expectedStates = IIPAccount(payable(groupId)).state();
        for (uint256 i = 0; i < numCalls; i++) {
            (sigsAddToGroup[i], expectedStates, ) = _getSetPermissionSigForPeriphery({
                ipId: groupId,
                to: groupingWorkflowsAddr,
                module: groupingModuleAddr,
                selector: IGroupingModule.addIp.selector,
                deadline: deadline,
                state: expectedStates,
                signerSk: testSenderSk
            });
            address[] memory predictedIpIdsForGroup = new address[](1);
            predictedIpIdsForGroup[0] = expectedIpIds[i];
            expectedStates = _predictNextState(
                address(groupingWorkflows),
                address(groupingModule),
                expectedStates,
                abi.encodeWithSelector(IGroupingModule.addIp.selector, groupId, predictedIpIdsForGroup, 100e6)
            );
        }

        // setup call data for batch calling 10 `registerIpAndAttachLicenseAndAddToGroup`
        bytes[] memory data = new bytes[](numCalls);
        for (uint256 i = 0; i < numCalls; i++) {
            data[i] = abi.encodeWithSelector(
                IGroupingWorkflows.registerIpAndAttachLicenseAndAddToGroup.selector,
                address(spgNftContract),
                tokenIds[i],
                groupId,
                100e6, // 100%
                testLicensesData,
                testIpMetadata,
                WorkflowStructs.SignatureData({
                    signer: testSender,
                    deadline: deadline,
                    signature: sigsMetadataAndAttach[i]
                }),
                WorkflowStructs.SignatureData({ signer: testSender, deadline: deadline, signature: sigsAddToGroup[i] })
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
            for (uint256 j = 0; j < testLicensesData.length; j++) {
                (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, j);
                assertEq(licenseTemplate, testLicensesData[j].licenseTemplate);
                assertEq(licenseTermsId, testLicensesData[j].licenseTermsId);
            }
        }
    }

    function _setUpTest() private {
        revShare = 10 * 10 ** 6; // 10%
        testLicensesData.push(
            WorkflowStructs.LicenseData({
                licenseTemplate: pilTemplateAddr,
                licenseTermsId: pilTemplate.registerLicenseTerms(
                    // minting fee is set to 0 because currently core protocol requires group IP's minting fee to be 0
                    PILFlavors.commercialRemix({
                        mintingFee: 0,
                        commercialRevShare: revShare,
                        royaltyPolicy: royaltyPolicyLRPAddr,
                        currencyToken: address(wrappedIP)
                    })
                ),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: 0,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: revShare,
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: evenSplitGroupPoolAddr
                })
            })
        );
        testGroupLicenseData.push(
            WorkflowStructs.LicenseData({
                licenseTemplate: testLicensesData[0].licenseTemplate,
                licenseTermsId: testLicensesData[0].licenseTermsId,
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: 0,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: revShare,
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(0)
                })
            })
        );

        // setup a group
        {
            groupId = groupingModule.registerGroup(evenSplitGroupPoolAddr);
            LicensingHelper.attachLicenseTermsAndSetConfigs({
                ipId: groupId,
                licensingModule: licensingModuleAddr,
                licenseTemplate: testGroupLicenseData[0].licenseTemplate,
                licenseTermsId: testGroupLicenseData[0].licenseTermsId,
                licensingConfig: testGroupLicenseData[0].licensingConfig
            });
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
                    bytes4(keccak256("mintAndRegisterIp(address,address,(string,bytes32,string,bytes32),bool)")),
                    address(spgNftContract),
                    testSender,
                    testIpMetadata,
                    true
                );
            }

            wrappedIP.deposit{ value: testMintFee * numIps }();
            wrappedIP.approve(address(spgNftContract), testMintFee * numIps);

            // batch call `mintAndRegisterIp`
            bytes[] memory results = registrationWorkflows.multicall(data);

            // decode the multicall results to get the IP IDs
            ipIds = new address[](numIps);
            for (uint256 i = 0; i < numIps; i++) {
                (ipIds[i], ) = abi.decode(results[i], (address, uint256));
            }

            // attach license terms to the IPs
            for (uint256 i = 0; i < numIps; i++) {
                LicensingHelper.attachLicenseTermsAndSetConfigs({
                    ipId: ipIds[i],
                    licensingModule: licensingModuleAddr,
                    licenseTemplate: testLicensesData[0].licenseTemplate,
                    licenseTermsId: testLicensesData[0].licenseTermsId,
                    licensingConfig: testLicensesData[0].licensingConfig
                });
            }
        }
    }
}
