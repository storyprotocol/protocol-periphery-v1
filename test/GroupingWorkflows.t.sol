// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "./utils/BaseTest.t.sol";

import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";

import { IStoryProtocolGateway as ISPG } from "../contracts/interfaces/IStoryProtocolGateway.sol";

contract GroupingWorkflowsTest is BaseTest {
    address internal groupId;

    function setUp() public override {
        super.setUp();
        minter = alice;
    }

    modifier withGroup() {
        groupId = groupingModule.registerGroup(address(rewardPool));
        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature, , bytes memory data) = _getSetPermissionSigForPeriphery({
            ipId: groupId,
            to: address(spg),
            module: address(licensingModule),
            selector: ILicensingModule.attachLicenseTerms.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerPk: alicePk
        });

        IIPAccount(payable(groupId)).executeWithSig({
            to: address(accessController),
            value: 0,
            data: data,
            signer: alice,
            deadline: deadline,
            signature: signature
        });

        uint256 licenseTermsId = spg.registerPILTermsAndAttach({
            ipId: groupId,
            terms: PILFlavors.nonCommercialSocialRemixing()
        });
        _;
    }

    function test_GroupingWorkflows_mintAndRegisterIpAndAttachPILTermsAndAddToGroup()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
        withGroup
    {
        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigAddToGroup, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: groupId,
            to: address(groupingWorkflows),
            module: address(groupingModule),
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerPk: alicePk
        });

        (address ipId, uint256 tokenId) = groupingWorkflows.mintAndRegisterIpAndAttachPILTermsAndAddToGroup({
            spgNftContract: address(nftContract),
            groupId: groupId,
            recipient: caller,
            ipMetadata: ipMetadataEmpty,
            licenseTermsId: 1,
            sigAddToGroup: ISPG.SignatureData({ signer: alice, deadline: deadline, signature: sigAddToGroup })
        });

        assertEq(expectedState, IIPAccount(payable(groupId)).state());
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertTrue(ipAssetRegistry.isRegisteredGroup(groupId));
        assertTrue(ipAssetRegistry.containsIp(groupId, ipId));
        assertEq(ipAssetRegistry.totalMembers(groupId), 1);
        assertEq(tokenId, 1);
        assertSPGNFTMetadata(tokenId, ipMetadataEmpty.nftMetadataURI);
        assertMetadata(ipId, ipMetadataEmpty);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, 1);
    }

    function test_GroupingWorkflows_registerIpAndAttachPILTermsAndAddToGroup()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens
        withGroup
    {
        uint256 tokenId = nftContract.mint(address(caller), ipMetadataEmpty.nftMetadataURI);
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadataAndAttach, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndAttachTermsPermissionList(expectedIpId, address(groupingWorkflows)),
            deadline: deadline,
            state: bytes32(0),
            signerPk: alicePk
        });

        (bytes memory sigAddToGroup, , ) = _getSetPermissionSigForPeriphery({
            ipId: groupId,
            to: address(groupingWorkflows),
            module: address(groupingModule),
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerPk: alicePk
        });

        address ipId = groupingWorkflows.registerIpAndAttachPILTermsAndAddToGroup({
            nftContract: address(nftContract),
            tokenId: tokenId,
            groupId: groupId,
            ipMetadata: ipMetadataEmpty,
            licenseTermsId: 1,
            sigMetadataAndAttach: ISPG.SignatureData({
                signer: alice,
                deadline: deadline,
                signature: sigMetadataAndAttach
            }),
            sigAddToGroup: ISPG.SignatureData({ signer: alice, deadline: deadline, signature: sigAddToGroup })
        });

        assertEq(expectedIpId, ipId);
        assertTrue(ipAssetRegistry.isRegistered(expectedIpId));
        assertTrue(ipAssetRegistry.isRegisteredGroup(groupId));
        assertTrue(ipAssetRegistry.containsIp(groupId, expectedIpId));
        assertEq(ipAssetRegistry.totalMembers(groupId), 1);
        assertSPGNFTMetadata(tokenId, ipMetadataEmpty.nftMetadataURI);
        assertMetadata(expectedIpId, ipMetadataEmpty);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(expectedIpId, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, 1);
    }

    function test_GroupingWorkflows_registerGroupAndAttachPILTermsAndAddIps()
        public
        withCollection
        whenCallerHasMinterRole
    {
        mockToken.mint(address(caller), 1000 * 10 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 * 10 ** mockToken.decimals());

        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                spg.mintAndRegisterIpAndAttachPILTerms.selector,
                address(nftContract),
                bob,
                ipMetadataDefault,
                PILFlavors.nonCommercialSocialRemixing()
            );
        }
        bytes[] memory results = spg.multicall(data);
        address[] memory ipIds = new address[](10);

        for (uint256 i = 0; i < 10; i++) {
            (ipIds[i], ) = abi.decode(results[i], (address, uint256));
        }

        uint256 groupLicenseTermsId;
        (groupId, groupLicenseTermsId) = groupingWorkflows.registerGroupAndAttachPILTermsAndAddIps(
            address(rewardPool),
            ipIds,
            PILFlavors.nonCommercialSocialRemixing()
        );

        assertTrue(ipAssetRegistry.isRegisteredGroup(groupId));
        assertEq(groupLicenseTermsId, 1);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(groupId, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, groupLicenseTermsId);

        assertEq(ipAssetRegistry.totalMembers(groupId), 10);
        for (uint256 i = 0; i < 10; i++) {
            assertTrue(ipAssetRegistry.containsIp(groupId, ipIds[i]));
        }
    }
}
