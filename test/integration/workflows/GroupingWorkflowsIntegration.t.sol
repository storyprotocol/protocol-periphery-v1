//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IGroupIPAssetRegistry.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { LicensingHelper } from "../../../contracts/lib/LicensingHelper.sol";
import { IStoryProtocolGateway as ISPG } from "../../../contracts/interfaces/IStoryProtocolGateway.sol";

// test
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockERC721 } from "../../mocks/MockERC721.sol";
import { BaseIntegration } from "../BaseIntegration.t.sol";
import { MockEvenSplitGroupPool } from "../../mocks/MockEvenSplitGroupPool.sol";

contract GroupingWorkflowsIntegration is BaseIntegration {
    uint256 internal constant testLicenseTermsId = 0;

    address internal groupOwner;
    address internal groupId;

    uint256 internal groupOwnerSk;

    // Mock group pool
    address internal rewardPool;

    // Individual IP IDs for testing
    address[] internal ipIds;

    function setUp() public override {
        super.setUp();

        // setup users
        minter = u.alice;
        groupOwner = u.bob;
        feeRecipient = u.carl;

        // setup secret keys
        minterSk = sk.alice;
        groupOwnerSk = sk.bob;

        // setup a group IPA
        _setupGroup();

        // setup individual IPs
        _setupIPs();
    }

    // Mint → Register IP → Attach license terms → Add new IP to group IPA
    function test_Integ_Grouping_mintAndRegisterIpAndAttachLicenseAndAddToGroup() public {
        uint256 deadline = block.timestamp + 1000;

        // Get the signature for setting the permission for calling `addIp` function in `GroupingModule`
        // from the Group IP owner
        (bytes memory sigAddToGroup, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: groupId,
            to: address(groupingWorkflows),
            module: address(groupingModuleAddr),
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerSk: groupOwnerSk
        });

        vm.startPrank(minter);
        (address ipId, uint256 tokenId) = groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup({
            spgNftContract: spgNFT,
            groupId: groupId,
            recipient: minter,
            ipMetadata: ipMetadataDefault,
            licenseTemplate: pilTemplateAddr,
            licenseTermsId: testLicenseTermsId,
            sigAddToGroup: ISPG.SignatureData({ signer: groupOwner, deadline: deadline, signature: sigAddToGroup })
        });
        vm.stopPrank();

        // check the group IP account state matches the expected state
        assertEq(IIPAccount(payable(groupId)).state(), expectedState);

        // check the IP is registered
        assertTrue(IIPAssetRegistry(ipAssetRegistryAddr).isRegistered(ipId));

        // check the IP is added to the group
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(groupId, ipId));

        // check the NFT metadata is correctly set
        assertEq(ISPGNFT(spgNFT).tokenURI(tokenId), ipMetadataDefault.nftMetadataURI);

        // check the IP metadata is correctly set
        assertMetadata(ipId, ipMetadataDefault);

        // check the license terms is correctly attached
        (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistryAddr)
            .getAttachedLicenseTerms(ipId, 0);
        assertEq(licenseTemplate, pilTemplateAddr);
        assertEq(licenseTermsId, testLicenseTermsId);
    }

    // Register IP → Attach license terms → Add new IP to group IPA
    function test_Integ_Grouping_registerIpAndAttachLicenseAndAddToGroup() public {
        // mint a NFT from the mock ERC721 contract
        vm.startPrank(minter);
        uint256 tokenId = MockERC721(mockNFT).mint(minter);
        vm.stopPrank();

        // get the expected IP ID
        address expectedIpId = IIPAssetRegistry(ipAssetRegistryAddr).ipId(block.chainid, mockNFT, tokenId);

        uint256 deadline = block.timestamp + 1000;

        // Get the signature for setting the permission for calling `setAll` (IP metadata) and `attachLicenseTerms`
        // functions in `coreMetadataModule` and `licensingModule` from the IP owner
        (bytes memory sigMetadataAndAttach, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndAttachTermsPermissionList(expectedIpId, address(groupingWorkflows)),
            deadline: deadline,
            state: bytes32(0),
            signerSk: minterSk
        });

        // Get the signature for setting the permission for calling `addIp` function in `GroupingModule`
        // from the Group IP owner
        (bytes memory sigAddToGroup, , ) = _getSetPermissionSigForPeriphery({
            ipId: groupId,
            to: address(groupingWorkflows),
            module: address(groupingModuleAddr),
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerSk: groupOwnerSk
        });

        address ipId = groupingWorkflows.registerIpAndAttachLicenseAndAddToGroup({
            nftContract: mockNFT,
            tokenId: tokenId,
            groupId: groupId,
            licenseTemplate: pilTemplateAddr,
            licenseTermsId: testLicenseTermsId,
            ipMetadata: ipMetadataDefault,
            sigMetadataAndAttach: ISPG.SignatureData({
                signer: minter,
                deadline: deadline,
                signature: sigMetadataAndAttach
            }),
            sigAddToGroup: ISPG.SignatureData({ signer: groupOwner, deadline: deadline, signature: sigAddToGroup })
        });

        // check the IP id matches the expected IP id
        assertEq(ipId, expectedIpId);

        // check the IP is registered
        assertTrue(IIPAssetRegistry(ipAssetRegistryAddr).isRegistered(ipId));

        // check the IP is added to the group
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(groupId, ipId));

        // check the IP metadata is correctly set
        assertMetadata(ipId, ipMetadataDefault);

        // check the license terms is correctly attached
        (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistryAddr)
            .getAttachedLicenseTerms(ipId, 0);
        assertEq(licenseTemplate, pilTemplateAddr);
        assertEq(licenseTermsId, testLicenseTermsId);
    }

    // Register group IP → Attach license terms to group IPA → Add existing IPs to the new group IPA
    function test_Integ_Grouping_registerGroupAndAttachLicenseAndAddIps() public {
        vm.startPrank(groupOwner);
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: rewardPool,
            ipIds: ipIds,
            licenseTemplate: pilTemplateAddr,
            licenseTermsId: testLicenseTermsId
        });
        vm.stopPrank();

        // check the group IPA is registered
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).isRegisteredGroup(newGroupId));

        // check all the individual IPs are added to the new group
        assertEq(IGroupIPAssetRegistry(ipAssetRegistryAddr).totalMembers(newGroupId), ipIds.length);
        for (uint256 i = 0; i < ipIds.length; i++) {
            assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(newGroupId, ipIds[i]));
        }

        // check the license terms is correctly attached to the group IPA
        (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistryAddr)
            .getAttachedLicenseTerms(newGroupId, 0);
        assertEq(licenseTemplate, pilTemplateAddr);
        assertEq(licenseTermsId, testLicenseTermsId);
    }

    // Multicall (mint → Register IP → Attach PIL terms → Add new IP to group IPA)
    function test_Integ_Grouping_Multi_mintAndRegisterIpAndAttachLicenseAndAddToGroup() public {
        uint256 deadline = block.timestamp + 1000;

        // Get the signatures for setting the permission for calling `addIp` function in `GroupingModule`
        // from the Group IP owner
        bytes[] memory sigsAddToGroup = new bytes[](10);
        bytes32 expectedStates = IIPAccount(payable(groupId)).state();
        for (uint256 i = 0; i < 10; i++) {
            (sigsAddToGroup[i], expectedStates, ) = _getSetPermissionSigForPeriphery({
                ipId: groupId,
                to: address(groupingWorkflows),
                module: address(groupingModuleAddr),
                selector: IGroupingModule.addIp.selector,
                deadline: deadline,
                state: expectedStates,
                signerSk: groupOwnerSk
            });
        }

        // setup call data for batch calling 10 `mintAndRegisterIpAndAttachLicenseAndAddToGroup`
        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup.selector,
                spgNFT,
                groupId,
                minter,
                pilTemplateAddr,
                testLicenseTermsId,
                ipMetadataDefault,
                ISPG.SignatureData({ signer: groupOwner, deadline: deadline, signature: sigsAddToGroup[i] })
            );
        }

        // batch call `mintAndRegisterIpAndAttachLicenseAndAddToGroup`
        vm.startPrank(minter);
        bytes[] memory results = groupingWorkflows.multicall(data);
        vm.stopPrank();

        // check each IP is registered, added to the group, and metadata is set, license terms are attached
        address ipId;
        uint256 tokenId;
        for (uint256 i = 0; i < 10; i++) {
            (ipId, tokenId) = abi.decode(results[i], (address, uint256));
            assertTrue(IIPAssetRegistry(ipAssetRegistryAddr).isRegistered(ipId));
            assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(groupId, ipId));
            assertEq(ISPGNFT(spgNFT).tokenURI(tokenId), ipMetadataDefault.nftMetadataURI);
            assertMetadata(ipId, ipMetadataDefault);
            (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistryAddr)
                .getAttachedLicenseTerms(ipId, 0);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, testLicenseTermsId);
        }
    }

    // Multicall (Register IP → Attach PIL terms → Add new IP to group IPA)
    function test_Integ_Grouping_Multi_registerIpAndAttachLicenseAndAddToGroup() public {
        // mint a NFT from the mock ERC721 contract
        uint256[] memory tokenIds = new uint256[](10);
        vm.startPrank(minter);
        for (uint256 i = 0; i < 10; i++) {
            tokenIds[i] = MockERC721(mockNFT).mint(minter);
        }
        vm.stopPrank();

        // get the expected IP ID
        address[] memory expectedIpIds = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            expectedIpIds[i] = IIPAssetRegistry(ipAssetRegistryAddr).ipId(block.chainid, mockNFT, tokenIds[i]);
        }

        uint256 deadline = block.timestamp + 10000;

        // Get the signatures for setting the permission for calling `setAll` (IP metadata) and `attachLicenseTerms`
        // functions in `coreMetadataModule` and `licensingModule` from the IP owner
        bytes[] memory sigsMetadataAndAttach = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            (sigsMetadataAndAttach[i], , ) = _getSetBatchPermissionSigForPeriphery({
                ipId: expectedIpIds[i],
                permissionList: _getMetadataAndAttachTermsPermissionList(expectedIpIds[i], address(groupingWorkflows)),
                deadline: deadline,
                state: bytes32(0),
                signerSk: minterSk
            });
        }

        // Get the signatures for setting the permission for calling `addIp` function in `GroupingModule`
        // from the Group IP owner
        bytes[] memory sigsAddToGroup = new bytes[](10);
        bytes32 expectedStates = IIPAccount(payable(groupId)).state();
        for (uint256 i = 0; i < 10; i++) {
            (sigsAddToGroup[i], expectedStates, ) = _getSetPermissionSigForPeriphery({
                ipId: groupId,
                to: address(groupingWorkflows),
                module: address(groupingModuleAddr),
                selector: IGroupingModule.addIp.selector,
                deadline: deadline,
                state: expectedStates,
                signerSk: groupOwnerSk
            });
        }

        // setup call data for batch calling 10 `registerIpAndAttachLicenseAndAddToGroup`
        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                groupingWorkflows.registerIpAndAttachLicenseAndAddToGroup.selector,
                mockNFT,
                tokenIds[i],
                groupId,
                pilTemplateAddr,
                testLicenseTermsId,
                ipMetadataDefault,
                ISPG.SignatureData({ signer: minter, deadline: deadline, signature: sigsMetadataAndAttach[i] }),
                ISPG.SignatureData({ signer: groupOwner, deadline: deadline, signature: sigsAddToGroup[i] })
            );
        }

        // batch call `registerIpAndAttachLicenseAndAddToGroup`
        vm.startPrank(minter);
        bytes[] memory results = groupingWorkflows.multicall(data);
        vm.stopPrank();

        // check each IP is registered, added to the group, and metadata is set, license terms are attached
        address ipId;
        for (uint256 i = 0; i < 10; i++) {
            ipId = abi.decode(results[i], (address));
            assertEq(ipId, expectedIpIds[i]);
            assertTrue(IIPAssetRegistry(ipAssetRegistryAddr).isRegistered(ipId));
            assertTrue(IGroupIPAssetRegistry(ipAssetRegistryAddr).containsIp(groupId, ipId));
            assertMetadata(ipId, ipMetadataDefault);
            (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistryAddr)
                .getAttachedLicenseTerms(ipId, 0);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, testLicenseTermsId);
        }
    }

    // setup a group IPA for testing
    function _setupGroup() internal {
        // setup a group reward pool
        vm.startPrank(multiSig);
        rewardPool = address(new MockEvenSplitGroupPool());
        IGroupingModule(groupingModuleAddr).whitelistGroupRewardPool(rewardPool);
        vm.stopPrank();

        // register a group and attach default PIL terms to it
        vm.startPrank(groupOwner);
        groupId = IGroupingModule(groupingModuleAddr).registerGroup(rewardPool);
        vm.label(groupId, "Group1");
        LicensingHelper.attachLicenseTerms(
            groupId,
            licensingModuleAddr,
            licenseRegistryAddr,
            pilTemplateAddr,
            testLicenseTermsId
        );
        vm.stopPrank();
    }

    // setup individual IPs for testing
    function _setupIPs() internal {
        // mint and approve tokens for minting
        vm.startPrank(minter);
        MockERC20(mockToken).mint(minter, 1000 * 10 * 10 ** MockERC20(mockToken).decimals());
        MockERC20(mockToken).approve(spgNFT, 1000 * 10 * 10 ** MockERC20(mockToken).decimals());
        vm.stopPrank();

        // setup call data for batch calling `mintAndRegisterIp` to create 10 IPs
        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(spg.mintAndRegisterIp.selector, spgNFT, minter, ipMetadataDefault);
        }

        // batch call `mintAndRegisterIp`
        vm.startPrank(minter);
        bytes[] memory results = spg.multicall(data);
        vm.stopPrank();

        // decode the multicall results to get the IP IDs
        ipIds = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            (ipIds[i], ) = abi.decode(results[i], (address, uint256));
        }

        // attach license terms to the IPs
        vm.startPrank(minter);
        for (uint256 i = 0; i < 10; i++) {
            LicensingHelper.attachLicenseTerms(
                ipIds[i],
                licensingModuleAddr,
                licenseRegistryAddr,
                pilTemplateAddr,
                testLicenseTermsId
            );
        }
        vm.stopPrank();
    }
}
