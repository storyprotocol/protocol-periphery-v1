// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
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
    /// @param royaltyClaimDetails The details of the royalty claim from child IPs,
    /// see {IRoyaltyWorkflows-RoyaltyClaimDetails}.
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amount of revenue claimed for each currency token.
    function transferToVaultAndSnapshotAndClaimByTokenBatch(
        address ancestorIpId,
        address claimer,
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
            tokenList: _getCurrencyTokenList(royaltyClaimDetails),
            claimer: claimer
        });
    }

    /// @notice Transfers royalties to the ancestor IP's royalty vault, takes a snapshot, claims revenue for each
    /// specified currency token both on the new snapshot and on each specified unclaimed snapshots.
    /// @param ancestorIpId The address of the ancestor IP.
    /// @param claimer The address of the claimer of the revenue tokens (must be a royalty token holder).
    /// @param unclaimedSnapshotIds The IDs of unclaimed snapshots to include in the claim.
    /// @param royaltyClaimDetails The details of the royalty claim from child IPs,
    /// see {IRoyaltyWorkflows-RoyaltyClaimDetails}.
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amounts of revenue claimed for each currency token.
    function transferToVaultAndSnapshotAndClaimBySnapshotBatch(
        address ancestorIpId,
        address claimer,
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

        address[] memory currencyTokens = _getCurrencyTokenList(royaltyClaimDetails);

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
            } catch (bytes memory reason) {
                // If the error is not IpRoyaltyVault__NoClaimableTokens, revert with the original error
                if (CoreErrors.IpRoyaltyVault__NoClaimableTokens.selector != bytes4(reason)) {
                    assembly {
                        revert(add(reason, 32), mload(reason))
                    }
                }
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
            } catch (bytes memory reason) {
                // If the error is not IpRoyaltyVault__NoClaimableTokens, revert with the original error
                if (CoreErrors.IpRoyaltyVault__NoClaimableTokens.selector != bytes4(reason)) {
                    assembly {
                        revert(add(reason, 32), mload(reason))
                    }
                }
            }
        }
    }

    /// @dev Extracts all unique currency token addresses from an array of RoyaltyClaimDetails.
    /// @param royaltyClaimDetails The details of the royalty claim from child IPs,
    /// see {IRoyaltyWorkflows-RoyaltyClaimDetails}.
    /// @return currencyTokenList An array of unique currency token addresses extracted from `royaltyClaimDetails`.
    function _getCurrencyTokenList(
        RoyaltyClaimDetails[] calldata royaltyClaimDetails
    ) private pure returns (address[] memory currencyTokenList) {
        uint256 length = royaltyClaimDetails.length;
        address[] memory tempUniqueTokenList = new address[](length);
        uint256 uniqueCount = 0;

        for (uint256 i = 0; i < length; i++) {
            address currencyToken = royaltyClaimDetails[i].currencyToken;
            bool isDuplicate = false;

            // Check if `currencyToken` already in `tempUniqueTokenList`
            for (uint256 j = 0; j < uniqueCount; j++) {
                if (tempUniqueTokenList[j] == currencyToken) {
                    // set the `isDuplicate` flag if `currencyToken` already in `tempUniqueTokenList`
                    isDuplicate = true;
                    break;
                }
            }

            // Add `currencyToken` to `tempUniqueTokenList` if it's not already in `tempUniqueTokenList`
            if (!isDuplicate) {
                tempUniqueTokenList[uniqueCount] = currencyToken;
                uniqueCount++;
            }
        }

        currencyTokenList = new address[](uniqueCount);
        for (uint256 i = 0; i < uniqueCount; i++) {
            currencyTokenList[i] = tempUniqueTokenList[i];
        }
    }

    //
    // Upgrade
    //

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
