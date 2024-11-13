// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Royalty Workflows Interface
/// @notice Interface for IP royalty workflows.
interface IRoyaltyWorkflows {
    /// @notice Transfers royalties from royalty policy to the ancestor IP's royalty vault, and claims revenue
    /// for each specified currency token.
    /// @param ancestorIpId The address of the ancestor IP.
    /// @param claimer The address of the claimer of the revenue tokens (must be a royalty token holder).
    /// @param childIpIds The addresses of the child IPs.
    /// @param royaltyPolicies The addresses of the royalty policies.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim.
    /// @param amounts The amounts of currency (revenue) tokens to claim.
    /// @return amountsClaimed The amount of revenue claimed for each currency token.
    function transferToVaultAndClaimByTokenBatch(
        address ancestorIpId,
        address claimer,
        address[] calldata childIpIds,
        address[] calldata royaltyPolicies,
        address[] calldata currencyTokens,
        uint256[] calldata amounts
    ) external returns (uint256[] memory amountsClaimed);

    /// @notice Claims all revenue for each specified currency token.
    /// @param ancestorIpId The address of the ancestor IP.
    /// @param claimer The address of the claimer of the revenue tokens (must be a royalty token holder).
    /// @param childIpIds The addresses of the child IPs.
    /// @param royaltyPolicies The addresses of the royalty policies.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim.
    /// @return amountsClaimed The amount of revenue claimed for each currency token.
    function claimAllRevenue(
        address ancestorIpId,
        address claimer,
        address[] calldata childIpIds,
        address[] calldata royaltyPolicies,
        address[] calldata currencyTokens
    ) external returns (uint256[] memory amountsClaimed);
}
