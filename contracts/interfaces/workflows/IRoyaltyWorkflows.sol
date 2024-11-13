// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Royalty Workflows Interface
/// @notice Interface for IP royalty workflows.
interface IRoyaltyWorkflows {
    /// @notice Transfers specified amounts of royalties from various royalty policies to the royalty
    ///         vault of an ancestor IP, and claims all the revenue for each currency token from the
    ///         ancestor IP's royalty vault to the claimer.
    /// @param ancestorIpId The address of the ancestor IP from which the revenue is being claimed.
    /// @param claimer The address of the claimer of the currency (revenue) tokens.
    /// @param childIpIds The addresses of the child IPs from which royalties are derived.
    /// @param royaltyPolicies The addresses of the royalty policies that govern royalty flows for each child IP.
    /// @param currencyTokens The addresses of the currency tokens in which the royalties will be claimed.
    /// @param amounts The amounts (in each currency) of royalties to be transferred to the ancestor IP's
    ///        royalty vault and subsequently claimed by the claimer.
    /// @return amountsClaimed The amounts of successfully claimed revenue for each specified currency token.
    function transferToVaultAndClaimByTokenBatch(
        address ancestorIpId,
        address claimer,
        address[] calldata childIpIds,
        address[] calldata royaltyPolicies,
        address[] calldata currencyTokens,
        uint256[] calldata amounts
    ) external returns (uint256[] memory amountsClaimed);

    /// @notice Transfers all avaiable royalties from various royalty policies to the royalty
    ///         vault of an ancestor IP, and claims all the revenue for each currency token
    ///         from the ancestor IP's royalty vault to the claimer.
    /// @param ancestorIpId The address of the ancestor IP from which the revenue is being claimed.
    /// @param claimer The address of the claimer of the currency (revenue) tokens.
    /// @param childIpIds The addresses of the child IPs from which royalties are derived.
    /// @param royaltyPolicies The addresses of the royalty policies that govern royalty flows for each child IP.
    /// @param currencyTokens The addresses of the currency tokens in which the royalties will be claimed.
    /// @return amountsClaimed The amounts of successfully claimed revenue for each specified currency token.
    function claimAllRevenue(
        address ancestorIpId,
        address claimer,
        address[] calldata childIpIds,
        address[] calldata royaltyPolicies,
        address[] calldata currencyTokens
    ) external returns (uint256[] memory amountsClaimed);
}
