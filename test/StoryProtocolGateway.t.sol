// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { ISPGNFT } from "../contracts/interfaces/ISPGNFT.sol";
import { Errors } from "../contracts/lib/Errors.sol";
import { SPGNFTLib } from "../contracts/lib/SPGNFTLib.sol";

import { BaseTest } from "./utils/BaseTest.t.sol";

contract StoryProtocolGatewayTest is BaseTest {
    ISPGNFT internal nftContract;
    address internal minter;
    address internal caller;

    function setUp() public override {
        super.setUp();
        minter = alice;
    }

    modifier withCollection() {
        nftContract = ISPGNFT(
            spg.createCollection({
                name: "Test Collection",
                symbol: "TEST",
                maxSupply: 100,
                mintCost: 100 * 10 ** mockToken.decimals(),
                mintToken: address(mockToken),
                owner: minter
            })
        );
        _;
    }

    function test_SPG_createCollection() public withCollection {
        uint256 mintCost = nftContract.mintCost();

        assertEq(nftContract.name(), "Test Collection");
        assertEq(nftContract.symbol(), "TEST");
        assertEq(nftContract.totalSupply(), 0);
        assertTrue(nftContract.hasRole(SPGNFTLib.MINTER_ROLE, alice));
        assertEq(mintCost, 100 * 10 ** mockToken.decimals());
    }

    modifier whenCallerDoesNotHaveMinterRole() {
        caller = bob;
        _;
    }

    function test_SPG_revert_mintAndRegisterIp_callerNotMinterRole()
        public
        withCollection
        whenCallerDoesNotHaveMinterRole
    {
        vm.expectRevert(Errors.SPG__CallerNotMinterRole.selector);
        vm.prank(caller);
        spg.mintAndRegisterIp({ nftContract: address(nftContract), recipient: bob });
    }

    modifier whenCallerHasMinterRole() {
        caller = alice;
        vm.startPrank(caller);
        _;
    }

    function test_SPG_mintAndRegisterIp() public withCollection whenCallerHasMinterRole {
        mockToken.mint(address(caller), 1000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 1000 * 10 ** mockToken.decimals());

        spg.mintAndRegisterIp({ nftContract: address(nftContract), recipient: bob });
    }
}
