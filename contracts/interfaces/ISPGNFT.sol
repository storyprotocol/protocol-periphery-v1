// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ISPGNFT is IERC721 {
    function initialize(
        string memory name,
        string memory symbol,
        uint32 maxSupply,
        uint256 mintCost,
        address owner
    ) external;

    function setMintCost(uint256 cost) external;

    function mint(address to) external payable returns (uint256 tokenId);
}
