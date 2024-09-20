// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// solhint-disable-next-line max-line-length
import { IGraphAwareRoyaltyPolicy } from "@storyprotocol/core/interfaces/modules/royalty/policies/IGraphAwareRoyaltyPolicy.sol";
import { IIpRoyaltyVault } from "@storyprotocol/core/interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";

import { Errors } from "../lib/Errors.sol";
import { IRoyaltyWorkflows } from "../interfaces/workflows/IRoyaltyWorkflows.sol";

/// @title Royalty Workflows
/// @notice Each workflow bundles multiple core protocol operations into a single function to enable one-click
/// IP revenue claiming in the Story Proof-of-Creativity Protocol.
contract RoyaltyWorkflows is IRoyaltyWorkflows, MulticallUpgradeable, AccessManagedUpgradeable, UUPSUpgradeable {
    using ERC165Checker for address;

    /// @notice The address of the Royalty Module.
    IRoyaltyModule public immutable ROYALTY_MODULE;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address royaltyModule) {
        if (royaltyModule == address(0)) revert Errors.RoyaltyWorkflows__ZeroAddressParam();

        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);

        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.RoyaltyWorkflows__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
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
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed) {
        // Transfers to ancestor's vault an amount of revenue tokens claimable via the given royalty policy
        for (uint256 i = 0; i < royaltyClaimDetails.length; i++) {
            IGraphAwareRoyaltyPolicy(royaltyClaimDetails[i].royaltyPolicy).transferToVault({
                ipId: royaltyClaimDetails[i].childIpId,
                ancestorIpId: ancestorIpId,
                token: royaltyClaimDetails[i].currencyToken,
                amount: royaltyClaimDetails[i].amount
            });
        }

        // Gets the ancestor IP's royalty vault
        IIpRoyaltyVault ancestorIpRoyaltyVault = IIpRoyaltyVault(ROYALTY_MODULE.ipRoyaltyVaults(ancestorIpId));

        // Takes a snapshot of the ancestor IP's royalty vault
        snapshotId = ancestorIpRoyaltyVault.snapshot();

        // Claims revenue for each specified currency token from the latest snapshot
        amountsClaimed = ancestorIpRoyaltyVault.claimRevenueOnBehalfByTokenBatch({
            snapshotId: snapshotId,
            tokenList: currencyTokens,
            claimer: claimer
        });
    }

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
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed) {
        // Transfers to ancestor's vault an amount of revenue tokens claimable via the given royalty policy
        for (uint256 i = 0; i < royaltyClaimDetails.length; i++) {
            IGraphAwareRoyaltyPolicy(royaltyClaimDetails[i].royaltyPolicy).transferToVault({
                ipId: royaltyClaimDetails[i].childIpId,
                ancestorIpId: ancestorIpId,
                token: royaltyClaimDetails[i].currencyToken,
                amount: royaltyClaimDetails[i].amount
            });
        }

        // Gets the ancestor IP's royalty vault
        IIpRoyaltyVault ancestorIpRoyaltyVault = IIpRoyaltyVault(ROYALTY_MODULE.ipRoyaltyVaults(ancestorIpId));

        // Takes a snapshot of the ancestor IP's royalty vault
        snapshotId = ancestorIpRoyaltyVault.snapshot();

        // Claims revenue for each specified currency token from the latest snapshot
        amountsClaimed = ancestorIpRoyaltyVault.claimRevenueOnBehalfByTokenBatch({
            snapshotId: snapshotId,
            tokenList: currencyTokens,
            claimer: claimer
        });

        // Claims revenue for each specified currency token from the unclaimed snapshots
        for (uint256 i = 0; i < currencyTokens.length; i++) {
            try
                ancestorIpRoyaltyVault.claimRevenueOnBehalfBySnapshotBatch({
                    snapshotIds: unclaimedSnapshotIds,
                    token: currencyTokens[i],
                    claimer: claimer
                })
            returns (uint256 claimedAmount) {
                amountsClaimed[i] += claimedAmount;
            } catch {
                amountsClaimed[i] += 0;
            }
        }
    }

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
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed) {
        // Gets the IP's royalty vault
        IIpRoyaltyVault ipRoyaltyVault = IIpRoyaltyVault(ROYALTY_MODULE.ipRoyaltyVaults(ipId));

        // Claims revenue for each specified currency token from the latest snapshot
        snapshotId = ipRoyaltyVault.snapshot();
        amountsClaimed = ipRoyaltyVault.claimRevenueOnBehalfByTokenBatch({
            snapshotId: snapshotId,
            tokenList: currencyTokens,
            claimer: claimer
        });
    }

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
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed) {
        // Gets the IP's royalty vault
        IIpRoyaltyVault ipRoyaltyVault = IIpRoyaltyVault(ROYALTY_MODULE.ipRoyaltyVaults(ipId));

        // Claims revenue for each specified currency token from the latest snapshot
        snapshotId = ipRoyaltyVault.snapshot();
        amountsClaimed = ipRoyaltyVault.claimRevenueOnBehalfByTokenBatch({
            snapshotId: snapshotId,
            tokenList: currencyTokens,
            claimer: claimer
        });

        // Claims revenue for each specified currency token from the unclaimed snapshots
        for (uint256 i = 0; i < currencyTokens.length; i++) {
            try
                ipRoyaltyVault.claimRevenueOnBehalfBySnapshotBatch({
                    snapshotIds: unclaimedSnapshotIds,
                    token: currencyTokens[i],
                    claimer: claimer
                })
            returns (uint256 claimedAmount) {
                amountsClaimed[i] += claimedAmount;
            } catch {
                // Continue to the next currency token
                amountsClaimed[i] += 0;
            }
        }
    }

    //
    // Upgrade
    //

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
