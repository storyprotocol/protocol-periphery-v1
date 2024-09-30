//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IGroupIPAssetRegistry.sol";

// contracts
import { LicensingHelper } from "../../contracts/lib/LicensingHelper.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// test
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockERC721 } from "../mocks/MockERC721.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";

contract GroupingWorkflowsTest is BaseTest {
    using Strings for uint256;

    uint256 internal constant testLicenseTermsId = 1;

    address internal groupOwner;
    address internal groupId;

    uint256 internal groupOwnerSk;

    // Individual IP IDs for adding to a group
    address[] internal ipIds;

    function setUp() public override {
        super.setUp();

        groupOwner = u.bob;
        groupOwnerSk = sk.bob;

        // setup a group IPA
        _setupGroup();

        // setup individual IPs
        _setupIPs();
    }

    // Mint → Register IP → Attach license terms → Add new IP to group IPA
    function test_GroupingWorkflows_mintAndRegisterIpAndAttachLicenseAndAddToGroup() public {
        uint256 deadline = block.timestamp + 1000;

        // Get the signature for setting the permission for calling `addIp` function in `GroupingModule`
        // from the Group IP owner
        (bytes memory sigAddToGroup, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: groupId,
            to: address(groupingWorkflows),
            module: address(groupingModule),
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerSk: groupOwnerSk
        });

        vm.startPrank(minter);
        (address ipId, uint256 tokenId) = groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup({
            spgNftContract: address(spgNftPublic),
            groupId: groupId,
            recipient: minter,
            ipMetadata: ipMetadataDefault,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: testLicenseTermsId,
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: deadline,
                signature: sigAddToGroup
            })
        });
        vm.stopPrank();

        // check the group IP account state matches the expected state
        assertEq(IIPAccount(payable(groupId)).state(), expectedState);

        // check the IP is registered
        assertTrue(IIPAssetRegistry(ipAssetRegistry).isRegistered(ipId));

        // check the IP is added to the group
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistry).containsIp(groupId, ipId));

        // check the NFT metadata is correctly set
        assertEq(spgNftPublic.tokenURI(tokenId), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));

        // check the IP metadata is correctly set
        assertMetadata(ipId, ipMetadataDefault);

        // check the license terms is correctly attached
        (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(address(licenseRegistry))
            .getAttachedLicenseTerms(ipId, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, testLicenseTermsId);
    }

    // Register IP → Attach license terms → Add new IP to group IPA
    function test_GroupingWorkflows_registerIpAndAttachLicenseAndAddToGroup() public {
        // mint a NFT from the mock ERC721 contract
        vm.startPrank(minter);
        uint256 tokenId = MockERC721(mockNft).mint(minter);
        vm.stopPrank();

        // get the expected IP ID
        address expectedIpId = IIPAssetRegistry(ipAssetRegistry).ipId(block.chainid, address(mockNft), tokenId);

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
            module: address(groupingModule),
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerSk: groupOwnerSk
        });

        address ipId = groupingWorkflows.registerIpAndAttachLicenseAndAddToGroup({
            nftContract: address(mockNft),
            tokenId: tokenId,
            groupId: groupId,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: testLicenseTermsId,
            ipMetadata: ipMetadataDefault,
            sigMetadataAndAttach: WorkflowStructs.SignatureData({
                signer: minter,
                deadline: deadline,
                signature: sigMetadataAndAttach
            }),
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: deadline,
                signature: sigAddToGroup
            })
        });

        // check the IP id matches the expected IP id
        assertEq(ipId, expectedIpId);

        // check the IP is registered
        assertTrue(IIPAssetRegistry(ipAssetRegistry).isRegistered(ipId));

        // check the IP is added to the group
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistry).containsIp(groupId, ipId));

        // check the IP metadata is correctly set
        assertMetadata(ipId, ipMetadataDefault);

        // check the license terms is correctly attached
        (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistry).getAttachedLicenseTerms(
            ipId,
            0
        );
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, testLicenseTermsId);
    }

    // Register group IP → Attach license terms to group IPA
    function test_GroupingWorkflows_registerGroupAndAttachLicense() public {
        vm.startPrank(groupOwner);
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicense({
            groupPool: address(mockRewardPool),
            licenseTemplate: address(pilTemplate),
            licenseTermsId: testLicenseTermsId
        });
        vm.stopPrank();

        // check the group IPA is registered
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistry).isRegisteredGroup(newGroupId));

        // check the license terms is correctly attached to the group IPA
        (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistry).getAttachedLicenseTerms(
            newGroupId,
            0
        );
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, testLicenseTermsId);
    }

    // Register group IP → Attach license terms to group IPA → Add existing IPs to the new group IPA
    function test_GroupingWorkflows_registerGroupAndAttachLicenseAndAddIps() public {
        vm.startPrank(groupOwner);
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: address(mockRewardPool),
            ipIds: ipIds,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: testLicenseTermsId
        });
        vm.stopPrank();

        // check the group IPA is registered
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistry).isRegisteredGroup(newGroupId));

        // check all the individual IPs are added to the new group
        assertEq(IGroupIPAssetRegistry(ipAssetRegistry).totalMembers(newGroupId), ipIds.length);
        for (uint256 i = 0; i < ipIds.length; i++) {
            assertTrue(IGroupIPAssetRegistry(ipAssetRegistry).containsIp(newGroupId, ipIds[i]));
        }

        // check the license terms is correctly attached to the group IPA
        (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistry).getAttachedLicenseTerms(
            newGroupId,
            0
        );
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, testLicenseTermsId);
    }

    // Multicall (mint → Register IP → Attach PIL terms → Add new IP to group IPA)
    function test_GroupingWorkflows_multicall_mintAndRegisterIpAndAttachLicenseAndAddToGroup() public {
        uint256 deadline = block.timestamp + 1000;

        // Get the signatures for setting the permission for calling `addIp` function in `GroupingModule`
        // from the Group IP owner
        bytes[] memory sigsAddToGroup = new bytes[](10);
        bytes32 expectedStates = IIPAccount(payable(groupId)).state();
        for (uint256 i = 0; i < 10; i++) {
            (sigsAddToGroup[i], expectedStates, ) = _getSetPermissionSigForPeriphery({
                ipId: groupId,
                to: address(groupingWorkflows),
                module: address(groupingModule),
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
                address(spgNftPublic),
                groupId,
                minter,
                pilTemplate,
                testLicenseTermsId,
                ipMetadataDefault,
                WorkflowStructs.SignatureData({ signer: groupOwner, deadline: deadline, signature: sigsAddToGroup[i] })
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
            assertTrue(IIPAssetRegistry(ipAssetRegistry).isRegistered(ipId));
            assertTrue(IGroupIPAssetRegistry(ipAssetRegistry).containsIp(groupId, ipId));
            assertEq(spgNftPublic.tokenURI(tokenId), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
            assertMetadata(ipId, ipMetadataDefault);
            (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistry)
                .getAttachedLicenseTerms(ipId, 0);
            assertEq(licenseTemplate, address(pilTemplate));
            assertEq(licenseTermsId, testLicenseTermsId);
        }
    }

    // Multicall (Register IP → Attach PIL terms → Add new IP to group IPA)
    function test_GroupingWorkflows_multicall_registerIpAndAttachLicenseAndAddToGroup() public {
        // mint a NFT from the mock ERC721 contract
        uint256[] memory tokenIds = new uint256[](10);
        vm.startPrank(minter);
        for (uint256 i = 0; i < 10; i++) {
            tokenIds[i] = MockERC721(mockNft).mint(minter);
        }
        vm.stopPrank();

        // get the expected IP ID
        address[] memory expectedIpIds = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            expectedIpIds[i] = IIPAssetRegistry(ipAssetRegistry).ipId(block.chainid, address(mockNft), tokenIds[i]);
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
                module: address(groupingModule),
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
                mockNft,
                tokenIds[i],
                groupId,
                pilTemplate,
                testLicenseTermsId,
                ipMetadataDefault,
                WorkflowStructs.SignatureData({
                    signer: minter,
                    deadline: deadline,
                    signature: sigsMetadataAndAttach[i]
                }),
                WorkflowStructs.SignatureData({ signer: groupOwner, deadline: deadline, signature: sigsAddToGroup[i] })
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
            assertTrue(IIPAssetRegistry(ipAssetRegistry).isRegistered(ipId));
            assertTrue(IGroupIPAssetRegistry(ipAssetRegistry).containsIp(groupId, ipId));
            assertMetadata(ipId, ipMetadataDefault);
            (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistry)
                .getAttachedLicenseTerms(ipId, 0);
            assertEq(licenseTemplate, address(pilTemplate));
            assertEq(licenseTermsId, testLicenseTermsId);
        }
    }

    // setup a group IPA for testing
    function _setupGroup() internal {
        // register a group and attach default PIL terms to it
        vm.startPrank(groupOwner);
        groupId = IGroupingModule(groupingModule).registerGroup(address(mockRewardPool));
        vm.label(groupId, "Group1");
        LicensingHelper.attachLicenseTerms(
            groupId,
            address(licensingModule),
            address(licenseRegistry),
            address(pilTemplate),
            testLicenseTermsId
        );
        vm.stopPrank();
    }

    // setup individual IPs for testing
    function _setupIPs() internal {
        // mint and approve tokens for minting
        vm.startPrank(minter);
        MockERC20(mockToken).mint(minter, 1000 * 10 * 10 ** MockERC20(mockToken).decimals());
        MockERC20(mockToken).approve(address(spgNftPublic), 1000 * 10 * 10 ** MockERC20(mockToken).decimals());
        vm.stopPrank();

        // setup call data for batch calling `mintAndRegisterIp` to create 10 IPs
        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                registrationWorkflows.mintAndRegisterIp.selector,
                address(spgNftPublic),
                minter,
                ipMetadataDefault
            );
        }

        // batch call `mintAndRegisterIp`
        vm.startPrank(minter);
        bytes[] memory results = registrationWorkflows.multicall(data);
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
                address(licensingModule),
                address(licenseRegistry),
                address(pilTemplate),
                testLicenseTermsId
            );
        }
        vm.stopPrank();
    }
}
