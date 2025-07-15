// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { WorkflowStructs } from "../../lib/WorkflowStructs.sol";

/// @title Royalty Workflows Interface
/// @notice Interface for IP royalty workflows.
interface IRoyaltyWorkflows {
    /// @notice Transfers all available royalties from various royalty policies to the royalty
    ///         vault of an ancestor IP, and claims all the revenue for each currency token
    ///         from the ancestor IP's royalty vault to the claimer.
    /// @param ancestorIpId The address of the ancestor IP from which the revenue is being claimed.
    /// @param claimer The address of the claimer of the currency (revenue) tokens.
    /// @param claimRevenueData The data for claiming revenue from each child IP.
    /// @return amountsClaimed The amounts of successfully claimed revenue for each specified currency token.
    function claimAllRevenue(
        address ancestorIpId,
        address claimer,
        WorkflowStructs.ClaimRevenueData[] calldata claimRevenueData
    ) external returns (uint256[] memory amountsClaimed);

    // >>>>>>>>>>>>>>>>>>>>>>>>>>> DEPRECATED FUNCTIONS >>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    /// @notice Transfers all available royalties from various royalty policies to the royalty
    ///         vault of an ancestor IP, and claims all the revenue for each currency token
    ///         from the ancestor IP's royalty vault to the claimer.
    /// @dev This function is deprecated and will be removed in a future version of the protocol.
    ///      Use `claimAllRevenue(ancestorIpId, claimer, claimRevenueData)` instead.
    /// @param ancestorIpId The address of the ancestor IP from which the revenue is being claimed.
    /// @param claimer The address of the claimer of the currency (revenue) tokens.
    /// @param childIpIds The addresses of the child IPs from which royalties are derived.
    /// @param royaltyPolicies The addresses of the royalty policies, where royaltyPolicies[i] governs
    ///        the royalty flow for childIpIds[i].
    /// @param currencyTokens The addresses of the currency tokens in which royalties will be claimed,
    ///        where currencyTokens[i] is the token used for royalties from childIpIds[i].
    /// @return amountsClaimed The amounts of successfully claimed revenue for each specified currency token.
    function claimAllRevenue(
        address ancestorIpId,
        address claimer,
        address[] calldata childIpIds,
        address[] calldata royaltyPolicies,
        address[] calldata currencyTokens
    ) external returns (uint256[] memory amountsClaimed);
}
