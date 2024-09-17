// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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
                address(registrationWorkflows)
            )
        );
        address NFT_CONTRACT_BEACON = address(new UpgradeableBeacon(testSpgNftImpl, deployer));
        SPGNFT anotherNftContract = SPGNFT(address(new BeaconProxy(NFT_CONTRACT_BEACON, "")));

        anotherNftContract.initialize(
            ISPGNFT.InitParams({
                name: "Test Collection",
                symbol: "TEST",
                baseURI: testBaseURI,
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
    }

    function test_SPGNFT_initialize_revert_zeroParams() public {
        address testSpgNftImpl = address(
            new SPGNFT(
                address(derivativeWorkflows),
                address(groupingWorkflows),
                address(licenseAttachmentWorkflows),
                address(registrationWorkflows)
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
        uint256 tokenId = nftContract.mint(u.bob, ipMetadataEmpty.nftMetadataURI);

        assertEq(nftContract.totalSupply(), 1);
        assertEq(nftContract.balanceOf(u.bob), 1);
        assertEq(nftContract.ownerOf(tokenId), u.bob);
        assertEq(mockToken.balanceOf(u.alice), balanceBeforeAlice - mintFee);
        assertEq(mockToken.balanceOf(address(nftContract)), balanceBeforeContract + mintFee);
        assertEq(nftContract.tokenURI(tokenId), string.concat(testBaseURI, tokenId.toString()));
        balanceBeforeAlice = mockToken.balanceOf(u.alice);
        balanceBeforeContract = mockToken.balanceOf(address(nftContract));

        tokenId = nftContract.mint(u.bob, ipMetadataDefault.nftMetadataURI);
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

        tokenId = nftContract.mint(u.carl, ipMetadataDefault.nftMetadataURI);
        assertEq(mockToken.balanceOf(address(nftContract)), 400 * 10 ** mockToken.decimals());
        assertEq(nftContract.totalSupply(), 3);
        assertEq(nftContract.balanceOf(u.carl), 1);
        assertEq(nftContract.ownerOf(tokenId), u.carl);
        assertEq(mockToken.balanceOf(u.alice), balanceBeforeAlice - mintFee);
        assertEq(mockToken.balanceOf(address(nftContract)), balanceBeforeContract + mintFee);
        assertEq(nftContract.tokenURI(tokenId), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));

        vm.stopPrank();
    }

    function test_SPGNFT_setBaseURI() public {
        vm.startPrank(u.alice);
        mockToken.mint(address(u.alice), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        // non empty baseURI
        assertEq(nftContract.baseURI(), testBaseURI);
        uint256 tokenId1 = nftContract.mint(u.alice, ipMetadataDefault.nftMetadataURI);
        assertEq(nftContract.tokenURI(tokenId1), string.concat(testBaseURI, ipMetadataDefault.nftMetadataURI));

        nftContract.setBaseURI("test");
        assertEq(nftContract.baseURI(), "test");
        uint256 tokenId2 = nftContract.mint(u.alice, ipMetadataEmpty.nftMetadataURI);
        assertEq(nftContract.tokenURI(tokenId1), string.concat("test", ipMetadataDefault.nftMetadataURI));
        assertEq(nftContract.tokenURI(tokenId2), string.concat("test", tokenId2.toString()));

        // empty baseURI
        nftContract.setBaseURI("");
        assertEq(nftContract.baseURI(), "");
        uint256 tokenId3 = nftContract.mint(u.alice, ipMetadataDefault.nftMetadataURI);
        assertEq(nftContract.tokenURI(tokenId1), ipMetadataDefault.nftMetadataURI);
        assertEq(nftContract.tokenURI(tokenId2), ipMetadataEmpty.nftMetadataURI);
        assertEq(nftContract.tokenURI(tokenId3), ipMetadataDefault.nftMetadataURI);

        vm.stopPrank();
    }

    function test_SPGNFT_revert_mint_erc20InsufficientAllowance() public {
        uint256 mintFee = nftContract.mintFee();
        mockToken.mint(address(u.alice), mintFee);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(nftContract), 0, mintFee)
        );
        vm.prank(u.alice);
        nftContract.mint(u.bob, ipMetadataDefault.nftMetadataURI);
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
        nftContract.mint(u.bob, ipMetadataDefault.nftMetadataURI);
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

        nftContract.mint(feeRecipient, ipMetadataDefault.nftMetadataURI);

        assertEq(mockToken.balanceOf(address(nftContract)), mintFee);

        uint256 balanceBeforeFeeRecipient = mockToken.balanceOf(feeRecipient);

        nftContract.withdrawToken(address(mockToken));
        assertEq(mockToken.balanceOf(address(nftContract)), 0);
        assertEq(mockToken.balanceOf(feeRecipient), balanceBeforeFeeRecipient + mintFee);

        vm.stopPrank();
    }
}
