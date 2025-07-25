// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IERC7572 } from "../contracts/interfaces/story-nft/IERC7572.sol";
import { ISPGNFT } from "../contracts/interfaces/ISPGNFT.sol";
import { SPGNFT } from "../contracts/SPGNFT.sol";
import { SPGNFTLib } from "../contracts/lib/SPGNFTLib.sol";
import { Errors } from "../contracts/lib/Errors.sol";

import { BaseTest } from "./utils/BaseTest.t.sol";

contract SPGNFTTest is BaseTest {
    using Strings for uint256;

    function setUp() public override {
        super.setUp();

        feeRecipient = u.alice;

        nftContract = SPGNFT(
            registrationWorkflows.createCollection(
                ISPGNFT.InitParams({
                    name: "Test Collection",
                    symbol: "TEST",
                    baseURI: testBaseURI,
                    contractURI: testContractURI,
                    maxSupply: 100,
                    mintFee: 100 * 10 ** mockToken.decimals(),
                    mintFeeToken: address(mockToken),
                    mintFeeRecipient: feeRecipient,
                    owner: u.alice,
                    mintOpen: true,
                    isPublicMinting: false
                })
            )
        );
    }

    function test_SPGNFT_initialize() public {
        address testSpgNftImpl = address(
            new SPGNFT(
                address(derivativeWorkflows),
                address(groupingWorkflows),
                address(licenseAttachmentWorkflows),
                address(registrationWorkflows),
                address(royaltyTokenDistributionWorkflows)
            )
        );
        address NFT_CONTRACT_BEACON = address(new UpgradeableBeacon(testSpgNftImpl, deployer));
        SPGNFT anotherNftContract = SPGNFT(address(new BeaconProxy(NFT_CONTRACT_BEACON, "")));

        vm.expectEmit(address(anotherNftContract));
        emit IERC7572.ContractURIUpdated();
        anotherNftContract.initialize(
            ISPGNFT.InitParams({
                name: "Test Collection",
                symbol: "TEST",
                baseURI: testBaseURI,
                contractURI: testContractURI,
                maxSupply: 100,
                mintFee: 100 * 10 ** mockToken.decimals(),
                mintFeeToken: address(mockToken),
                mintFeeRecipient: feeRecipient,
                owner: u.alice,
                mintOpen: true,
                isPublicMinting: false
            })
        );

        assertEq(nftContract.name(), anotherNftContract.name());
        assertEq(nftContract.symbol(), anotherNftContract.symbol());
        assertEq(nftContract.totalSupply(), anotherNftContract.totalSupply());
        assertTrue(anotherNftContract.hasRole(SPGNFTLib.MINTER_ROLE, u.alice));
        assertEq(anotherNftContract.mintFee(), 100 * 10 ** mockToken.decimals());
        assertEq(anotherNftContract.mintFeeToken(), address(mockToken));
        assertEq(anotherNftContract.mintFeeRecipient(), feeRecipient);
        assertTrue(anotherNftContract.mintOpen());
        assertFalse(anotherNftContract.publicMinting());
        assertEq(anotherNftContract.contractURI(), testContractURI);
        assertEq(anotherNftContract.baseURI(), testBaseURI);
    }

    function test_SPGNFT_initialize_revert_zeroParams() public {
        address testSpgNftImpl = address(
            new SPGNFT(
                address(derivativeWorkflows),
                address(groupingWorkflows),
                address(licenseAttachmentWorkflows),
                address(registrationWorkflows),
                address(royaltyTokenDistributionWorkflows)
            )
        );
        address NFT_CONTRACT_BEACON = address(new UpgradeableBeacon(testSpgNftImpl, deployer));
        nftContract = SPGNFT(address(new BeaconProxy(NFT_CONTRACT_BEACON, "")));

        vm.expectRevert(Errors.SPGNFT__ZeroAddressParam.selector);
        nftContract.initialize(
            ISPGNFT.InitParams({
                name: "Test Collection",
                symbol: "TEST",
                baseURI: testBaseURI,
                contractURI: testContractURI,
                maxSupply: 100,
                mintFee: 1,
                mintFeeToken: address(0),
                mintFeeRecipient: feeRecipient,
                owner: u.alice,
                mintOpen: true,
                isPublicMinting: false
            })
        );

        vm.expectRevert(Errors.SPGNFT__ZeroMaxSupply.selector);
        nftContract.initialize(
            ISPGNFT.InitParams({
                name: "Test Collection",
                symbol: "TEST",
                baseURI: testBaseURI,
                contractURI: testContractURI,
                maxSupply: 0,
                mintFee: 0,
                mintFeeToken: address(mockToken),
                mintFeeRecipient: feeRecipient,
                owner: u.alice,
                mintOpen: true,
                isPublicMinting: false
            })
        );
    }

    function test_SPGNFT_mint() public {
        vm.startPrank(u.alice);

        mockToken.mint(address(u.alice), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        uint256 mintFee = nftContract.mintFee();
        uint256 balanceBeforeAlice = mockToken.balanceOf(u.alice);
        uint256 balanceBeforeContract = mockToken.balanceOf(address(nftContract));
        uint256 tokenId = nftContract.mint({
            to: u.bob,
            nftMetadataURI: ipMetadataEmpty.nftMetadataURI,
            nftMetadataHash: ipMetadataEmpty.nftMetadataHash,
            allowDuplicates: true
        });

        assertEq(nftContract.totalSupply(), 1);
        assertEq(nftContract.balanceOf(u.bob), 1);
        assertEq(nftContract.ownerOf(tokenId), u.bob);
        assertEq(mockToken.balanceOf(u.alice), balanceBeforeAlice - mintFee);
        assertEq(mockToken.balanceOf(address(nftContract)), balanceBeforeContract + mintFee);
        assertEq(nftContract.tokenURI(tokenId), string.concat(testBaseURI, tokenId.toString()));
        balanceBeforeAlice = mockToken.balanceOf(u.alice);
        balanceBeforeContract = mockToken.balanceOf(address(nftContract));

        tokenId = nftContract.mint({
            to: u.bob,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: true
        });

        assertEq(nftContract.getTokenIdByMetadataHash(ipMetadataDefault.nftMetadataHash), tokenId);
        assertEq(nftContract.totalSupply(), 2);
        assertEq(nftContract.balanceOf(u.bob), 2);
        assertEq(nftContract.ownerOf(tokenId), u.bob);
        assertEq(mockToken.balanceOf(u.alice), balanceBeforeAlice - mintFee);
        assertEq(mockToken.balanceOf(address(nftContract)), balanceBeforeContract + mintFee);
        assertEq(nftContract.tokenURI(tokenId), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));
        balanceBeforeAlice = mockToken.balanceOf(u.alice);
        balanceBeforeContract = mockToken.balanceOf(address(nftContract));

        // change mint cost
        nftContract.setMintFee(200 * 10 ** mockToken.decimals());
        mintFee = nftContract.mintFee();

        tokenId = nftContract.mint({
            to: u.carl,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: true
        });
        assertEq(tokenId, 3);
        assertEq(nftContract.getTokenIdByMetadataHash(ipMetadataDefault.nftMetadataHash), 2);
        assertEq(mockToken.balanceOf(address(nftContract)), 400 * 10 ** mockToken.decimals());
        assertEq(nftContract.totalSupply(), 3);
        assertEq(nftContract.balanceOf(u.carl), 1);
        assertEq(nftContract.ownerOf(tokenId), u.carl);
        assertEq(mockToken.balanceOf(u.alice), balanceBeforeAlice - mintFee);
        assertEq(mockToken.balanceOf(address(nftContract)), balanceBeforeContract + mintFee);
        assertEq(nftContract.tokenURI(tokenId), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));

        vm.stopPrank();
    }

    function testFuzz_SPGNFT_mint(string memory nftMetadataURI, bytes32 nftMetadataHash) public {
        vm.assume(bytes(nftMetadataURI).length > 0);
        vm.startPrank(u.alice);

        mockToken.mint(address(u.alice), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        uint256 mintFee = nftContract.mintFee();
        uint256 balanceBeforeAlice = mockToken.balanceOf(u.alice);
        uint256 balanceBeforeContract = mockToken.balanceOf(address(nftContract));

        uint256 tokenId = nftContract.mint({
            to: u.bob,
            nftMetadataURI: nftMetadataURI,
            nftMetadataHash: nftMetadataHash,
            allowDuplicates: true
        });

        assertEq(nftContract.getTokenIdByMetadataHash(nftMetadataHash), tokenId);
        assertEq(nftContract.totalSupply(), 1);
        assertEq(nftContract.balanceOf(u.bob), 1);
        assertEq(nftContract.ownerOf(tokenId), u.bob);
        assertEq(mockToken.balanceOf(u.alice), balanceBeforeAlice - mintFee);
        assertEq(mockToken.balanceOf(address(nftContract)), balanceBeforeContract + mintFee);
        assertEq(nftContract.tokenURI(tokenId), string.concat(testBaseURI, nftMetadataURI));
        balanceBeforeAlice = mockToken.balanceOf(u.alice);
        balanceBeforeContract = mockToken.balanceOf(address(nftContract));

        // change mint cost
        nftContract.setMintFee(200 * 10 ** mockToken.decimals());
        mintFee = nftContract.mintFee();

        tokenId = nftContract.mint({
            to: u.carl,
            nftMetadataURI: nftMetadataURI,
            nftMetadataHash: nftMetadataHash,
            allowDuplicates: true
        });
        assertEq(tokenId, 2);
        assertEq(nftContract.getTokenIdByMetadataHash(nftMetadataHash), 1);
        assertEq(mockToken.balanceOf(address(nftContract)), 300 * 10 ** mockToken.decimals());
        assertEq(nftContract.totalSupply(), 2);
        assertEq(nftContract.balanceOf(u.carl), 1);
        assertEq(nftContract.ownerOf(tokenId), u.carl);
        assertEq(mockToken.balanceOf(u.alice), balanceBeforeAlice - mintFee);
        assertEq(mockToken.balanceOf(address(nftContract)), balanceBeforeContract + mintFee);
        assertEq(nftContract.tokenURI(tokenId), string.concat(testBaseURI, nftMetadataURI));

        vm.stopPrank();
    }

    function test_SPGNFT_mint_revert_DuplicatedNFTMetadataHash() public {
        vm.startPrank(u.alice);
        mockToken.mint(address(u.alice), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        // turn on dedup
        uint256 tokenId = nftContract.mint({
            to: u.carl,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: false
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SPGNFT__DuplicatedNFTMetadataHash.selector,
                address(nftContract),
                tokenId,
                ipMetadataDefault.nftMetadataHash
            )
        );
        nftContract.mint({
            to: u.carl,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: false
        });

        vm.stopPrank();
    }

    function test_SPGNFT_mint_revert_MintingDenied() public {
        vm.startPrank(u.bob);
        mockToken.mint(address(u.bob), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        vm.expectRevert(Errors.SPGNFT__MintingDenied.selector);
        nftContract.mint(u.bob, ipMetadataDefault.nftMetadataURI, ipMetadataDefault.nftMetadataHash, false);

        vm.stopPrank();
    }

    function test_SPGNFT_mintByPeriphery_revert_callerNotPeriphery() public {
        vm.startPrank(u.alice);

        vm.expectRevert(Errors.SPGNFT__CallerNotPeripheryContract.selector);
        nftContract.mintByPeriphery(
            u.bob,
            u.alice,
            ipMetadataDefault.nftMetadataURI,
            ipMetadataDefault.nftMetadataHash,
            false
        );

        vm.stopPrank();
    }

    function test_SPGNFT_setBaseURI() public {
        vm.startPrank(u.alice);
        mockToken.mint(address(u.alice), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        // non empty baseURI
        assertEq(nftContract.baseURI(), testBaseURI);
        uint256 tokenId1 = nftContract.mint({
            to: u.alice,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: true
        });
        assertEq(nftContract.tokenURI(tokenId1), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));

        nftContract.setBaseURI("test");
        assertEq(nftContract.baseURI(), "test");
        uint256 tokenId2 = nftContract.mint({
            to: u.alice,
            nftMetadataURI: ipMetadataEmpty.nftMetadataURI,
            nftMetadataHash: ipMetadataEmpty.nftMetadataHash,
            allowDuplicates: true
        });
        assertEq(nftContract.tokenURI(tokenId1), string.concat("test", ipMetadataDefault.nftMetadataURI));
        assertEq(nftContract.tokenURI(tokenId2), string.concat("test", tokenId2.toString()));

        // empty baseURI
        nftContract.setBaseURI("");
        assertEq(nftContract.baseURI(), "");
        uint256 tokenId3 = nftContract.mint({
            to: u.alice,
            nftMetadataURI: ipMetadataDefault.nftMetadataURI,
            nftMetadataHash: ipMetadataDefault.nftMetadataHash,
            allowDuplicates: true
        });
        assertEq(nftContract.tokenURI(tokenId1), ipMetadataDefault.nftMetadataURI);
        assertEq(nftContract.tokenURI(tokenId2), ipMetadataEmpty.nftMetadataURI);
        assertEq(nftContract.tokenURI(tokenId3), ipMetadataDefault.nftMetadataURI);

        vm.stopPrank();
    }

    function test_SPGNFT_setContractURI() public {
        assertEq(nftContract.contractURI(), testContractURI);

        vm.startPrank(u.alice); // owner (admin) of the collection
        vm.expectEmit(address(nftContract));
        emit IERC7572.ContractURIUpdated();
        nftContract.setContractURI("test");
        assertEq(nftContract.contractURI(), "test");

        vm.expectEmit(address(nftContract));
        emit IERC7572.ContractURIUpdated();
        nftContract.setContractURI(testContractURI);
        assertEq(nftContract.contractURI(), testContractURI);
        vm.stopPrank();
    }

    function test_SPGNFT_revert_mint_erc20InsufficientAllowance() public {
        uint256 mintFee = nftContract.mintFee();
        mockToken.mint(address(u.alice), mintFee);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(nftContract), 0, mintFee)
        );
        vm.prank(u.alice);
        nftContract.mint(u.bob, ipMetadataDefault.nftMetadataURI, ipMetadataDefault.nftMetadataHash, false);
    }

    function test_SPGNFT_revert_mint_erc20InsufficientBalance() public {
        vm.startPrank(u.alice);
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(u.alice),
                0,
                nftContract.mintFee()
            )
        );
        nftContract.mint(u.bob, ipMetadataDefault.nftMetadataURI, ipMetadataDefault.nftMetadataHash, false);
        vm.stopPrank();
    }

    function test_SPGNFT_setMintFee() public {
        vm.startPrank(u.alice);

        nftContract.setMintFee(200 * 10 ** mockToken.decimals());
        assertEq(nftContract.mintFee(), 200 * 10 ** mockToken.decimals());

        nftContract.setMintFee(300 * 10 ** mockToken.decimals());
        assertEq(nftContract.mintFee(), 300 * 10 ** mockToken.decimals());

        vm.stopPrank();
    }

    function test_SPGNFT_setMintFeeToken() public {
        vm.startPrank(u.alice);

        nftContract.setMintFeeToken(address(1));
        assertEq(nftContract.mintFeeToken(), address(1));

        nftContract.setMintFeeToken(address(mockToken));
        assertEq(nftContract.mintFeeToken(), address(mockToken));

        vm.stopPrank();
    }

    function test_SPGNFT_revert_setMintFee_accessControlUnauthorizedAccount() public {
        vm.startPrank(u.bob);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                u.bob,
                SPGNFTLib.ADMIN_ROLE
            )
        );
        nftContract.setMintFee(2);

        vm.stopPrank();
    }

    function test_SPGNFT_withdrawToken() public {
        vm.prank(u.alice);
        nftContract.setMintFeeRecipient(feeRecipient);

        vm.startPrank(u.alice);

        mockToken.mint(address(u.alice), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        uint256 mintFee = nftContract.mintFee();

        nftContract.mint(feeRecipient, ipMetadataDefault.nftMetadataURI, ipMetadataDefault.nftMetadataHash, false);

        assertEq(mockToken.balanceOf(address(nftContract)), mintFee);

        uint256 balanceBeforeFeeRecipient = mockToken.balanceOf(feeRecipient);

        nftContract.withdrawToken(address(mockToken));
        assertEq(mockToken.balanceOf(address(nftContract)), 0);
        assertEq(mockToken.balanceOf(feeRecipient), balanceBeforeFeeRecipient + mintFee);

        vm.stopPrank();
    }

    function test_SPGNFT_setMintFeeRecipient() public {
        // alice is admin and fee recipient
        vm.startPrank(u.alice);
        nftContract.setMintFeeRecipient(u.bob);
        vm.stopPrank();

        // alice is admin, bob is fee recipient
        vm.startPrank(u.bob);
        nftContract.setMintFeeRecipient(u.carl);
        vm.stopPrank();

        // alice is admin, carl is fee recipient
        vm.startPrank(u.alice);
        nftContract.setMintFeeRecipient(u.bob);
        vm.stopPrank();
    }

    function test_SPGNFT_setMintFeeRecipient_revert_callerNotFeeRecipientOrAdmin() public {
        vm.startPrank(u.bob);
        vm.expectRevert(Errors.SPGNFT__CallerNotFeeRecipientOrAdmin.selector);
        nftContract.setMintFeeRecipient(u.carl);
        vm.stopPrank();

        vm.startPrank(u.carl);
        vm.expectRevert(Errors.SPGNFT__CallerNotFeeRecipientOrAdmin.selector);
        nftContract.setMintFeeRecipient(u.bob);
        vm.stopPrank();
    }

    function test_SPGNFT_setTokenURI_deprecated() public {
        // mint a token to alice
        vm.startPrank(u.alice);
        mockToken.mint(address(u.alice), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        uint256 tokenId = nftContract.mint(
            address(u.alice),
            ipMetadataDefault.nftMetadataURI,
            ipMetadataDefault.nftMetadataHash,
            false
        );

        // alice can set the token URI as the owner
        string memory newTokenURI = string.concat(testBaseURI, "newTokenURI");
        nftContract.setTokenURI(tokenId, "newTokenURI");

        // Verify the token URI was updated
        assertEq(nftContract.tokenURI(tokenId), newTokenURI);

        vm.stopPrank();
    }

    function test_SPGNFT_setTokenURI_deprecated_revert_callerNotOwner() public {
        // mint a token to alice
        vm.startPrank(u.alice);
        mockToken.mint(address(u.alice), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        uint256 tokenId = nftContract.mint(
            address(u.alice),
            ipMetadataDefault.nftMetadataURI,
            ipMetadataDefault.nftMetadataHash,
            false
        );
        vm.stopPrank();

        // bob cannot set the token URI as he's not the owner
        vm.startPrank(u.bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.SPGNFT__CallerNotOwner.selector, tokenId, u.bob, u.alice));
        nftContract.setTokenURI(tokenId, "newTokenURI");

        vm.stopPrank();
    }

    function test_SPGNFT_setTokenURI() public {
        // mint a token to alice
        vm.startPrank(u.alice);
        mockToken.mint(address(u.alice), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        uint256 tokenId = nftContract.mint(
            address(u.alice),
            ipMetadataDefault.nftMetadataURI,
            ipMetadataDefault.nftMetadataHash,
            false
        );

        // alice can set the token URI as the owner
        string memory newTokenURI = string.concat(testBaseURI, "newTokenURI");
        nftContract.setTokenURI(tokenId, "newTokenURI", bytes32(keccak256(abi.encodePacked(newTokenURI))));

        // Verify the token URI was updated
        assertEq(nftContract.tokenURI(tokenId), newTokenURI);
        assertEq(nftContract.getTokenIdByMetadataHash(bytes32(keccak256(abi.encodePacked(newTokenURI)))), tokenId);

        vm.stopPrank();
    }

    function test_SPGNFT_setTokenURI_revert_callerNotOwner() public {
        // mint a token to alice
        vm.startPrank(u.alice);
        mockToken.mint(address(u.alice), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        uint256 tokenId = nftContract.mint(
            address(u.alice),
            ipMetadataDefault.nftMetadataURI,
            ipMetadataDefault.nftMetadataHash,
            false
        );
        vm.stopPrank();

        // bob cannot set the token URI as he's not the owner
        vm.startPrank(u.bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.SPGNFT__CallerNotOwner.selector, tokenId, u.bob, u.alice));
        nftContract.setTokenURI(tokenId, "newTokenURI", bytes32(keccak256(abi.encodePacked("newTokenURI"))));

        vm.stopPrank();
    }

    function test_SPGNFT_setMintOpen() public {
        vm.startPrank(u.alice);
        nftContract.setMintOpen(false);
        assertEq(nftContract.mintOpen(), false);

        nftContract.setMintOpen(true);
        assertEq(nftContract.mintOpen(), true);

        vm.stopPrank();

        vm.startPrank(u.bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                u.bob,
                SPGNFTLib.ADMIN_ROLE
            )
        );
        nftContract.setMintOpen(false);
        vm.stopPrank();
    }

    function test_SPGNFT_setPublicMinting() public {
        vm.startPrank(u.alice);
        nftContract.setPublicMinting(false);
        assertEq(nftContract.publicMinting(), false);

        nftContract.setPublicMinting(true);
        assertEq(nftContract.publicMinting(), true);

        vm.stopPrank();

        vm.startPrank(u.bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                u.bob,
                SPGNFTLib.ADMIN_ROLE
            )
        );
        nftContract.setPublicMinting(false);
        vm.stopPrank();
    }
}
