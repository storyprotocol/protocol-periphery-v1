//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

// contracts
import { Errors } from "../../contracts/lib/Errors.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";
// test
import { BaseTest } from "../utils/BaseTest.t.sol";

contract LicenseAttachmentWorkflowsTest is BaseTest {
    using Strings for uint256;

    struct IPAsset {
        address payable ipId;
        uint256 tokenId;
        address owner;
    }

    mapping(uint256 index => IPAsset) internal ipAsset;

    WorkflowStructs.LicenseTermsData[] internal commTermsData;

    function setUp() public override {
        super.setUp();
        _setUpLicenseTermsData();
    }

    modifier withIp(address owner) {
        vm.startPrank(owner);
        mockToken.mint(address(owner), 100 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 100 * 10 ** mockToken.decimals());
        (address ipId, uint256 tokenId) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(nftContract),
            recipient: owner,
            ipMetadata: ipMetadataDefault,
            allowDuplicates: true
        });
        ipAsset[1] = IPAsset({ ipId: payable(ipId), tokenId: tokenId, owner: owner });
        vm.stopPrank();
        _;
    }

    function test_LicenseAttachmentWorkflows_revert_DuplicatedNFTMetadataHash()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            licenseTermsData: commTermsData,
            allowDuplicates: true
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SPGNFT__DuplicatedNFTMetadataHash.selector,
                address(nftContract),
                1,
                ipMetadataDefault.nftMetadataHash
            )
        );
        licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            licenseTermsData: commTermsData,
            allowDuplicates: false
        });
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach() public withCollection withIp(u.alice) {
        address payable ipId = ipAsset[1].ipId;
        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getAttachTermsAndConfigPermissionList(ipId, address(licenseAttachmentWorkflows)),
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        uint256 ltAmt = pilTemplate.totalRegisteredLicenseTerms();

        uint256[] memory licenseTermsIds = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signature
            })
        });
        _assertAttachedLicenseTerms(ipId, licenseTermsIds);
    }

    function test_LicenseAttachmentWorkflows_mintAndRegisterIpAndAttachPILTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipId1, uint256 tokenId1, uint256[] memory licenseTermsIds1) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataEmpty,
                licenseTermsData: commTermsData,
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(tokenId1, 1);
        assertEq(nftContract.tokenURI(tokenId1), string.concat(testBaseURI, tokenId1.toString()));
        assertMetadata(ipId1, ipMetadataEmpty);
        _assertAttachedLicenseTerms(ipId1, licenseTermsIds1);

        (address ipId2, uint256 tokenId2, uint256[] memory licenseTermsIds2) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                licenseTermsData: commTermsData,
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(tokenId2, 2);
        assertEq(nftContract.tokenURI(tokenId2), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipId2, ipMetadataDefault);
        _assertAttachedLicenseTerms(ipId2, licenseTermsIds2);
    }

    function test_LicenseAttachmentWorkflows_registerIpAndAttachPILTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        uint256 tokenId = nftContract.mint({
            to: caller,
            nftMetadataURI: ipMetadataEmpty.nftMetadataURI,
            nftMetadataHash: ipMetadataEmpty.nftMetadataHash,
            allowDuplicates: true
        });
        address payable ipId = payable(ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenId));

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadataAndAttachAndConfig, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getMetadataAndAttachTermsAndConfigPermissionList(
                ipId,
                address(licenseAttachmentWorkflows)
            ),
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        (, uint256[] memory licenseTermsIds) = licenseAttachmentWorkflows.registerIpAndAttachPILTerms({
            nftContract: address(nftContract),
            tokenId: tokenId,
            ipMetadata: ipMetadataDefault,
            licenseTermsData: commTermsData,
            sigMetadataAndAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: sigMetadataAndAttachAndConfig
            })
        });

        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertMetadata(ipId, ipMetadataDefault);
        _assertAttachedLicenseTerms(ipId, licenseTermsIds);
    }

    function test_LicenseAttachmentWorkflows_registerPILTermsAndAttach_idempotency()
        public
        withCollection
        withIp(u.alice)
    {
        address payable ipId = ipAsset[1].ipId;
        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature1, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getAttachTermsAndConfigPermissionList(ipId, address(licenseAttachmentWorkflows)),
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        uint256[] memory licenseTermsIds1 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signature1
            })
        });

        (bytes memory signature2, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipId,
            permissionList: _getAttachTermsAndConfigPermissionList(ipId, address(licenseAttachmentWorkflows)),
            deadline: deadline,
            state: IIPAccount(ipId).state(),
            signerSk: sk.alice
        });

        // attach the same license terms to the IP again, but it shouldn't revert
        uint256[] memory licenseTermsIds2 = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signature2
            })
        });

        for (uint256 i = 0; i < licenseTermsIds1.length; i++) {
            assertEq(licenseTermsIds1[i], licenseTermsIds2[i]);
        }
    }

    function test_revert_registerPILTermsAndAttach_DerivativesCannotAddLicenseTerms()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(licenseAttachmentWorkflows))
    {
        (address ipIdParent, , uint256[] memory licenseTermsIdsParent) = licenseAttachmentWorkflows
            .mintAndRegisterIpAndAttachPILTerms({
                spgNftContract: address(nftContract),
                recipient: caller,
                ipMetadata: ipMetadataDefault,
                licenseTermsData: commTermsData,
                allowDuplicates: true
            });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdsParent[3];

        mockToken.mint(address(caller), 100 * 10 ** mockToken.decimals());
        mockToken.approve(address(derivativeWorkflows), 100 * 10 ** mockToken.decimals());
        (address ipIdChild, ) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: 0 // non-commercial remixing does not require royalty tokens
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller,
            allowDuplicates: true
        });

        uint256 deadline = block.timestamp + 1000;

        (bytes memory signature, , ) = _getSetBatchPermissionSigForPeriphery({
            ipId: ipIdChild,
            permissionList: _getAttachTermsAndConfigPermissionList(ipIdChild, address(licenseAttachmentWorkflows)),
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        // attach a different license terms to the child ip, should revert with the correct error
        vm.expectRevert(CoreErrors.LicensingModule__DerivativesCannotAddLicenseTerms.selector);
        licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipIdChild,
            licenseTermsData: commTermsData,
            sigAttachAndConfig: WorkflowStructs.SignatureData({
                signer: u.alice,
                deadline: deadline,
                signature: signature
            })
        });
    }

    function _assertAttachedLicenseTerms(address ipId, uint256[] memory licenseTermsIds) internal {
        for (uint256 i = 0; i < commTermsData.length; i++) {
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, i);
            assertEq(licenseTemplate, address(pilTemplate));
            assertEq(licenseTermsId, licenseTermsIds[i]);
            assertEq(pilTemplate.getLicenseTermsId(commTermsData[i].terms), licenseTermsIds[i]);
        }
    }

    function _setUpLicenseTermsData() internal {
        uint256 testMintFee = 100 * 10 ** mockToken.decimals();

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialUse({
                    mintingFee: testMintFee,
                    currencyToken: address(mockToken),
                    royaltyPolicy: address(royaltyPolicyLAP)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 0,
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(evenSplitGroupPool)
                })
            })
        );

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialUse({
                    mintingFee: testMintFee,
                    currencyToken: address(mockToken),
                    royaltyPolicy: address(royaltyPolicyLRP)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: false,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 0,
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(evenSplitGroupPool)
                })
            })
        );

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: testMintFee,
                    commercialRevShare: 5_000_000, // 5%
                    royaltyPolicy: address(royaltyPolicyLRP),
                    currencyToken: address(mockToken)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 5_000_000, // 5%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(evenSplitGroupPool)
                })
            })
        );

        commTermsData.push(
            WorkflowStructs.LicenseTermsData({
                terms: PILFlavors.commercialRemix({
                    mintingFee: testMintFee,
                    commercialRevShare: 8_000_000, // 8%
                    royaltyPolicy: address(royaltyPolicyLAP),
                    currencyToken: address(mockToken)
                }),
                licensingConfig: Licensing.LicensingConfig({
                    isSet: true,
                    mintingFee: testMintFee,
                    licensingHook: address(0),
                    hookData: "",
                    commercialRevShare: 8_000_000, // 8%
                    disabled: false,
                    expectMinimumGroupRewardShare: 0,
                    expectGroupRewardPool: address(evenSplitGroupPool)
                })
            })
        );
    }
}
