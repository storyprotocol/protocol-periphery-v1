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
import { WorkflowStructs } from "../lib/WorkflowStructs.sol";

/// @title Royalty Workflows
/// @notice Each workflow bundles multiple core protocol operations into a single function to enable one-click
/// IP revenue claiming in the Story Proof-of-Creativity Protocol.
contract RoyaltyWorkflows is IRoyaltyWorkflows, MulticallUpgradeable, AccessManagedUpgradeable, UUPSUpgradeable {
    using ERC165Checker for address;

    /// @notice The address of the Royalty Module.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
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
        __Multicall_init();
    }

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
    ) external returns (uint256[] memory amountsClaimed) {
        for (uint256 i = 0; i < claimRevenueData.length; i++) {
            // Transfer all available revenue tokens to the ancestor's vault
            try
                IGraphAwareRoyaltyPolicy(claimRevenueData[i].royaltyPolicy).transferToVault({
                    ipId: claimRevenueData[i].childIpId,
                    ancestorIpId: ancestorIpId,
                    token: claimRevenueData[i].currencyToken
                })
            {} catch (bytes memory reason) {
                // If the error is not that the royalty policy has no claimable royalty, revert with the original error
                if (
                    CoreErrors.RoyaltyPolicyLAP__ZeroClaimableRoyalty.selector != bytes4(reason) &&
                    CoreErrors.RoyaltyPolicyLRP__ZeroClaimableRoyalty.selector != bytes4(reason)
                ) {
                    assembly {
                        revert(add(reason, 32), mload(reason))
                    }
                }
            }
        }

        // Gets the ancestor IP's royalty vault
        IIpRoyaltyVault ancestorIpRoyaltyVault = IIpRoyaltyVault(ROYALTY_MODULE.ipRoyaltyVaults(ancestorIpId));

        // Claims revenue for each specified currency token
        amountsClaimed = ancestorIpRoyaltyVault.claimRevenueOnBehalfByTokenBatch({
            claimer: claimer,
            tokenList: _getUniqueCurrencyTokens(claimRevenueData)
        });
    }

    /// @notice Returns an array of unique currency token addresses, filtering out duplicates.
    /// @param claimRevenueData The data for claiming revenue from each child IP.
    /// @return uniqueCurrencyTokens An array containing only unique currency token addresses.
    function _getUniqueCurrencyTokens(
        WorkflowStructs.ClaimRevenueData[] calldata claimRevenueData
    ) internal pure returns (address[] memory uniqueCurrencyTokens) {
        uint256 length = claimRevenueData.length;
        address[] memory tempUniqueTokenList = new address[](length);
        uint256 uniqueCount = 0;

        for (uint256 i = 0; i < length; i++) {
            address currencyToken = claimRevenueData[i].currencyToken;
            bool isDuplicate = false;

            // Check if `currencyToken` already exists in `tempUniqueTokenList`
            for (uint256 j = 0; j < uniqueCount; j++) {
                if (tempUniqueTokenList[j] == currencyToken) {
                    isDuplicate = true;
                    break;
                }
            }

            // Add `currencyToken` to `tempUniqueTokenList` if it's unique
            if (!isDuplicate) {
                tempUniqueTokenList[uniqueCount] = currencyToken;
                uniqueCount++;
            }
        }

        // Populate `uniqueCurrencyTokens` array with unique tokens
        uniqueCurrencyTokens = new address[](uniqueCount);
        for (uint256 i = 0; i < uniqueCount; i++) {
            uniqueCurrencyTokens[i] = tempUniqueTokenList[i];
        }
    }

    //
    // Upgrade
    //

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

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
    ) external returns (uint256[] memory amountsClaimed) {
        for (uint256 i = 0; i < childIpIds.length; i++) {
            try
                IGraphAwareRoyaltyPolicy(royaltyPolicies[i]).transferToVault({
                    ipId: childIpIds[i],
                    ancestorIpId: ancestorIpId,
                    token: currencyTokens[i]
                })
            {} catch (bytes memory reason) {
                // If the error is not that the royalty policy has no claimable royalty, revert with the original error
                if (
                    CoreErrors.RoyaltyPolicyLAP__ZeroClaimableRoyalty.selector != bytes4(reason) &&
                    CoreErrors.RoyaltyPolicyLRP__ZeroClaimableRoyalty.selector != bytes4(reason)
                ) {
                    assembly {
                        revert(add(reason, 32), mload(reason))
                    }
                }
            }
        }

        // Gets the ancestor IP's royalty vault
        IIpRoyaltyVault ancestorIpRoyaltyVault = IIpRoyaltyVault(ROYALTY_MODULE.ipRoyaltyVaults(ancestorIpId));

        // Claims revenue for each specified currency token
        amountsClaimed = ancestorIpRoyaltyVault.claimRevenueOnBehalfByTokenBatch({
            claimer: claimer,
            tokenList: _getUniqueCurrencyTokens(currencyTokens)
        });
    }

      /// @notice Returns an array of unique currency token addresses, filtering out duplicates.
    /// @param currencyTokens The addresses of the currency (revenue) tokens to filter.
    /// @return uniqueCurrencyTokens An array containing only unique currency token addresses.
    function _getUniqueCurrencyTokens(
        address[] calldata currencyTokens
    ) internal pure returns (address[] memory uniqueCurrencyTokens) {
        uint256 length = currencyTokens.length;
        address[] memory tempUniqueTokenList = new address[](length);
        uint256 uniqueCount = 0;

        for (uint256 i = 0; i < length; i++) {
            address currencyToken = currencyTokens[i];
            bool isDuplicate = false;

            // Check if `currencyToken` already exists in `tempUniqueTokenList`
            for (uint256 j = 0; j < uniqueCount; j++) {
                if (tempUniqueTokenList[j] == currencyToken) {
                    isDuplicate = true;
                    break;
                }
            }

            // Add `currencyToken` to `tempUniqueTokenList` if it's unique
            if (!isDuplicate) {
                tempUniqueTokenList[uniqueCount] = currencyToken;
                uniqueCount++;
            }
        }

        // Populate `uniqueCurrencyTokens` array with unique tokens
        uniqueCurrencyTokens = new address[](uniqueCount);
        for (uint256 i = 0; i < uniqueCount; i++) {
            uniqueCurrencyTokens[i] = tempUniqueTokenList[i];
        }
    }
}
