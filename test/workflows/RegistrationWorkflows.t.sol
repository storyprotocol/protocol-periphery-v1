//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
/* solhint-disable no-console */

// external
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";

// contracts
import { Errors } from "../../contracts/lib/Errors.sol";
import { ISPGNFT } from "../../contracts/interfaces/ISPGNFT.sol";
import { SPGNFTLib } from "../../contracts/lib/SPGNFTLib.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";

contract RegistrationWorkflowsTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_RegistrationWorkflows_createCollection() public withCollection {
        assertEq(nftContract.name(), "Test Collection");
        assertEq(nftContract.symbol(), "TEST");
        assertEq(nftContract.totalSupply(), 0);
        assertTrue(nftContract.hasRole(SPGNFTLib.MINTER_ROLE, u.alice));
        assertEq(nftContract.mintFee(), 100 * 10 ** mockToken.decimals());
        assertEq(nftContract.mintFeeToken(), address(mockToken));
        assertEq(nftContract.mintFeeRecipient(), u.carl);
        assertTrue(nftContract.mintOpen());
        assertFalse(nftContract.publicMinting());
    }

    modifier whenCallerDoesNotHaveMinterRole() {
        caller = u.bob;
        _;
    }

    function test_RegistrationWorkflows_revert_mintAndRegisterIp_callerNotMinterRole()
        public
        withCollection
        whenCallerDoesNotHaveMinterRole
    {
        vm.expectRevert(Errors.SPG__CallerNotMinterRole.selector);
        vm.prank(caller);
        registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(nftContract),
            recipient: u.bob,
            ipMetadata: ipMetadataEmpty
        });
    }

    function test_RegistrationWorkflows_mintAndRegisterIp() public withCollection whenCallerHasMinterRole {
        mockToken.mint(address(caller), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        (address ipId1, uint256 tokenId1) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(nftContract),
            recipient: u.bob,
            ipMetadata: ipMetadataEmpty
        });
        assertEq(tokenId1, 1);
        assertTrue(ipAssetRegistry.isRegistered(ipId1));
        assertEq(nftContract.tokenURI(tokenId1), ipMetadataEmpty.nftMetadataURI);
        assertMetadata(ipId1, ipMetadataEmpty);

        (address ipId2, uint256 tokenId2) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(nftContract),
            recipient: u.bob,
            ipMetadata: ipMetadataDefault
        });
        assertEq(tokenId2, 2);
        assertTrue(ipAssetRegistry.isRegistered(ipId2));
        assertEq(nftContract.tokenURI(tokenId2), ipMetadataDefault.nftMetadataURI);
        assertMetadata(ipId2, ipMetadataDefault);
    }

    function test_RegistrationWorkflows_registerIp() public {
        uint256 tokenId = mockNft.mint(address(u.alice));
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(mockNft), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadata, bytes32 expectedState, ) = _getSetPermissionSigForPeriphery({
            ipId: expectedIpId,
            to: address(registrationWorkflows),
            module: address(coreMetadataModule),
            selector: ICoreMetadataModule.setAll.selector,
            deadline: deadline,
            state: bytes32(0),
            signerSk: sk.alice
        });

        address actualIpId = registrationWorkflows.registerIp({
            nftContract: address(mockNft),
            tokenId: tokenId,
            ipMetadata: ipMetadataDefault,
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: deadline, signature: sigMetadata })
        });

        assertEq(IIPAccount(payable(actualIpId)).state(), expectedState);
        assertEq(actualIpId, expectedIpId);
        assertTrue(ipAssetRegistry.isRegistered(actualIpId));
        assertMetadata(actualIpId, ipMetadataDefault);
    }

    function test_RegistrationWorkflows_multicall_createCollection() public {
        ISPGNFT[] memory nftContracts = new ISPGNFT[](10);
        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                registrationWorkflows.createCollection.selector,
                "Test Collection",
                "TEST",
                100,
                100 * 10 ** mockToken.decimals(),
                address(mockToken),
                feeRecipient,
                minter,
                true,
                false
            );
        }

        bytes[] memory results = registrationWorkflows.multicall(data);
        for (uint256 i = 0; i < 10; i++) {
            nftContracts[i] = ISPGNFT(abi.decode(results[i], (address)));
        }

        for (uint256 i = 0; i < 10; i++) {
            assertEq(nftContracts[i].name(), "Test Collection");
            assertEq(nftContracts[i].symbol(), "TEST");
            assertEq(nftContracts[i].totalSupply(), 0);
            assertTrue(nftContracts[i].hasRole(SPGNFTLib.MINTER_ROLE, u.alice));
            assertEq(nftContracts[i].mintFee(), 100 * 10 ** mockToken.decimals());
            assertEq(nftContracts[i].mintFeeToken(), address(mockToken));
            assertEq(nftContracts[i].mintFeeRecipient(), u.carl);
            assertTrue(nftContracts[i].mintOpen());
            assertFalse(nftContracts[i].publicMinting());
        }
    }

    function test_RegistrationWorkflows_multicall_mintAndRegisterIp() public withCollection whenCallerHasMinterRole {
        mockToken.mint(address(caller), 1000 * 10 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 * 10 ** mockToken.decimals());

        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                registrationWorkflows.mintAndRegisterIp.selector,
                address(nftContract),
                u.bob,
                ipMetadataDefault
            );
        }
        bytes[] memory results = registrationWorkflows.multicall(data);
        address[] memory ipIds = new address[](10);
        uint256[] memory tokenIds = new uint256[](10);

        for (uint256 i = 0; i < 10; i++) {
            (ipIds[i], tokenIds[i]) = abi.decode(results[i], (address, uint256));
            assertTrue(ipAssetRegistry.isRegistered(ipIds[i]));
            assertEq(nftContract.tokenURI(tokenIds[i]), ipMetadataDefault.nftMetadataURI);
            assertMetadata(ipIds[i], ipMetadataDefault);
        }
    }
}
