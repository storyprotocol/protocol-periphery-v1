//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IGroupIPAssetRegistry.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
// contracts
import { Errors } from "../../contracts/lib/Errors.sol";
import { LicensingHelper } from "../../contracts/lib/LicensingHelper.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// test
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockERC721 } from "../mocks/MockERC721.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";

contract GroupingWorkflowsTest is BaseTest, ERC721Holder {
    using Strings for uint256;

    WorkflowStructs.LicenseData[] internal testLicensesData;
    WorkflowStructs.LicenseData[] internal testGroupLicenseData;
    uint32 internal revShare;

    address internal groupOwner;
    address internal groupId;

    uint256 internal groupOwnerSk;

    // Individual IP IDs for adding to a group
    address[] internal ipIds;

    function setUp() public override {
        super.setUp();

        groupOwner = u.bob;
        groupOwnerSk = sk.bob;

        // register license terms
        revShare = 10 * 10 ** 6; // 10%
        testLicensesData.push(
            WorkflowStructs.LicenseData({
                licenseTemplate: address(pilTemplate),
                licenseTermsId: pilTemplate.registerLicenseTerms(
                    PILFlavors.commercialRemix({
                        mintingFee: 0,
                        commercialRevShare: revShare,
                        currencyToken: address(mockToken),
                        royaltyPolicy: address(royaltyPolicyLRP)
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
                    expectGroupRewardPool: address(evenSplitGroupPool)
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

        // setup a group IPA
        _setupGroup();

        // setup individual IPs
        _setupIPs();
    }

    function test_GroupingWorkflows_revert_DuplicatedNFTMetadataHash() public {
        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigAddToGroup, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: groupId,
            to: address(groupingWorkflows),
            module: address(groupingModule),
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerSk: groupOwnerSk
        });

        vm.startPrank(groupOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SPGNFT__DuplicatedNFTMetadataHash.selector,
                address(spgNftPublic),
                1,
                ipMetadataDefault.nftMetadataHash
            )
        );
        groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup({
            spgNftContract: address(spgNftPublic),
            groupId: groupId,
            recipient: groupOwner,
            maxAllowedRewardShare: 100e6, // 100%
            ipMetadata: ipMetadataDefault,
            licensesData: testLicensesData,
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: deadline,
                signature: sigAddToGroup
            }),
            allowDuplicates: false
        });
        vm.stopPrank();
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
        vm.startPrank(groupOwner);
        (address ipId, uint256 tokenId) = groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup({
            spgNftContract: address(spgNftPublic),
            groupId: groupId,
            recipient: groupOwner,
            maxAllowedRewardShare: 100e6, // 100%
            ipMetadata: ipMetadataDefault,
            licensesData: testLicensesData,
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: deadline,
                signature: sigAddToGroup
            }),
            allowDuplicates: true
        });
        vm.stopPrank();
        // check the group IP account state matches the expected state
        assertEq(
            IIPAccount(payable(groupId)).state(),
            _predictNextState(
                expectedState,
                abi.encodeWithSelector(IGroupingModule.addIp.selector, groupId, ipId, 100e6)
            )
        );
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
        assertEq(licenseTermsId, testLicensesData[0].licenseTermsId);
    }

    // Register IP → Attach license terms → Add new IP to group IPA
    function test_GroupingWorkflows_registerIpAndAttachLicenseAndAddToGroup() public {
        // mint a NFT from the mock ERC721 contract
        vm.startPrank(groupOwner);
        uint256 tokenId = MockERC721(mockNft).mint(groupOwner);
        vm.stopPrank();
        // get the expected IP ID
        address expectedIpId = IIPAssetRegistry(ipAssetRegistry).ipId(block.chainid, address(mockNft), tokenId);
        uint256 deadline = block.timestamp + 1000;
        // Get the signature for setting the permission for calling `setAll` (IP metadata) and `attachLicenseTerms`
        // functions in `coreMetadataModule` and `licensingModule` from the IP owner
        (bytes memory sigMetadataAndAttachAndConfig, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndAttachTermsAndConfigPermissionList(expectedIpId, address(groupingWorkflows)),
            deadline: deadline,
            state: bytes32(0),
            signerSk: groupOwnerSk
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
        vm.startPrank(groupOwner);
        address ipId = groupingWorkflows.registerIpAndAttachLicenseAndAddToGroup({
            nftContract: address(mockNft),
            tokenId: tokenId,
            groupId: groupId,
            maxAllowedRewardShare: 100e6, // 100%
            licensesData: testLicensesData,
            ipMetadata: ipMetadataDefault,
            sigMetadataAndAttachAndConfig: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: deadline,
                signature: sigMetadataAndAttachAndConfig
            }),
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: deadline,
                signature: sigAddToGroup
            })
        });
        vm.stopPrank();

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
        assertEq(licenseTermsId, testLicensesData[0].licenseTermsId);
    }

    // Register group IP → Attach license terms to group IPA
    function test_GroupingWorkflows_registerGroupAndAttachLicense() public {
        vm.startPrank(groupOwner);
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicense({
            groupPool: address(evenSplitGroupPool),
            licenseData: testGroupLicenseData[0]
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
        assertEq(licenseTermsId, testGroupLicenseData[0].licenseTermsId);
    }

    // Register group IP → Attach license terms to group IPA → Add existing IPs to the new group IPA
    function test_GroupingWorkflows_registerGroupAndAttachLicenseAndAddIps() public {
        vm.startPrank(groupOwner);
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: address(evenSplitGroupPool),
            ipIds: ipIds,
            maxAllowedRewardShare: 100e6, // 100%
            licenseData: testGroupLicenseData[0]
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
        assertEq(licenseTermsId, testGroupLicenseData[0].licenseTermsId);
    }

    // Collect royalties for the entire group and distribute to each member IP's royalty vault
    function test_GroupingWorkflows_collectRoyaltiesAndClaimReward() public {
        address ipOwner1 = u.bob;
        address ipOwner2 = u.carl;

        vm.startPrank(groupOwner);
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: address(evenSplitGroupPool),
            ipIds: ipIds,
            maxAllowedRewardShare: 100e6, // 100%
            licenseData: testGroupLicenseData[0]
        });
        vm.stopPrank();

        assertEq(ipAssetRegistry.totalMembers(newGroupId), 10);
        assertEq(evenSplitGroupPool.getTotalIps(newGroupId), 10);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = newGroupId;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = testGroupLicenseData[0].licenseTermsId;

        vm.startPrank(ipOwner1);
        // approve nft minting fee
        mockToken.mint(ipOwner1, 1 * 10 ** mockToken.decimals());
        mockToken.approve(address(spgNftPublic), 1 * 10 ** mockToken.decimals());

        (address ipId1, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(spgNftPublic),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTermsIds: licenseTermsIds,
                licenseTemplate: testGroupLicenseData[0].licenseTemplate,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: ipMetadataDefault,
            recipient: ipOwner1,
            allowDuplicates: true
        });
        vm.stopPrank();

        vm.startPrank(ipOwner2);
        // approve nft minting fee
        mockToken.mint(ipOwner2, 1 * 10 ** mockToken.decimals());
        mockToken.approve(address(spgNftPublic), 1 * 10 ** mockToken.decimals());

        (address ipId2, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(spgNftPublic),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTermsIds: licenseTermsIds,
                licenseTemplate: testGroupLicenseData[0].licenseTemplate,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: revShare,
                maxRevenueShare: 0
            }),
            ipMetadata: ipMetadataDefault,
            recipient: ipOwner2,
            allowDuplicates: true
        });
        vm.stopPrank();

        uint256 amount1 = 1_000 * 10 ** mockToken.decimals(); // 1,000 tokens
        mockToken.mint(ipOwner1, amount1);
        vm.startPrank(ipOwner1);
        mockToken.approve(address(royaltyModule), amount1);
        royaltyModule.payRoyaltyOnBehalf(ipId1, ipOwner1, address(mockToken), amount1);
        royaltyPolicyLRP.transferToVault(ipId1, newGroupId, address(mockToken));
        vm.stopPrank();

        uint256 amount2 = 10_000 * 10 ** mockToken.decimals(); // 10,000 tokens
        mockToken.mint(ipOwner2, amount2);
        vm.startPrank(ipOwner2);
        mockToken.approve(address(royaltyModule), amount2);
        royaltyModule.payRoyaltyOnBehalf(ipId2, ipOwner2, address(mockToken), amount2);
        royaltyPolicyLRP.transferToVault(ipId2, newGroupId, address(mockToken));
        vm.stopPrank();

        address[] memory royaltyTokens = new address[](1);
        royaltyTokens[0] = address(mockToken);

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
                MockERC20(mockToken).balanceOf(royaltyModule.ipRoyaltyVaults(ipIds[i])),
                collectedRoyalties[0] / ipIds.length // even split between all member IPs
            );
        }
    }

    // Revert if currency token contains zero address
    function test_GroupingWorkflows_revert_collectRoyaltiesAndClaimReward_zeroAddressParam() public {
        address[] memory currencyTokens = new address[](1);
        currencyTokens[0] = address(0);

        uint256[] memory snapshotIds = new uint256[](1);
        snapshotIds[0] = 0;

        vm.expectRevert(Errors.GroupingWorkflows__ZeroAddressParam.selector);
        groupingWorkflows.collectRoyaltiesAndClaimReward(groupId, currencyTokens, ipIds);
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
            expectedStates = _predictNextState(
                expectedStates,
                abi.encodeWithSelector(IGroupingModule.addIp.selector, groupId, ipIds[i], 100e6)
            );
        }
        // setup call data for batch calling 10 `mintAndRegisterIpAndAttachLicenseAndAddToGroup`
        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "mintAndRegisterIpAndAttachLicenseAndAddToGroup(address,address,address,uint256,(address,uint256,(bool,uint256,address,bytes,uint32,bool,uint32,address))[],(string,bytes32,string,bytes32),(address,uint256,bytes),bool)"
                    )
                ),
                address(spgNftPublic),
                groupId,
                groupOwner,
                100e6, // 100%
                testLicensesData,
                ipMetadataDefault,
                WorkflowStructs.SignatureData({ signer: groupOwner, deadline: deadline, signature: sigsAddToGroup[i] }),
                true
            );
        }
        // batch call `mintAndRegisterIpAndAttachLicenseAndAddToGroup`
        vm.startPrank(groupOwner);
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
            assertEq(licenseTermsId, testLicensesData[0].licenseTermsId);
        }
    }

    // Multicall (Register IP → Attach PIL terms → Add new IP to group IPA)
    function test_GroupingWorkflows_multicall_registerIpAndAttachLicenseAndAddToGroup() public {
        // mint a NFT from the mock ERC721 contract
        uint256[] memory tokenIds = new uint256[](10);
        vm.startPrank(groupOwner);
        for (uint256 i = 0; i < 10; i++) {
            tokenIds[i] = MockERC721(mockNft).mint(groupOwner);
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
                permissionList: _getMetadataAndAttachTermsAndConfigPermissionList(
                    expectedIpIds[i],
                    address(groupingWorkflows)
                ),
                deadline: deadline,
                state: bytes32(0),
                signerSk: groupOwnerSk
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
            expectedStates = _predictNextState(
                expectedStates,
                abi.encodeWithSelector(IGroupingModule.addIp.selector, groupId, expectedIpIds[i], 100e6)
            );
        }
        // setup call data for batch calling 10 `registerIpAndAttachLicenseAndAddToGroup`
        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "registerIpAndAttachLicenseAndAddToGroup(address,uint256,address,uint256,(address,uint256,(bool,uint256,address,bytes,uint32,bool,uint32,address))[],(string,bytes32,string,bytes32),(address,uint256,bytes),(address,uint256,bytes))"
                    )
                ),
                mockNft,
                tokenIds[i],
                groupId,
                100e6, // 100%
                testLicensesData,
                ipMetadataDefault,
                WorkflowStructs.SignatureData({
                    signer: groupOwner,
                    deadline: deadline,
                    signature: sigsMetadataAndAttach[i]
                }),
                WorkflowStructs.SignatureData({ signer: groupOwner, deadline: deadline, signature: sigsAddToGroup[i] })
            );
        }
        // batch call `registerIpAndAttachLicenseAndAddToGroup`
        vm.startPrank(groupOwner);
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
            assertEq(licenseTermsId, testLicensesData[0].licenseTermsId);
        }
    }

    function test_GroupingWorkflows_revert_NoLicenseData() public {
        vm.expectRevert(Errors.GroupingWorkflows__NoLicenseData.selector);
        groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup({
            spgNftContract: address(spgNftPublic),
            groupId: groupId,
            recipient: groupOwner,
            maxAllowedRewardShare: 100e6, // 100%
            ipMetadata: ipMetadataDefault,
            licensesData: new WorkflowStructs.LicenseData[](0),
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: block.timestamp + 1000,
                signature: new bytes(0)
            }),
            allowDuplicates: true
        });

        vm.expectRevert(Errors.GroupingWorkflows__NoLicenseData.selector);
        groupingWorkflows.registerIpAndAttachLicenseAndAddToGroup({
            nftContract: address(mockNft),
            tokenId: 0,
            groupId: groupId,
            maxAllowedRewardShare: 100e6, // 100%
            licensesData: new WorkflowStructs.LicenseData[](0),
            ipMetadata: ipMetadataDefault,
            sigMetadataAndAttachAndConfig: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: block.timestamp + 1000,
                signature: new bytes(0)
            }),
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: block.timestamp + 1000,
                signature: new bytes(0)
            })
        });
    }

    function test_GroupingWorkflows_mintAndRegisterIpAndAttachLicenseAndAddToGroup_withRegistrationFee() public {
        uint96 registrationFee = 1 ether;
        address treasury = address(0x12345);

        vm.prank(u.admin);
        ipAssetRegistry.setRegistrationFee(treasury, address(mockToken), registrationFee);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigAddToGroup, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: groupId,
            to: address(groupingWorkflows),
            module: address(groupingModule),
            selector: IGroupingModule.addIp.selector,
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            signerSk: groupOwnerSk
        });

        vm.startPrank(groupOwner);
        mockToken.mint(groupOwner, spgNftPublic.mintFee() + registrationFee);
        mockToken.approve(address(spgNftPublic), spgNftPublic.mintFee());
        mockToken.approve(address(groupingWorkflows), registrationFee);

        uint256 treasuryBalanceBefore = mockToken.balanceOf(treasury);
        uint256 groupOwnerBalanceBefore = mockToken.balanceOf(groupOwner);
        groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup({
            spgNftContract: address(spgNftPublic),
            groupId: groupId,
            recipient: groupOwner,
            maxAllowedRewardShare: 100e6, // 100%
            ipMetadata: ipMetadataDefault,
            licensesData: testLicensesData,
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: deadline,
                signature: sigAddToGroup
            }),
            allowDuplicates: true
        });
        vm.stopPrank();

        assertEq(mockToken.balanceOf(treasury), treasuryBalanceBefore + registrationFee);
        assertEq(mockToken.balanceOf(groupOwner), groupOwnerBalanceBefore - registrationFee - spgNftPublic.mintFee());
    }

    function test_GroupingWorkflows_registerIpAndAttachLicenseAndAddToGroup_withRegistrationFee() public {
        uint96 registrationFee = 1 ether;
        address treasury = address(0x12345);

        vm.prank(u.admin);
        ipAssetRegistry.setRegistrationFee(treasury, address(mockToken), registrationFee);

        vm.startPrank(groupOwner);
        uint256 tokenId = MockERC721(mockNft).mint(groupOwner);
        vm.stopPrank();
        address expectedIpId = IIPAssetRegistry(ipAssetRegistry).ipId(block.chainid, address(mockNft), tokenId);

        (bytes memory sigMetadataAndAttachAndConfig, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: expectedIpId,
            permissionList: _getMetadataAndAttachTermsAndConfigPermissionList(expectedIpId, address(groupingWorkflows)),
            deadline: block.timestamp + 1000,
            state: bytes32(0),
            signerSk: groupOwnerSk
        });

        (bytes memory sigAddToGroup, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: groupId,
            to: address(groupingWorkflows),
            module: address(groupingModule),
            selector: IGroupingModule.addIp.selector,
            deadline: block.timestamp + 1000,
            state: IIPAccount(payable(groupId)).state(),
            signerSk: groupOwnerSk
        });

        vm.startPrank(groupOwner);
        mockToken.mint(groupOwner, registrationFee);
        mockToken.approve(address(groupingWorkflows), registrationFee);

        uint256 treasuryBalanceBefore = mockToken.balanceOf(treasury);
        uint256 groupOwnerBalanceBefore = mockToken.balanceOf(groupOwner);

        groupingWorkflows.registerIpAndAttachLicenseAndAddToGroup({
            nftContract: address(mockNft),
            tokenId: tokenId,
            groupId: groupId,
            maxAllowedRewardShare: 100e6, // 100%
            licensesData: testLicensesData,
            ipMetadata: ipMetadataDefault,
            sigMetadataAndAttachAndConfig: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: block.timestamp + 1000,
                signature: sigMetadataAndAttachAndConfig
            }),
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: block.timestamp + 1000,
                signature: sigAddToGroup
            })
        });
        vm.stopPrank();

        assertEq(mockToken.balanceOf(treasury), treasuryBalanceBefore + registrationFee);
        assertEq(mockToken.balanceOf(groupOwner), groupOwnerBalanceBefore - registrationFee);
    }

    function test_GroupingWorkflows_registerGroupAndAttachLicense_withRegistrationFee() public {
        uint96 registrationFee = 1 ether;
        address treasury = address(0x12345);

        vm.prank(u.admin);
        ipAssetRegistry.setRegistrationFee(treasury, address(mockToken), registrationFee);

        vm.startPrank(groupOwner);
        mockToken.mint(groupOwner, registrationFee);
        mockToken.approve(address(groupingWorkflows), registrationFee);

        uint256 treasuryBalanceBefore = mockToken.balanceOf(treasury);
        uint256 groupOwnerBalanceBefore = mockToken.balanceOf(groupOwner);

        address newGroupId = groupingWorkflows.registerGroupAndAttachLicense({
            groupPool: address(evenSplitGroupPool),
            licenseData: testGroupLicenseData[0]
        });
        vm.stopPrank();

        assertEq(mockToken.balanceOf(treasury), treasuryBalanceBefore + registrationFee);
        assertEq(mockToken.balanceOf(groupOwner), groupOwnerBalanceBefore - registrationFee);
    }

    function test_GroupingWorkflows_registerGroupAndAttachLicenseAndAddIps_withRegistrationFee() public {
        uint96 registrationFee = 1 ether;
        address treasury = address(0x12345);

        vm.prank(u.admin);
        ipAssetRegistry.setRegistrationFee(treasury, address(mockToken), registrationFee);

        vm.startPrank(groupOwner);
        mockToken.mint(groupOwner, registrationFee);
        mockToken.approve(address(groupingWorkflows), registrationFee);

        uint256 treasuryBalanceBefore = mockToken.balanceOf(treasury);
        uint256 groupOwnerBalanceBefore = mockToken.balanceOf(groupOwner);

        groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: address(evenSplitGroupPool),
            ipIds: ipIds,
            maxAllowedRewardShare: 100e6, // 100%
            licenseData: testGroupLicenseData[0]
        });
        vm.stopPrank();

        assertEq(mockToken.balanceOf(treasury), treasuryBalanceBefore + registrationFee);
        assertEq(mockToken.balanceOf(groupOwner), groupOwnerBalanceBefore - registrationFee);
    }

    // setup a group IPA for testing
    function _setupGroup() internal {
        // register a group and attach default PIL terms to it
        vm.startPrank(groupOwner);
        groupId = IGroupingModule(groupingModule).registerGroup(address(evenSplitGroupPool));
        vm.label(groupId, "Group1");
        LicensingHelper.attachLicenseTermsAndSetConfigs(
            groupId,
            address(licensingModule),
            testGroupLicenseData[0].licenseTemplate,
            testGroupLicenseData[0].licenseTermsId,
            testGroupLicenseData[0].licensingConfig
        );
        vm.stopPrank();
    }

    // setup individual IPs for testing
    function _setupIPs() internal {
        // mint and approve tokens for minting
        vm.startPrank(groupOwner);
        MockERC20(mockToken).mint(groupOwner, 1000 * 10 * 10 ** MockERC20(mockToken).decimals());
        MockERC20(mockToken).approve(address(spgNftPublic), 1000 * 10 * 10 ** MockERC20(mockToken).decimals());
        vm.stopPrank();

        // setup call data for batch calling `mintAndRegisterIp` to create 10 IPs
        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                bytes4(keccak256("mintAndRegisterIp(address,address,(string,bytes32,string,bytes32),bool)")),
                address(spgNftPublic),
                groupOwner,
                ipMetadataDefault,
                true
            );
        }

        // batch call `mintAndRegisterIp`
        vm.startPrank(groupOwner);
        bytes[] memory results = registrationWorkflows.multicall(data);
        vm.stopPrank();

        // decode the multicall results to get the IP IDs
        ipIds = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            (ipIds[i], ) = abi.decode(results[i], (address, uint256));
        }

        // attach license terms to the IPs
        vm.startPrank(groupOwner);
        for (uint256 i = 0; i < 10; i++) {
            LicensingHelper.attachLicenseTermsAndSetConfigs(
                ipIds[i],
                address(licensingModule),
                testLicensesData[0].licenseTemplate,
                testLicensesData[0].licenseTermsId,
                testLicensesData[0].licensingConfig
            );
        }
        vm.stopPrank();
    }
}
