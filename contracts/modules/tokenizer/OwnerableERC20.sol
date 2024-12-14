// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OwnerableERC20 is ERC20 {
    constructor() ERC20("MockERC20", "MERC20") {}

    // can only mint by owner
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
