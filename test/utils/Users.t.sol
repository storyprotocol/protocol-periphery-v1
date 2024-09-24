// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Vm } from "forge-std/Vm.sol";

struct Users {
    // Default admin
    address payable admin;
    // Random users
    address payable alice;
    address payable bob;
    address payable carl;
    address payable dan;
}

struct UserSecretKeys {
    // Default admin
    uint256 admin;
    // Random users
    uint256 alice;
    uint256 bob;
    uint256 carl;
    uint256 dan;
}

library UsersLib {
    function createUser(string memory name, Vm vm) public returns (address payable user, uint256 sk) {
        sk = uint256(keccak256(abi.encodePacked(name)));
        user = payable(vm.addr(sk));
        vm.deal(user, 1000 ether); // set balance to 1000 ether
        vm.label(user, name);
        return (user, sk);
    }

    function createMockUsers(Vm vm) public returns (Users memory, UserSecretKeys memory) {
        (address payable admin, uint256 adminSk) = createUser("Admin", vm);
        (address payable alice, uint256 aliceSk) = createUser("Alice", vm);
        (address payable bob, uint256 bobSk) = createUser("Bob", vm);
        (address payable carl, uint256 carlSk) = createUser("Carl", vm);
        (address payable dan, uint256 danSk) = createUser("Dan", vm);

        return (
            Users({ admin: admin, alice: alice, bob: bob, carl: carl, dan: dan }),
            UserSecretKeys({ admin: adminSk, alice: aliceSk, bob: bobSk, carl: carlSk, dan: danSk })
        );
    }
}
