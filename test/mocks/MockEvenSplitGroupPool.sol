// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IGroupRewardPool } from "@storyprotocol/core/interfaces/modules/grouping/IGroupRewardPool.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract MockEvenSplitGroupPool is IGroupRewardPool {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct IpRewardInfo {
        uint256 startPoolBalance; // balance of pool when IP added to pool
        uint256 rewardDebt; // pending reward = (PoolInfo.accBalance - startPoolBalance)  / totalIp - ip.rewardDebt
    }

    struct PoolInfo {
        uint256 accBalance;
        uint256 availableBalance;
    }

    mapping(address groupId => mapping(address ipId => uint256 addedTime)) public ipAddedTime;
    mapping(address groupId => uint256 totalMemberIPs) public totalMemberIPs;
    mapping(address groupId => EnumerableSet.AddressSet tokens) internal groupTokens;
    // Info of each token pool. groupId => { token => PoolInfo}
    mapping(address groupId => mapping(address token => PoolInfo)) public poolInfo;
    // Info of each user that stakes LP tokens. groupId => { token => { ipId => IpInfo}}
    mapping(address groupId => mapping(address tokenId => mapping(address ipId => IpRewardInfo))) public ipRewardInfo;

    function addIp(address groupId, address ipId) external {
        // ignore if IP is already added to pool
        if (ipAddedTime[groupId][ipId] != 0) return;
        ipAddedTime[groupId][ipId] = block.timestamp;
        // set rewardDebt of IP to current availableReward of the IP
        totalMemberIPs[groupId] += 1;

        EnumerableSet.AddressSet storage tokens = groupTokens[groupId];
        uint256 length = tokens.length();
        for (uint256 i = 0; i < length; i++) {
            address token = tokens.at(i);
            _collectRoyalties(groupId, token);
            uint256 totalReward = poolInfo[groupId][token].accBalance;
            ipRewardInfo[groupId][token][ipId].startPoolBalance = totalReward;
            ipRewardInfo[groupId][token][ipId].rewardDebt = 0;
        }
    }

    function removeIp(address groupId, address ipId) external {
        EnumerableSet.AddressSet storage tokens = groupTokens[groupId];
        uint256 length = tokens.length();
        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId;
        for (uint256 i = 0; i < length; i++) {
            address token = tokens.at(i);
            _collectRoyalties(groupId, token);
            _distributeRewards(groupId, token, ipIds);
            ipAddedTime[groupId][ipId] = 0;
        }
        totalMemberIPs[groupId] -= 1;
    }

    /// @notice Returns the reward for each IP in the group
    /// @param groupId The group ID
    /// @param token The reward token
    /// @param ipIds The IP IDs
    /// @return The rewards for each IP
    function getAvailableReward(
        address groupId,
        address token,
        address[] calldata ipIds
    ) external view returns (uint256[] memory) {
        return _getAvailableReward(groupId, token, ipIds);
    }

    function distributeRewards(
        address groupId,
        address token,
        address[] calldata ipIds
    ) external returns (uint256[] memory rewards) {
        return _distributeRewards(groupId, token, ipIds);
    }

    function collectRoyalties(address groupId, address token) external {
        _collectRoyalties(groupId, token);
    }

    function _getAvailableReward(
        address groupId,
        address token,
        address[] memory ipIds
    ) internal view returns (uint256[] memory) {
        uint256 totalAccumulatePoolBalance = poolInfo[groupId][token].accBalance;
        uint256[] memory rewards = new uint256[](ipIds.length);
        for (uint256 i = 0; i < ipIds.length; i++) {
            // ignore if IP is not added to pool
            if (ipAddedTime[groupId][ipIds[i]] == 0) {
                rewards[i] = 0;
                revert("IP not added to pool");
                continue;
            }
            uint256 poolBalanceBeforeIpAdded = ipRewardInfo[groupId][token][ipIds[i]].startPoolBalance;
            uint256 rewardPerIP = (totalAccumulatePoolBalance - poolBalanceBeforeIpAdded) / totalMemberIPs[groupId];
            rewards[i] = rewardPerIP - ipRewardInfo[groupId][token][ipIds[i]].rewardDebt;
        }
        return rewards;
    }

    function _distributeRewards(
        address groupId,
        address token,
        address[] memory ipIds
    ) internal returns (uint256[] memory rewards) {
        rewards = _getAvailableReward(groupId, token, ipIds);
        for (uint256 i = 0; i < ipIds.length; i++) {
            // calculate pending reward for each IP
            ipRewardInfo[groupId][token][ipIds[i]].rewardDebt += rewards[i];
            poolInfo[groupId][token].availableBalance -= rewards[i];
            // call royalty module to transfer reward to IP as royalty
            IERC20(token).safeTransfer(ipIds[i], rewards[i]);
        }
    }

    function _collectRoyalties(address groupId, address token) internal {
        // call royalty module to collect revenue of token
        uint256 royalties = 0;
        poolInfo[groupId][token].availableBalance += royalties;
        poolInfo[groupId][token].accBalance += royalties;
        groupTokens[groupId].add(token);
    }

    function depositReward(address groupId, address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        poolInfo[groupId][token].accBalance += amount;
        poolInfo[groupId][token].availableBalance += amount;
        groupTokens[groupId].add(token);
    }
}
