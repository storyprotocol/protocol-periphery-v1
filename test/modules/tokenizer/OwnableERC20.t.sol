// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { ERC20CappedUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import { IOwnableERC20 } from "../../../contracts/interfaces/modules/tokenizer/IOwnableERC20.sol";
import { OwnableERC20 } from "../../../contracts/modules/tokenizer/OwnableERC20.sol";

import { BaseTest } from "../../utils/BaseTest.t.sol";

contract OwnableERC20Test is BaseTest {
    OwnableERC20 internal testOwnableERC20;

    function setUp() public override {
        super.setUp();

        testOwnableERC20 = OwnableERC20(
            address(
                new BeaconProxy(
                    address(ownableERC20Beacon),
                    abi.encodeWithSelector(
                        IOwnableERC20.initialize.selector,
                        address(0x111),
                        abi.encode(
                            IOwnableERC20.InitData({ cap: 1000, name: "Test", symbol: "TEST", initialOwner: u.admin })
                        )
                    )
                )
            )
        );
    }

    function test_OwnableERC20_initialize() public {
        assertEq(testOwnableERC20.name(), "Test");
        assertEq(testOwnableERC20.symbol(), "TEST");
        assertEq(testOwnableERC20.owner(), u.admin);
        assertEq(testOwnableERC20.cap(), 1000);
        assertEq(testOwnableERC20.ipId(), address(0x111));
    }

    function test_OwnableERC20_mint() public {
        vm.startPrank(u.admin);
        testOwnableERC20.mint(u.admin, 100);
        testOwnableERC20.mint(u.alice, 100);
        testOwnableERC20.mint(u.bob, 100);
        vm.stopPrank();

        assertEq(testOwnableERC20.totalSupply(), 300);
        assertEq(testOwnableERC20.balanceOf(u.admin), 100);
        assertEq(testOwnableERC20.balanceOf(u.alice), 100);
        assertEq(testOwnableERC20.balanceOf(u.bob), 100);
    }

    function test_OwnableERC20_mint_revert_NotOwner() public {
        vm.startPrank(u.alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, u.alice));
        testOwnableERC20.mint(u.alice, 100);
        vm.stopPrank();

        vm.startPrank(u.bob);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, u.bob));
        testOwnableERC20.mint(u.bob, 100);
        vm.stopPrank();
    }

    function test_OwnableERC20_revert_ERC20ExceededCap() public {
        vm.startPrank(u.admin);
        vm.expectRevert(abi.encodeWithSelector(ERC20CappedUpgradeable.ERC20ExceededCap.selector, 1001, 1000));
        testOwnableERC20.mint(u.admin, 1001);
        vm.stopPrank();

        vm.startPrank(u.admin);
        testOwnableERC20.mint(u.alice, 500);
        testOwnableERC20.mint(u.bob, 500);
        vm.stopPrank();

        vm.startPrank(u.admin);
        vm.expectRevert(abi.encodeWithSelector(ERC20CappedUpgradeable.ERC20ExceededCap.selector, 2000, 1000));
        testOwnableERC20.mint(u.admin, 1000);
        vm.stopPrank();
    }
}
