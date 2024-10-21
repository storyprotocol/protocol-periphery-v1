// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IGroupIPAssetRegistry.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

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
            })
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
        uint256 tokenId = spgNftContract.mint(testSender, testIpMetadata.nftMetadataURI);

        // get the expected IP ID
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        // Get the signature for setting the permission for calling `setAll` (IP metadata) and `attachLicenseTerms`
        // functions in `coreMetadataModule` and `licensingModule` from the IP owner
        (bytes memory sigMetadataAndAttach, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndAttachTermsPermissionList(expectedIpId, groupingWorkflowsAddr),
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
            licenseTemplate: testLicenseTemplate,
            licenseTermsId: testLicenseTermsId,
            ipMetadata: testIpMetadata,
            sigMetadataAndAttach: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadataAndAttach
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

    function _test_GroupingIntegration_multicall_mintAndRegisterIpAndAttachLicenseAndAddToGroup()
        private
        logTest("test_GroupingIntegration_multicall_mintAndRegisterIpAndAttachLicenseAndAddToGroup")
    {
        uint256 deadline = block.timestamp + 1000;
        uint256 numCalls = 10;
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
            tokenIds[i] = spgNftContract.mint(testSender, testIpMetadata.nftMetadataURI);
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
                permissionList: _getMetadataAndAttachTermsPermissionList(expectedIpIds[i], address(groupingWorkflows)),
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
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
            assertEq(licenseTemplate, testLicenseTemplate);
            assertEq(licenseTermsId, testLicenseTermsId);
        }
    }

    function _setUpTest() private {
        testLicenseTemplate = pilTemplateAddr;
        testLicenseTermsId = pilTemplate.registerLicenseTerms(
            // minting fee is set to 0 beacause currently core protocol requires group IP's minting fee to be 0
            PILFlavors.commercialUse(0, testMintFeeToken, royaltyPolicyLRPAddr)
        );

        // setup a group
        {
            groupId = groupingModule.registerGroup(evenSplitGroupPoolAddr);
            LicensingHelper.attachLicenseTerms(
                groupId,
                licensingModuleAddr,
                licenseRegistryAddr,
                testLicenseTemplate,
                testLicenseTermsId
            );
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

            uint256 numIps = 10;

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
                LicensingHelper.attachLicenseTerms(
                    ipIds[i],
                    licensingModuleAddr,
                    licenseRegistryAddr,
                    pilTemplateAddr,
                    testLicenseTermsId
                );
            }
        }
    }
}
