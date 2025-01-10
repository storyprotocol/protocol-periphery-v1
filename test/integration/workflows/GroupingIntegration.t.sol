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
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

/// @title GroupingIntegration
/// @notice Integration tests for Story Protocol's grouping functionality
/// @dev Tests various workflows related to IP grouping, licensing, and royalty distribution
contract GroupingIntegration is BaseIntegration {
    using Strings for uint256;

    ISPGNFT private spgNftContract;
    address private groupId;
    WorkflowStructs.LicenseData[] private testLicensesData;
    WorkflowStructs.LicenseData[] internal testGroupLicenseData;
    uint32 private revShare;
    uint256 private constant NUM_IPS = 10;
    address[] private ipIds;

    /// @notice Main entry point for running integration tests
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

    /// @notice Tests minting, registering IP, attaching license, and adding to group in a single transaction
    /// @dev Verifies the complete workflow of creating and grouping an IP asset
    function _test_GroupingIntegration_mintAndRegisterIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_mintAndRegisterIpAndAttachLicenseAndAddToGroup")
    {
        require(address(spgNftContract) != address(0), "SPG NFT contract not initialized");
        require(groupId != address(0), "Group ID not initialized");
        
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

        require(sigAddToGroup.length > 0, "Invalid signature generated");

        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);
        (address ipId, uint256 tokenId) = groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup({
            spgNftContract: address(spgNftContract),
            groupId: groupId,
            recipient: testSender,
            ipMetadata: testIpMetadata,
            licensesData: testLicensesData,
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
        for (uint256 j = 0; j < testLicensesData.length; j++) {
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, j);
            assertEq(licenseTemplate, testLicensesData[j].licenseTemplate);
            assertEq(licenseTermsId, testLicensesData[j].licenseTermsId);
        }
    }

    /// @notice Tests registering IP, attaching license, and adding to group for an existing NFT
    /// @dev Verifies the workflow of grouping an existing NFT
    function _test_GroupingIntegration_registerIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_registerIpAndAttachLicenseAndAddToGroup")
    {
        require(address(spgNftContract) != address(0), "SPG NFT contract not initialized");
        require(testLicensesData.length > 0, "License data not initialized");

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

    /// @notice Tests registering a new group and attaching a license
    /// @dev Verifies basic group creation and licensing
    function _test_GroupingIntegration_registerGroupAndAttachLicense()
        private
        logTest("test_GroupingIntegration_registerGroupAndAttachLicense")
    {
        require(evenSplitGroupPoolAddr != address(0), "Group pool not initialized");
        require(testLicensesData.length > 0, "License data not initialized");

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

    /// @notice Tests registering a group, attaching license, and adding multiple IPs
    /// @dev Verifies batch IP addition to a group
    function _test_GroupingIntegration_registerGroupAndAttachLicenseAndAddIps()
        private
        logTest("test_GroupingIntegration_registerGroupAndAttachLicenseAndAddIps")
    {
        require(ipIds.length > 0, "No IPs initialized for grouping");
        require(evenSplitGroupPoolAddr != address(0), "Group pool not initialized");

        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: evenSplitGroupPoolAddr,
            ipIds: ipIds,
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

    /// @notice Tests the complete workflow of collecting royalties and claiming rewards
    /// @dev Verifies royalty distribution mechanism
    function _test_GroupingIntegration_collectRoyaltiesAndClaimReward()
        private
        logTest("test_GroupingIntegration_collectRoyaltiesAndClaimReward")
    {
        require(revShare > 0, "Revenue share not initialized");
        require(ipIds.length > 0, "No IPs initialized for royalty collection");

        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: evenSplitGroupPoolAddr,
            ipIds: ipIds,
            licenseData: testGroupLicenseData[0]
        });

        assertEq(IGroupIPAssetRegistry(ipAssetRegistryAddr).totalMembers(newGroupId), NUM_IPS);
        assertEq(EvenSplitGroupPool(evenSplitGroupPoolAddr).getTotalIps(newGroupId), NUM_IPS);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = newGroupId;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = testLicensesData[0].licenseTermsId;

        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);
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

        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);
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

        uint256 amount1 = 1_000 * 10 ** StoryUSD.decimals(); // 1,000 tokens
        StoryUSD.mint(testSender, amount1);
        StoryUSD.approve(address(royaltyModule), amount1);
        royaltyModule.payRoyaltyOnBehalf(ipId1, testSender, address(StoryUSD), amount1);
        IGraphAwareRoyaltyPolicy(royaltyPolicyLAPAddr).transferToVault(ipId1, newGroupId, address(StoryUSD));

        uint256 amount2 = 10_000 * 10 ** StoryUSD.decimals(); // 10,000 tokens
        StoryUSD.mint(testSender, amount2);
        StoryUSD.approve(address(royaltyModule), amount2);
        royaltyModule.payRoyaltyOnBehalf(ipId2, testSender, address(StoryUSD), amount2);
        IGraphAwareRoyaltyPolicy(royaltyPolicyLAPAddr).transferToVault(ipId2, newGroupId, address(StoryUSD));

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

    /// @notice Tests batch minting and grouping of multiple IPs using multicall
    /// @dev Verifies the multicall functionality for minting and grouping workflow
    function _test_GroupingIntegration_multicall_mintAndRegisterIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_multicall_mintAndRegisterIpAndAttachLicenseAndAddToGroup")
    {
        require(address(spgNftContract) != address(0), "SPG NFT contract not initialized");
        require(groupId != address(0), "Group ID not initialized");

        uint256 deadline = block.timestamp + 1000;
        
        // Get the signatures for setting the permission for calling `addIp` function in `GroupingModule`
        bytes[] memory sigsAddToGroup = new bytes[](NUM_IPS);
        bytes32 expectedStates = IIPAccount(payable(groupId)).state();
        
        for (uint256 i = 0; i < NUM_IPS; i++) {
            (sigsAddToGroup[i], expectedStates, ) = _getSetPermissionSigForPeriphery({
                ipId: groupId,
                to: groupingWorkflowsAddr,
                module: groupingModuleAddr,
                selector: IGroupingModule.addIp.selector,
                deadline: deadline,
                state: expectedStates,
                signerSk: testSenderSk
            });
            require(sigsAddToGroup[i].length > 0, string.concat("Invalid signature generated for index ", i.toString()));
        }

        // setup call data for batch calling `numCalls` `mintAndRegisterIpAndAttachLicenseAndAddToGroup`
        bytes[] memory data = new bytes[](NUM_IPS);
        for (uint256 i = 0; i < NUM_IPS; i++) {
            data[i] = abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "mintAndRegisterIpAndAttachLicenseAndAddToGroup(address,address,address,(address,uint256,(bool,uint256,address,bytes,uint32,bool,uint32,address))[],(string,bytes32,string,bytes32),(address,uint256,bytes),bool)"
                    )
                ),
                address(spgNftContract),
                groupId,
                testSender,
                testLicensesData,
                testIpMetadata,
                WorkflowStructs.SignatureData({ signer: testSender, deadline: deadline, signature: sigsAddToGroup[i] })
            );
        }

        StoryUSD.mint(testSender, testMintFee * NUM_IPS);
        StoryUSD.approve(address(spgNftContract), testMintFee * NUM_IPS);

        // batch call `mintAndRegisterIpAndAttachLicenseAndAddToGroup`
        bytes[] memory results = groupingWorkflows.multicall(data);

        // check each IP is registered, added to the group, and metadata is set, license terms are attached
        address ipId;
        uint256 tokenId;
        for (uint256 i = 0; i < NUM_IPS; i++) {
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

    /// @notice Tests batch registration and grouping of existing NFTs using multicall
    /// @dev Verifies the multicall functionality for registration and grouping workflow
    function _test_GroupingIntegration_multicall_registerIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_multicall_registerIpAndAttachLicenseAndAddToGroup")
    {
        require(address(spgNftContract) != address(0), "SPG NFT contract not initialized");
        require(testLicensesData.length > 0, "License data not initialized");

        uint256 totalMintFee = testMintFee * NUM_IPS;
        require(totalMintFee / NUM_IPS == testMintFee, "Mint fee multiplication overflow");

        StoryUSD.mint(testSender, totalMintFee);
        StoryUSD.approve(address(spgNftContract), totalMintFee);

        uint256 deadline = block.timestamp + 1000;

        // mint NFTs from the spgNftContract
        uint256[] memory tokenIds = new uint256[](NUM_IPS);
        for (uint256 i = 0; i < NUM_IPS; i++) {
            tokenIds[i] = spgNftContract.mint({
                to: testSender,
                nftMetadataURI: testIpMetadata.nftMetadataURI,
                nftMetadataHash: testIpMetadata.nftMetadataHash,
                allowDuplicates: true
            });
        }

        // get the expected IP ID
        address[] memory expectedIpIds = new address[](NUM_IPS);
        for (uint256 i = 0; i < NUM_IPS; i++) {
            expectedIpIds[i] = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenIds[i]);
        }

        // Get the signatures for setting the permission for calling `setAll` (IP metadata) and `attachLicenseTerms`
        // functions in `coreMetadataModule` and `licensingModule` from the IP owner
        bytes[] memory sigsMetadataAndAttach = new bytes[](NUM_IPS);
        for (uint256 i = 0; i < NUM_IPS; i++) {
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
        bytes[] memory sigsAddToGroup = new bytes[](NUM_IPS);
        bytes32 expectedStates = IIPAccount(payable(groupId)).state();
        for (uint256 i = 0; i < NUM_IPS; i++) {
            (sigsAddToGroup[i], expectedStates, ) = _getSetPermissionSigForPeriphery({
                ipId: groupId,
                to: groupingWorkflowsAddr,
                module: groupingModuleAddr,
                selector: IGroupingModule.addIp.selector,
                deadline: deadline,
                state: expectedStates,
                signerSk: testSenderSk
            });
        }

        // setup call data for batch calling 10 `registerIpAndAttachLicenseAndAddToGroup`
        bytes[] memory data = new bytes[](NUM_IPS);
        for (uint256 i = 0; i < NUM_IPS; i++) {
            data[i] = abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "registerIpAndAttachLicenseAndAddToGroup(address,uint256,address,(address,uint256,(bool,uint256,address,bytes,uint32,bool,uint32,address))[],(string,bytes32,string,bytes32),(address,uint256,bytes),(address,uint256,bytes))"
                    )
                ),
                address(spgNftContract),
                tokenIds[i],
                groupId,
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
        for (uint256 i = 0; i < NUM_IPS; i++) {
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

    /// @notice Initializes test data and sets up the test environment
    /// @dev Sets up licenses, groups, and NFT collection
    function _setUpTest() private {
        revShare = 10 * 10 ** 6; // 10% (10 million basis points)
        
        testLicensesData.push(
            WorkflowStructs.LicenseData({
                licenseTemplate: pilTemplateAddr,
                licenseTermsId: pilTemplate.registerLicenseTerms(
                    // minting fee is set to 0 because currently core protocol requires group IP's minting fee to be 0
                    PILFlavors.commercialRemix({
                        mintingFee: 0,
                        commercialRevShare: revShare,
                        royaltyPolicy: royaltyPolicyLAPAddr,
                        currencyToken: address(StoryUSD)
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

            bytes[] memory data = new bytes[](NUM_IPS);
            for (uint256 i = 0; i < NUM_IPS; i++) {
                data[i] = abi.encodeWithSelector(
                    bytes4(keccak256("mintAndRegisterIp(address,address,(string,bytes32,string,bytes32),bool)")),
                    address(spgNftContract),
                    testSender,
                    testIpMetadata,
                    true
                );
            }

            StoryUSD.mint(testSender, testMintFee * NUM_IPS);
            StoryUSD.approve(address(spgNftContract), testMintFee * NUM_IPS);

            // batch call `mintAndRegisterIp`
            bytes[] memory results = registrationWorkflows.multicall(data);

            // decode the multicall results to get the IP IDs
            ipIds = new address[](NUM_IPS);
            for (uint256 i = 0; i < NUM_IPS; i++) {
                (ipIds[i], ) = abi.decode(results[i], (address, uint256));
            }

            // attach license terms to the IPs
            for (uint256 i = 0; i < NUM_IPS; i++) {
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
