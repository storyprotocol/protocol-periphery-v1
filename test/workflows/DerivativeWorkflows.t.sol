//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

// contracts
import { Errors } from "../../contracts/lib/Errors.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";

contract DerivativeWorkflowsTest is BaseTest {
    using Strings for uint256;

    address internal ipIdParent;

    function setUp() public override {
        super.setUp();
    }

    modifier withNonCommercialParentIp() {
        PILTerms[] memory terms = new PILTerms[](1);
        terms[0] = PILFlavors.nonCommercialSocialRemixing();
        (ipIdParent, , ) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            terms: terms,
            allowDuplicates: true
        });
        _;
    }

    modifier withCommercialParentIp() {
        PILTerms[] memory terms = new PILTerms[](1);
        terms[0] = PILFlavors.commercialRemix({
            mintingFee: 100 * 10 ** mockToken.decimals(),
            commercialRevShare: 10 * 10 ** 6, // 10%
            royaltyPolicy: address(royaltyPolicyLAP),
            currencyToken: address(mockToken)
        });
        (ipIdParent, , ) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            terms: terms,
            allowDuplicates: true
        });
        _;
    }

    function test_DerivativeWorkflows_revert_DuplicatedNFTMetadataHash()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        // First, create an derivative with the same NFT metadata hash but with dedup turned off
        (, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(ipIdParent, 0);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller,
            allowDuplicates: true
        });

        // Now attempt to create another derivative with the same NFT metadata hash but with dedup turned on
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SPGNFT__DuplicatedNFTMetadataHash.selector,
                address(nftContract),
                1,
                ipMetadataDefault.nftMetadataHash
            )
        );
        derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller,
            allowDuplicates: false
        });
    }

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivative_withNonCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        _mintAndRegisterIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_registerIpAndMakeDerivative_withNonCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        _registerIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivative_withCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withCommercialParentIp
    {
        _mintAndRegisterIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_registerIpAndMakeDerivative_withCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withCommercialParentIp
    {
        _registerIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivativeWithLicenseTokens()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint256 startLicenseTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipIdParent,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: licenseTermsIdParent,
            amount: 1,
            receiver: caller,
            royaltyContext: "",
            maxMintingFee: 0
        });

        // Need so that derivative workflows can transfer the license tokens
        licenseToken.setApprovalForAll(address(derivativeWorkflows), true);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        (address ipIdChild, uint256 tokenIdChild) = derivativeWorkflows
            .mintAndRegisterIpAndMakeDerivativeWithLicenseTokens({
                spgNftContract: address(nftContract),
                licenseTokenIds: licenseTokenIds,
                royaltyContext: "",
                ipMetadata: ipMetadataDefault,
                recipient: caller,
                allowDuplicates: true
            });
        assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
        assertEq(tokenIdChild, 2);
        assertEq(nftContract.tokenURI(tokenIdChild), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipIdChild, ipMetadataDefault);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);
        assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);

        assertParentChild({
            parentIpId: ipIdParent,
            childIpId: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_DerivativeWorkflows_registerIpAndMakeDerivativeWithLicenseTokens()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint256 tokenIdChild = nftContract.mint({
            to: caller,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: true
        });
        address ipIdChild = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild);

        uint256 deadline = block.timestamp + 1000;

        uint256 startLicenseTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipIdParent,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: licenseTermsIdParent,
            amount: 1,
            receiver: caller,
            royaltyContext: "",
            maxMintingFee: 0
        });

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;
        licenseToken.approve(address(derivativeWorkflows), startLicenseTokenId);

        (bytes memory sigMetadata, bytes32 expectedState) = _getSigForExecuteWithSig({
            ipId: ipIdChild,
            to: address(coreMetadataModule),
            deadline: deadline,
            state: bytes32(0),
            data: abi.encodeWithSelector(
                ICoreMetadataModule.setAll.selector,
                ipIdChild,
                ipMetadataDefault.ipMetadataURI,
                ipMetadataDefault.ipMetadataHash,
                ipMetadataDefault.nftMetadataHash
            ),
            signerSk: sk.alice
        });
        (bytes memory sigRegister, ) = _getSigForExecuteWithSig({
            ipId: ipIdChild,
            to: address(licensingModule),
            deadline: deadline,
            state: expectedState,
            data: abi.encodeWithSelector(
                ILicensingModule.registerDerivativeWithLicenseTokens.selector,
                ipIdChild,
                licenseTokenIds,
                ""
            ),
            signerSk: sk.alice
        });

        address ipIdChildActual = derivativeWorkflows.registerIpAndMakeDerivativeWithLicenseTokens({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            ipMetadata: ipMetadataDefault,
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigMetadata }),
            sigRegister: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigRegister })
        });
        assertEq(ipIdChildActual, ipIdChild);
        assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
        assertMetadata(ipIdChild, ipMetadataDefault);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);

        assertParentChild({
            parentIpId: ipIdParent,
            childIpId: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_SPG_multicall_mintAndRegisterIpAndMakeDerivative()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withNonCommercialParentIp
    {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );
        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                derivativeWorkflows.mintAndRegisterIpAndMakeDerivative.selector,
                address(nftContract),
                WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: licenseTermsIds,
                    royaltyContext: "",
                    maxMintingFee: 0
                }),
                ipMetadataDefault,
                caller,
                true
            );
        }

        bytes[] memory results = derivativeWorkflows.multicall(data);

        for (uint256 i = 0; i < 10; i++) {
            (address ipIdChild, uint256 tokenIdChild) = abi.decode(results[i], (address, uint256));
            assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
            assertEq(tokenIdChild, i + 2);
            assertEq(nftContract.tokenURI(tokenIdChild), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
            assertMetadata(ipIdChild, ipMetadataDefault);
            (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
                ipIdChild,
                0
            );
            assertEq(licenseTemplateChild, licenseTemplateParent);
            assertEq(licenseTermsIdChild, licenseTermsIdParent);
            assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);
            assertParentChild({
                parentIpId: ipIdParent,
                childIpId: ipIdChild,
                expectedParentCount: 1,
                expectedParentIndex: 0
            });
        }
    }

    function _mintAndRegisterIpAndMakeDerivativeBaseTest() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        (address ipIdChild, uint256 tokenIdChild) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller,
            allowDuplicates: true
        });
        assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
        assertEq(tokenIdChild, 2);
        assertEq(nftContract.tokenURI(tokenIdChild), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipIdChild, ipMetadataDefault);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);
        assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);

        assertParentChild({
            parentIpId: ipIdParent,
            childIpId: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function _registerIpAndMakeDerivativeBaseTest() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint256 tokenIdChild = nftContract.mint({
            to: caller,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: true
        });
        address ipIdChild = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild);

        uint256 deadline = block.timestamp + 1000;

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseTermsIdParent;

        WorkflowStructs.SignatureData memory sigMetadataData;
        WorkflowStructs.SignatureData memory sigMintingFeeData;
        WorkflowStructs.SignatureData memory sigRegisterData;

        {
            bytes32 expectedState;
            {
                bytes memory sigMetadata;
                (sigMetadata, expectedState) = _getSigForExecuteWithSig({
                    ipId: ipIdChild,
                    to: address(coreMetadataModule),
                    deadline: deadline,
                    state: bytes32(0),
                    data: abi.encodeWithSelector(
                        ICoreMetadataModule.setAll.selector,
                        ipIdChild,
                        ipMetadataDefault.ipMetadataURI,
                        ipMetadataDefault.ipMetadataHash,
                        ipMetadataDefault.nftMetadataHash
                    ),
                    signerSk: sk.alice
                });
                sigMetadataData = WorkflowStructs.SignatureData({
                    signer: u.alice,
                    deadline: deadline,
                    signature: sigMetadata
                });
            }

            {
                uint256 totalMintingFee = _getTotalMintingFee(parentIpIds, licenseTermsIds);
                if (totalMintingFee == 0) {
                    // If the total minting fee is 0, we don't need to have a signature for approving the minting fee
                    sigMintingFeeData = WorkflowStructs.SignatureData({
                        signer: u.alice,
                        deadline: deadline,
                        signature: ""
                    });
                } else {
                    bytes memory sigMintingFee;
                    (sigMintingFee, expectedState) = _getSigForExecuteWithSig({
                        ipId: ipIdChild,
                        to: address(mockToken),
                        deadline: deadline,
                        state: expectedState,
                        data: abi.encodeWithSelector(IERC20.approve.selector, address(royaltyModule), totalMintingFee),
                        signerSk: sk.alice
                    });
                    sigMintingFeeData = WorkflowStructs.SignatureData({
                        signer: u.alice,
                        deadline: deadline,
                        signature: sigMintingFee
                    });
                }
            }

            {
                (bytes memory sigRegister, ) = _getSigForExecuteWithSig({
                    ipId: ipIdChild,
                    to: address(licensingModule),
                    deadline: deadline,
                    state: expectedState,
                    data: abi.encodeWithSelector(
                        ILicensingModule.registerDerivative.selector,
                        ipIdChild,
                        parentIpIds,
                        licenseTermsIds,
                        address(pilTemplate),
                        "",
                        0
                    ),
                    signerSk: sk.alice
                });
                sigRegisterData = WorkflowStructs.SignatureData({
                    signer: u.alice,
                    deadline: deadline,
                    signature: sigRegister
                });
            }
        }

        address ipIdChildActual = derivativeWorkflows.registerIpAndMakeDerivative({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0
            }),
            ipMetadata: ipMetadataDefault,
            sigMetadata: sigMetadataData,
            sigMintingFee: sigMintingFeeData,
            sigRegister: sigRegisterData
        });
        assertEq(ipIdChildActual, ipIdChild);
        assertTrue(ipAssetRegistry.isRegistered(ipIdChild));
        assertEq(nftContract.tokenURI(tokenIdChild), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        assertMetadata(ipIdChild, ipMetadataDefault);
        (address licenseTemplateChild, uint256 licenseTermsIdChild) = licenseRegistry.getAttachedLicenseTerms(
            ipIdChild,
            0
        );
        assertEq(licenseTemplateChild, licenseTemplateParent);
        assertEq(licenseTermsIdChild, licenseTermsIdParent);
        assertEq(IIPAccount(payable(ipIdChild)).owner(), caller);

        assertParentChild({
            parentIpId: ipIdParent,
            childIpId: ipIdChild,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function _getTotalMintingFee(
        address[] memory parentIpIds,
        uint256[] memory licenseTermsIds
    ) internal view returns (uint256) {
        uint256 totalMintingFee;
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            (, uint256 mintFee) = ILicensingModule(licensingModule).predictMintingLicenseFee({
                licensorIpId: parentIpIds[i],
                licenseTemplate: address(pilTemplate),
                licenseTermsId: licenseTermsIds[i],
                amount: 1,
                receiver: address(this),
                royaltyContext: ""
            });
            totalMintingFee += mintFee;
        }
        return totalMintingFee;
    }
}
