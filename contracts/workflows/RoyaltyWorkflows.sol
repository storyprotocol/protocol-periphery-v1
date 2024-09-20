// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

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

    /// @dev Storage structure for the RoyaltyWorkflows
    /// @param nftContractBeacon The address of the NFT contract beacon.
    /// @custom:storage-location erc7201:story-protocol-periphery.RoyaltyWorkflows
    struct RoyaltyWorkflowsStorage {
        address nftContractBeacon;
    }

    // solhint-disable-next-line max-line-length
    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.RoyaltyWorkflows")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RoyaltyWorkflowsStorageLocation =
        0xf8dd9547b39b63dae20d14a2656d9d90affd36dc45fea58a4339f128bf613700;

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

    /// @dev Sets the NFT contract beacon address.
    /// @param newNftContractBeacon The address of the new NFT contract beacon.
    function setNftContractBeacon(address newNftContractBeacon) external restricted {
        if (newNftContractBeacon == address(0)) revert Errors.RoyaltyWorkflows__ZeroAddressParam();
        RoyaltyWorkflowsStorage storage $ = _getRoyaltyWorkflowsStorage();
        $.nftContractBeacon = newNftContractBeacon;
    }

    /// @notice Transfers royalties from royalty policy to the ancestor IP's royalty vault, takes a snapshot,
    /// and claims revenue on that snapshot for each specified currency token.
    /// @param ancestorIpId The address of the ancestor IP.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim (each address must be unique).
    /// @param royaltyClaimDetails The details of the royalty claim from child IPs,
    /// see {IRoyaltyWorkflows-RoyaltyClaimDetails}.
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amount of revenue claimed for each currency token.
    function transferToVaultAndSnapshotAndClaimByTokenBatch(
        address ancestorIpId,
        address[] calldata currencyTokens,
        RoyaltyClaimDetails[] calldata royaltyClaimDetails
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed) {
        (snapshotId, amountsClaimed, ) = _transferToVaultAndSnapshotAndClaimByTokenBatch(
            ancestorIpId,
            currencyTokens,
            royaltyClaimDetails
        );
    }

    /// @notice Transfers royalties to the ancestor IP's royalty vault, takes a snapshot, claims revenue for each
    /// specified currency token both on the new snapshot and on each specified unclaimed snapshots.
    /// @param ancestorIpId The address of the ancestor IP.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim (each address must be unique).
    /// @param unclaimedSnapshotIds The IDs of unclaimed snapshots to include in the claim.
    /// @param royaltyClaimDetails The details of the royalty claim from child IPs,
    /// see {IRoyaltyWorkflows-RoyaltyClaimDetails}.
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amounts of revenue claimed for each currency token.
    function transferToVaultAndSnapshotAndClaimBySnapshotBatch(
        address ancestorIpId,
        address[] calldata currencyTokens,
        uint256[] calldata unclaimedSnapshotIds,
        RoyaltyClaimDetails[] calldata royaltyClaimDetails
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed) {
        // Claims revenue for each specified currency token from the latest snapshot
        IIpRoyaltyVault ancestorIpRoyaltyVault;
        (snapshotId, amountsClaimed, ancestorIpRoyaltyVault) = _transferToVaultAndSnapshotAndClaimByTokenBatch(
            ancestorIpId,
            currencyTokens,
            royaltyClaimDetails
        );

        // Claims revenue for each specified currency token from the unclaimed snapshots
        uint256 length = royaltyClaimDetails.length;
        for (uint256 i = 0; i < length; i++) {
            amountsClaimed[i] += ancestorIpRoyaltyVault.claimRevenueOnBehalfBySnapshotBatch({
                snapshotIds: unclaimedSnapshotIds,
                token: royaltyClaimDetails[i].currencyToken,
                claimer: address(ancestorIpRoyaltyVault)
            });
        }
    }

    /// @notice Takes a snapshot of the IP's royalty vault and claims revenue on that snapshot for each
    /// specified currency token.
    /// @param ipId The address of the IP.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim.
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amounts of revenue claimed for each currency token.
    function snapshotAndClaimByTokenBatch(
        address ipId,
        address[] calldata currencyTokens
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed) {
        (snapshotId, amountsClaimed, ) = _snapshotAndClaimByTokenBatch(ipId, currencyTokens);
    }

    /// @notice Takes a snapshot of the IP's royalty vault and claims revenue for each specified currency token
    /// both on the new snapshot and on each specified unclaimed snapshot.
    /// @param ipId The address of the IP.
    /// @param unclaimedSnapshotIds The IDs of unclaimed snapshots to include in the claim.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim.
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amounts of revenue claimed for each currency token.
    function snapshotAndClaimBySnapshotBatch(
        address ipId,
        uint256[] calldata unclaimedSnapshotIds,
        address[] calldata currencyTokens
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed) {
        // Claims revenue for each specified currency token from the latest snapshot
        IIpRoyaltyVault ipRoyaltyVault;
        (snapshotId, amountsClaimed, ipRoyaltyVault) = _snapshotAndClaimByTokenBatch(ipId, currencyTokens);

        // Claims revenue for each specified currency token from the unclaimed snapshots
        uint256 length = currencyTokens.length;
        for (uint256 i = 0; i < length; i++) {
            amountsClaimed[i] += ipRoyaltyVault.claimRevenueOnBehalfBySnapshotBatch({
                snapshotIds: unclaimedSnapshotIds,
                token: currencyTokens[i],
                claimer: address(ipRoyaltyVault)
            });
        }
    }

    /// @dev Transfers royalties to the ancestor IP's royalty vault, takes a snapshot, and claims revenue for each
    /// specified currency token.
    /// @param ancestorIpId The address of the ancestor IP.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim (each address must be unique).
    /// @param royaltyClaimDetails The details of the royalty claim from child IPs.
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amounts of revenue claimed for each currency token.
    /// @return ancestorIpRoyaltyVault The ancestor IP's royalty vault.
    function _transferToVaultAndSnapshotAndClaimByTokenBatch(
        address ancestorIpId,
        address[] calldata currencyTokens,
        RoyaltyClaimDetails[] calldata royaltyClaimDetails
    ) private returns (uint256 snapshotId, uint256[] memory amountsClaimed, IIpRoyaltyVault ancestorIpRoyaltyVault) {
        // Transfers to ancestor's vault an amount of revenue tokens claimable via the given royalty policy
        uint256 length = royaltyClaimDetails.length;
        for (uint256 i = 0; i < length; i++) {
            IGraphAwareRoyaltyPolicy(royaltyClaimDetails[i].royaltyPolicy).transferToVault({
                ipId: royaltyClaimDetails[i].childIpId,
                ancestorIpId: ancestorIpId,
                token: royaltyClaimDetails[i].currencyToken,
                amount: royaltyClaimDetails[i].amount
            });
        }

        // Gets the ancestor IP's royalty vault
        ancestorIpRoyaltyVault = IIpRoyaltyVault(ROYALTY_MODULE.ipRoyaltyVaults(ancestorIpId));

        // Takes a snapshot of the ancestor IP's royalty vault
        snapshotId = ancestorIpRoyaltyVault.snapshot();

        // Claims revenue for each specified currency token
        amountsClaimed = ancestorIpRoyaltyVault.claimRevenueOnBehalfByTokenBatch({
            snapshotId: snapshotId,
            tokenList: currencyTokens,
            claimer: ancestorIpId
        });
    }

    /// @dev Takes a snapshot of the IP's royalty vault and claims revenue for each specified currency token.
    /// @param ipId The address of the IP.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to claim (each address must be unique).
    /// @return snapshotId The ID of the snapshot taken.
    /// @return amountsClaimed The amounts of revenue claimed for each currency token.
    /// @return ipRoyaltyVault The IP's royalty vault.
    function _snapshotAndClaimByTokenBatch(
        address ipId,
        address[] calldata currencyTokens
    ) private returns (uint256 snapshotId, uint256[] memory amountsClaimed, IIpRoyaltyVault ipRoyaltyVault) {
        // Gets the IP's royalty vault
        ipRoyaltyVault = IIpRoyaltyVault(ROYALTY_MODULE.ipRoyaltyVaults(ipId));

        // Claims revenue for each specified currency token from the latest snapshot
        snapshotId = ipRoyaltyVault.snapshot();
        amountsClaimed = ipRoyaltyVault.claimRevenueOnBehalfByTokenBatch({
            snapshotId: snapshotId,
            tokenList: currencyTokens,
            claimer: address(ipRoyaltyVault)
        });
    }

    //
    // Upgrade
    //

    /// @dev Returns the storage struct of RoyaltyWorkflows.
    function _getRoyaltyWorkflowsStorage() private pure returns (RoyaltyWorkflowsStorage storage $) {
        assembly {
            $.slot := RoyaltyWorkflowsStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
