//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IGroupIPAssetRegistry.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

// contracts
import { Errors } from "../../contracts/lib/Errors.sol";
import { LicensingHelper } from "../../contracts/lib/LicensingHelper.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// test
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockERC721 } from "../mocks/MockERC721.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";

contract GroupingWorkflowsTest is BaseTest {
    using Strings for uint256;

    WorkflowStructs.LicenseInfo[] internal testLicenseInfo;
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

        // setup license terms
        _setupLicenseTerms();

        // setup a group IPA
        _setupGroup();

        // setup individual IPs
        _setupIPs();
    }

    function test_GroupingWorkflows_revert_DuplicatedNFTMetadataHash() public {
        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigAddToGroup, ) = _getSigForExecuteWithSig({
            ipId: groupId,
            to: address(accessController),
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            data: abi.encodeWithSelector(
                IAccessController.setPermission.selector,
                groupId,
                address(groupingWorkflows),
                address(groupingModule),
                IGroupingModule.addIp.selector,
                AccessPermission.ALLOW
            ),
            signerSk: groupOwnerSk
        });

        vm.startPrank(minter);
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
            recipient: minter,
            ipMetadata: ipMetadataDefault,
            licenseInfo: testLicenseInfo,
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
        (bytes memory sigAddToGroup, bytes32 expectedState) = _getSigForExecuteWithSig({
            ipId: groupId,
            to: address(accessController),
            deadline: deadline,
            state: IIPAccount(payable(groupId)).state(),
            data: abi.encodeWithSelector(
                IAccessController.setPermission.selector,
                groupId,
                address(groupingWorkflows),
                address(groupingModule),
                IGroupingModule.addIp.selector,
                AccessPermission.ALLOW
            ),
            signerSk: groupOwnerSk
        });

        vm.startPrank(minter);
        (address ipId, uint256 tokenId) = groupingWorkflows.mintAndRegisterIpAndAttachLicenseAndAddToGroup({
            spgNftContract: address(spgNftPublic),
            groupId: groupId,
            recipient: minter,
            ipMetadata: ipMetadataDefault,
            licenseInfo: testLicenseInfo,
            sigAddToGroup: WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: deadline,
                signature: sigAddToGroup
            }),
            allowDuplicates: true
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
        for (uint256 i = 0; i < testLicenseInfo.length; i++) {
            (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(address(licenseRegistry))
                .getAttachedLicenseTerms(ipId, i);
            assertEq(licenseTemplate, testLicenseInfo[i].licenseTemplate);
            assertEq(licenseTermsId, testLicenseInfo[i].licenseTermsId);
        }
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

        WorkflowStructs.SignatureData memory sigMetadataData;
        WorkflowStructs.SignatureData[] memory sigsAttachData = new WorkflowStructs.SignatureData[](
            testLicenseInfo.length
        );
        WorkflowStructs.SignatureData memory sigAddToGroupData;

        {
            // Get the signature for executing `setAll` function in `CoreMetadataModule` on behalf of the IP owner
            (bytes memory sigMetadata, bytes32 expectedState) = _getSigForExecuteWithSig({
                ipId: expectedIpId,
                to: coreMetadataModuleAddr,
                deadline: deadline,
                state: bytes32(0),
                data: abi.encodeWithSelector(
                    ICoreMetadataModule.setAll.selector,
                    expectedIpId,
                    ipMetadataDefault.ipMetadataURI,
                    ipMetadataDefault.ipMetadataHash,
                    ipMetadataDefault.nftMetadataHash
                ),
                signerSk: minterSk
            });
            sigMetadataData = WorkflowStructs.SignatureData({
                signer: minter,
                deadline: deadline,
                signature: sigMetadata
            });

            // Get the signature for executing `attachLicenseTerms` function in `LicensingModule` on behalf of the IP owner
            bytes[] memory sigsAttach = new bytes[](testLicenseInfo.length);
            for (uint256 i = 0; i < testLicenseInfo.length; i++) {
                (sigsAttach[i], expectedState) = _getSigForExecuteWithSig({
                    ipId: expectedIpId,
                    to: licensingModuleAddr,
                    deadline: deadline,
                    state: expectedState,
                    data: abi.encodeWithSelector(
                        ILicensingModule.attachLicenseTerms.selector,
                        expectedIpId,
                        testLicenseInfo[i].licenseTemplate,
                        testLicenseInfo[i].licenseTermsId
                    ),
                    signerSk: minterSk
                });
                sigsAttachData[i] = WorkflowStructs.SignatureData({
                    signer: minter,
                    deadline: deadline,
                    signature: sigsAttach[i]
                });
            }

            address[] memory expectedIpIds = new address[](1);
            expectedIpIds[0] = expectedIpId;
            // Get the signature for executing `addIp` function in `GroupingModule` on behalf of the Group IP owner
            (bytes memory sigAddToGroup, ) = _getSigForExecuteWithSig({
                ipId: groupId,
                to: address(groupingModule),
                deadline: deadline,
                state: IIPAccount(payable(groupId)).state(),
                data: abi.encodeWithSelector(IGroupingModule.addIp.selector, groupId, expectedIpIds),
                signerSk: groupOwnerSk
            });
            sigAddToGroupData = WorkflowStructs.SignatureData({
                signer: groupOwner,
                deadline: deadline,
                signature: sigAddToGroup
            });
        }

        address ipId = groupingWorkflows.registerIpAndAttachLicenseAndAddToGroup({
            nftContract: address(mockNft),
            tokenId: tokenId,
            groupId: groupId,
            licenseInfo: testLicenseInfo,
            ipMetadata: ipMetadataDefault,
            sigMetadata: sigMetadataData,
            sigsAttach: sigsAttachData,
            sigAddToGroup: sigAddToGroupData
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
        for (uint256 i = 0; i < testLicenseInfo.length; i++) {
            (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistry)
                .getAttachedLicenseTerms(ipId, i);
            assertEq(licenseTemplate, testLicenseInfo[i].licenseTemplate);
            assertEq(licenseTermsId, testLicenseInfo[i].licenseTermsId);
        }
    }

    // Register group IP → Attach license terms to group IPA
    function test_GroupingWorkflows_registerGroupAndAttachLicense() public {
        vm.startPrank(groupOwner);
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicense({
            groupPool: address(evenSplitGroupPool),
            licenseInfo: testLicenseInfo[0]
        });
        vm.stopPrank();

        // check the group IPA is registered
        assertTrue(IGroupIPAssetRegistry(ipAssetRegistry).isRegisteredGroup(newGroupId));

        // check the license terms is correctly attached to the group IPA
        (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistry).getAttachedLicenseTerms(
            newGroupId,
            0
        );
        assertEq(licenseTemplate, testLicenseInfo[0].licenseTemplate);
        assertEq(licenseTermsId, testLicenseInfo[0].licenseTermsId);
    }

    // Register group IP → Attach license terms to group IPA → Add existing IPs to the new group IPA
    function test_GroupingWorkflows_registerGroupAndAttachLicenseAndAddIps() public {
        vm.startPrank(groupOwner);
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: address(evenSplitGroupPool),
            ipIds: ipIds,
            licenseInfo: testLicenseInfo[0]
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
        assertEq(licenseTemplate, testLicenseInfo[0].licenseTemplate);
        assertEq(licenseTermsId, testLicenseInfo[0].licenseTermsId);
    }

    // Collect royalties for the entire group and distribute to each member IP's royalty vault
    function test_GroupingWorkflows_collectRoyaltiesAndClaimReward() public {
        address ipOwner1 = u.bob;
        address ipOwner2 = u.carl;

        vm.startPrank(groupOwner);
        address newGroupId = groupingWorkflows.registerGroupAndAttachLicenseAndAddIps({
            groupPool: address(evenSplitGroupPool),
            ipIds: ipIds,
            licenseInfo: testLicenseInfo[0]
        });
        vm.stopPrank();

        assertEq(ipAssetRegistry.totalMembers(newGroupId), 10);
        assertEq(evenSplitGroupPool.getTotalIps(newGroupId), 10);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = newGroupId;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = testLicenseInfo[0].licenseTermsId;

        vm.startPrank(ipOwner1);
        // approve nft minting fee
        mockToken.mint(ipOwner1, 1 * 10 ** mockToken.decimals());
        mockToken.approve(address(spgNftPublic), 1 * 10 ** mockToken.decimals());

        (address ipId1, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(spgNftPublic),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTermsIds: licenseTermsIds,
                licenseTemplate: testLicenseInfo[0].licenseTemplate,
                royaltyContext: "",
                maxMintingFee: 0
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
                licenseTemplate: testLicenseInfo[0].licenseTemplate,
                royaltyContext: "",
                maxMintingFee: 0
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
        royaltyPolicyLAP.transferToVault(
            ipId1,
            newGroupId,
            address(mockToken),
            (amount1 * revShare) / royaltyModule.maxPercent()
        );
        vm.stopPrank();

        uint256 amount2 = 10_000 * 10 ** mockToken.decimals(); // 10,000 tokens
        mockToken.mint(ipOwner2, amount2);
        vm.startPrank(ipOwner2);
        mockToken.approve(address(royaltyModule), amount2);
        royaltyModule.payRoyaltyOnBehalf(ipId2, ipOwner2, address(mockToken), amount2);
        royaltyPolicyLAP.transferToVault(
            ipId2,
            newGroupId,
            address(mockToken),
            (amount2 * revShare) / royaltyModule.maxPercent()
        );
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
            (sigsAddToGroup[i], expectedStates) = _getSigForExecuteWithSig({
                ipId: groupId,
                to: address(accessController),
                deadline: deadline,
                state: expectedStates,
                data: abi.encodeWithSelector(
                    IAccessController.setPermission.selector,
                    groupId,
                    address(groupingWorkflows),
                    address(groupingModule),
                    IGroupingModule.addIp.selector,
                    AccessPermission.ALLOW
                ),
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
                testLicenseInfo,
                ipMetadataDefault,
                WorkflowStructs.SignatureData({ signer: groupOwner, deadline: deadline, signature: sigsAddToGroup[i] }),
                true
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
            for (uint256 j = 0; j < testLicenseInfo.length; j++) {
                (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistry)
                    .getAttachedLicenseTerms(ipId, j);
                assertEq(licenseTemplate, testLicenseInfo[j].licenseTemplate);
                assertEq(licenseTermsId, testLicenseInfo[j].licenseTermsId);
            }
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

        WorkflowStructs.SignatureData[] memory sigMetadataData = new WorkflowStructs.SignatureData[](10);
        WorkflowStructs.SignatureData[] memory sigAddToGroupData = new WorkflowStructs.SignatureData[](10);
        WorkflowStructs.SignatureData[][] memory sigAttachData = new WorkflowStructs.SignatureData[][](10);
        for (uint256 i = 0; i < 10; i++) {
            sigAttachData[i] = new WorkflowStructs.SignatureData[](testLicenseInfo.length);
        }

        {
            uint256 deadline = block.timestamp + 1000;
            // Get the signatures for setting the permission for calling `setAll` (IP metadata) and `attachLicenseTerms`
            // functions in `coreMetadataModule` and `licensingModule` from the IP owner
            bytes memory sigsMetadata;
            bytes[] memory sigsAttach = new bytes[](testLicenseInfo.length);
            for (uint256 i = 0; i < 10; i++) {
                bytes32 expectedState = bytes32(0);
                (sigsMetadata, expectedState) = _getSigForExecuteWithSig({
                    ipId: expectedIpIds[i],
                    to: address(coreMetadataModule),
                    deadline: deadline,
                    state: expectedState,
                    data: abi.encodeWithSelector(
                        ICoreMetadataModule.setAll.selector,
                        expectedIpIds[i],
                        ipMetadataDefault.ipMetadataURI,
                        ipMetadataDefault.ipMetadataHash,
                        ipMetadataDefault.nftMetadataHash
                    ),
                    signerSk: minterSk
                });
                sigMetadataData[i] = WorkflowStructs.SignatureData({
                    signer: minter,
                    deadline: deadline,
                    signature: sigsMetadata
                });

                for (uint256 j = 0; j < testLicenseInfo.length; j++) {
                    (sigsAttach[j], expectedState) = _getSigForExecuteWithSig({
                        ipId: expectedIpIds[i],
                        to: address(licensingModule),
                        deadline: deadline,
                        state: expectedState,
                        data: abi.encodeWithSelector(
                            ILicensingModule.attachLicenseTerms.selector,
                            expectedIpIds[i],
                            testLicenseInfo[j].licenseTemplate,
                            testLicenseInfo[j].licenseTermsId
                        ),
                        signerSk: minterSk
                    });

                    sigAttachData[i][j] = WorkflowStructs.SignatureData({
                        signer: minter,
                        deadline: deadline,
                        signature: sigsAttach[j]
                    });
                }
            }

            // Get the signatures for setting the permission for calling `addIp` function in `GroupingModule`
            // from the Group IP owner
            bytes memory sigsAddToGroup;
            bytes memory data;
            bytes32 expectedState = IIPAccount(payable(groupId)).state();
            address[] memory ipIdArr = new address[](1);
            for (uint256 i = 0; i < 10; i++) {
                ipIdArr[0] = expectedIpIds[i];
                data = abi.encodeWithSelector(IGroupingModule.addIp.selector, groupId, ipIdArr);
                (sigsAddToGroup, expectedState) = _getSigForExecuteWithSig({
                    ipId: groupId,
                    to: address(groupingModule),
                    deadline: deadline,
                    state: expectedState,
                    data: data,
                    signerSk: groupOwnerSk
                });

                sigAddToGroupData[i] = WorkflowStructs.SignatureData({
                    signer: groupOwner,
                    deadline: deadline,
                    signature: sigsAddToGroup
                });
            }
        }

        // setup call data for batch calling 10 `registerIpAndAttachLicenseAndAddToGroup`
        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                groupingWorkflows.registerIpAndAttachLicenseAndAddToGroup.selector,
                mockNft,
                tokenIds[i],
                groupId,
                testLicenseInfo,
                ipMetadataDefault,
                sigMetadataData[i],
                sigAttachData[i],
                sigAddToGroupData[i]
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
            for (uint256 j = 0; j < testLicenseInfo.length; j++) {
                (address licenseTemplate, uint256 licenseTermsId) = ILicenseRegistry(licenseRegistry)
                    .getAttachedLicenseTerms(ipId, j);
                assertEq(licenseTemplate, testLicenseInfo[j].licenseTemplate);
                assertEq(licenseTermsId, testLicenseInfo[j].licenseTermsId);
            }
        }
    }

    // setup license terms for testing
    function _setupLicenseTerms() internal {
        revShare = 10 * 10 ** 6; // 10%

        testLicenseInfo.push(
            WorkflowStructs.LicenseInfo({
                licenseTemplate: pilTemplateAddr,
                licenseTermsId: pilTemplate.registerLicenseTerms(
                    // minting fee is set to 0 beacause currently core protocol requires group IP's minting fee to be 0
                    PILFlavors.commercialRemix({
                        mintingFee: 0,
                        commercialRevShare: revShare,
                        royaltyPolicy: address(royaltyPolicyLAP),
                        currencyToken: address(mockToken)
                    })
                )
            })
        );

        testLicenseInfo.push(
            WorkflowStructs.LicenseInfo({
                licenseTemplate: pilTemplateAddr,
                licenseTermsId: pilTemplate.registerLicenseTerms(
                    // Another license that will not be associated with the group IP
                    PILFlavors.commercialRemix({
                        mintingFee: 10 * 10 ** mockToken.decimals(), // 10 tokens
                        commercialRevShare: revShare,
                        royaltyPolicy: address(royaltyPolicyLAP),
                        currencyToken: address(mockToken)
                    })
                )
            })
        );
    }

    // setup a group IPA for testing
    function _setupGroup() internal {
        // register a group and attach default PIL terms to it
        vm.startPrank(groupOwner);
        groupId = IGroupingModule(groupingModule).registerGroup(address(evenSplitGroupPool));
        vm.label(groupId, "Group1");
        LicensingHelper.attachLicenseTerms(
            groupId,
            address(licensingModule),
            testLicenseInfo[0].licenseTemplate,
            testLicenseInfo[0].licenseTermsId
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
                ipMetadataDefault,
                true
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
            for (uint256 j = 0; j < testLicenseInfo.length; j++) {
                LicensingHelper.attachLicenseTerms(
                    ipIds[i],
                    address(licensingModule),
                    testLicenseInfo[j].licenseTemplate,
                    testLicenseInfo[j].licenseTermsId
                );
            }
        }
        vm.stopPrank();
    }
}
