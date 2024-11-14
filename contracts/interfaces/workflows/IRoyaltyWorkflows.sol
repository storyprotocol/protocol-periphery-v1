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
    /// @param royaltyPolicies The addresses of the royalty policies, where royaltyPolicies[i] governs
    ///        the royalty flow for childIpIds[i].
    /// @param currencyTokens The addresses of the currency tokens in which royalties will be claimed,
    ///        where currencyTokens[i] is the token used for royalties from childIpIds[i].
    /// @param amounts The amounts to transfer and claim, where amounts[i] represents the amount of
    ///        royalties in currencyTokens[i] to transfer from childIpIds[i]'s royaltyPolicies[i] to the ancestor's
    ///        royalty vault.
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
