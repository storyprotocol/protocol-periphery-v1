// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Royalty Workflows Interface
/// @notice Interface for IP royalty workflows.
interface IRoyaltyWorkflows {
    /// @notice Details for claiming royalties from a child IP.
    /// @param childIpId The address of the child IP.
    /// @param royaltyPolicy The address of the royalty policy.
    /// @param currencyToken The address of the currency (revenue) token to claim.
    /// @param amount The amount of currency (revenue) token to claim.
    struct RoyaltyClaimDetails {
        address childIpId;
        address royaltyPolicy;
        address currencyToken;
        uint256 amount;
    }

    /// @notice Transfers royalties from royalty policy to the ancestor IP's royalty vault, takes a snapshot,
    /// and claims revenue on that snapshot for each specified currency token.
    /// @param ancestorIpId The address of the ancestor IP.
    /// @param claimer The address of the claimer of the revenue tokens (must be a royalty token holder).
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim (each address must be unique).
    /// @param royaltyClaimDetails The details of the royalty claim from child IPs,
    /// see {IRoyaltyWorkflows-RoyaltyClaimDetails}.
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amount of revenue claimed for each currency token.
    function transferToVaultAndSnapshotAndClaimByTokenBatch(
        address ancestorIpId,
        address claimer,
        address[] calldata currencyTokens,
        RoyaltyClaimDetails[] calldata royaltyClaimDetails
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed);

    /// @notice Transfers royalties to the ancestor IP's royalty vault, takes a snapshot, claims revenue for each
    /// specified currency token both on the new snapshot and on each specified unclaimed snapshots.
    /// @param ancestorIpId The address of the ancestor IP.
    /// @param claimer The address of the claimer of the revenue tokens (must be a royalty token holder).
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim (each address must be unique).
    /// @param unclaimedSnapshotIds The IDs of unclaimed snapshots to include in the claim.
    /// @param royaltyClaimDetails The details of the royalty claim from child IPs,
    /// see {IRoyaltyWorkflows-RoyaltyClaimDetails}.
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amounts of revenue claimed for each currency token.
    function transferToVaultAndSnapshotAndClaimBySnapshotBatch(
        address ancestorIpId,
        address claimer,
        address[] calldata currencyTokens,
        uint256[] calldata unclaimedSnapshotIds,
        RoyaltyClaimDetails[] calldata royaltyClaimDetails
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed);

    /// @notice Takes a snapshot of the IP's royalty vault and claims revenue on that snapshot for each
    /// specified currency token.
    /// @param ipId The address of the IP.
    /// @param claimer The address of the claimer of the revenue tokens (must be a royalty token holder).
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim.
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amounts of revenue claimed for each currency token.
    function snapshotAndClaimByTokenBatch(
        address ipId,
        address claimer,
        address[] calldata currencyTokens
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed);

    /// @notice Takes a snapshot of the IP's royalty vault and claims revenue for each specified currency token
    /// both on the new snapshot and on each specified unclaimed snapshot.
    /// @param ipId The address of the IP.
    /// @param claimer The address of the claimer of the revenue tokens (must be a royalty token holder).
    /// @param unclaimedSnapshotIds The IDs of unclaimed snapshots to include in the claim.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim.
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amounts of revenue claimed for each currency token.
    function snapshotAndClaimBySnapshotBatch(
        address ipId,
        address claimer,
        uint256[] calldata unclaimedSnapshotIds,
        address[] calldata currencyTokens
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed);
}
