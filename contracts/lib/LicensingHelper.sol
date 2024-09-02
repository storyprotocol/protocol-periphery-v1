// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { ILicensingHook } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingHook.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/ILicenseTemplate.sol";
import { IPILicenseTemplate, PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { Errors } from "./Errors.sol";

/// @title Periphery Licensing Helper Library
/// @notice Library for all licensing related helper functions for Periphery contracts.
library LicensingHelper {
    using SafeERC20 for IERC20;

    /// @dev Registers PIL License Terms and attaches them to the given IP.
    /// @param ipId The ID of the IP.
    /// @param pilTemplate The address of the PIL License Template.
    /// @param licensingModule The address of the Licensing Module.
    /// @param licenseRegistry The address of the License Registry.
    /// @param terms The PIL terms to be registered.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerPILTermsAndAttach(
        address ipId,
        address pilTemplate,
        address licensingModule,
        address licenseRegistry,
        PILTerms calldata terms
    ) internal returns (uint256 licenseTermsId) {
        licenseTermsId = IPILicenseTemplate(pilTemplate).registerLicenseTerms(terms);

        // Returns the license terms ID if already attached.
        if (ILicenseRegistry(licenseRegistry).hasIpAttachedLicenseTerms(ipId, pilTemplate, licenseTermsId))
            return licenseTermsId;

        ILicensingModule(licensingModule).attachLicenseTerms(ipId, pilTemplate, licenseTermsId);
    }

    /// @dev Collects license tokens from the caller. Assumes the periphery contract has permission to transfer the license tokens.
    /// @param licenseTokenIds The IDs of the license tokens to be collected.
    /// @param licenseToken The address of the license token contract.
    function collectLicenseTokens(uint256[] calldata licenseTokenIds, address licenseToken) internal {
        if (licenseTokenIds.length == 0) revert Errors.SPG__EmptyLicenseTokens();
        for (uint256 i = 0; i < licenseTokenIds.length; i++) {
            address tokenOwner = ILicenseToken(licenseToken).ownerOf(licenseTokenIds[i]);

            if (tokenOwner == address(this)) continue;
            if (tokenOwner != address(msg.sender))
                revert Errors.SPG__CallerAndNotTokenOwner(licenseTokenIds[i], msg.sender, tokenOwner);

            ILicenseToken(licenseToken).safeTransferFrom(msg.sender, address(this), licenseTokenIds[i]);
        }
    }

    /// @dev Collect mint fees for all parent IPs from the payer and set approval for Royalty Module to spend mint fees.
    /// @param payerAddress The address of the payer for the license mint fees.
    /// @param childIpId The ID of the derivative IP.
    /// @param royaltyModule The address of the Royalty Module.
    /// @param licenseRegistry The address of the License Registry.
    /// @param licenseTemplate The address of the license template.
    /// @param parentIpIds The IDs of all the parent IPs.
    /// @param licenseTermsIds The IDs of the license terms for each corresponding parent IP.
    function collectMintFeesAndSetApproval(
        address payerAddress,
        address childIpId,
        address royaltyModule,
        address licenseRegistry,
        address licenseTemplate,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds
    ) internal {
        // Get currency token and royalty policy, assumes all parent IPs have the same currency token.
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        (address royaltyPolicy, , , address mintFeeCurrencyToken) = lct.getRoyaltyPolicy(licenseTermsIds[0]);

        if (royaltyPolicy != address(0)) {
            // Get total mint fee for all parent IPs
            uint256 totalMintFee = aggregateMintFees({
                childIpId: childIpId,
                licenseTemplate: licenseTemplate,
                licenseRegistry: licenseRegistry,
                parentIpIds: parentIpIds,
                licenseTermsIds: licenseTermsIds
            });

            if (totalMintFee != 0) {
                // Transfer mint fee from payer to this contract
                IERC20(mintFeeCurrencyToken).safeTransferFrom(payerAddress, address(this), totalMintFee);

                // Approve Royalty Policy to spend mint fee
                IERC20(mintFeeCurrencyToken).forceApprove(royaltyModule, totalMintFee);
            }
        }
    }

    /// @dev Aggregate license mint fees for all parent IPs.
    /// @param childIpId The ID of the derivative IP.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseRegistry The address of the License Registry.
    /// @param parentIpIds The IDs of all the parent IPs.
    /// @param licenseTermsIds The IDs of the license terms for each corresponding parent IP.
    /// @return totalMintFee The sum of license mint fees across all parent IPs.
    function aggregateMintFees(
        address childIpId,
        address licenseTemplate,
        address licenseRegistry,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds
    ) internal returns (uint256 totalMintFee) {
        totalMintFee = 0;

        for (uint256 i = 0; i < parentIpIds.length; i++) {
            totalMintFee += getMintFeeForSingleParent({
                childIpId: childIpId,
                parentIpId: parentIpIds[i],
                licenseTemplate: licenseTemplate,
                licenseRegistry: licenseRegistry,
                amount: 1,
                licenseTermsId: licenseTermsIds[i]
            });
        }
    }

    /// @dev Fetch the license token mint fee from the licensing hook or license terms for the given parent IP.
    /// @param childIpId The ID of the derivative IP.
    /// @param parentIpId The ID of the parent IP.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseRegistry The address of the License Registry.
    /// @param amount The amount of licenses to mint.
    /// @param licenseTermsId The ID of the license terms for the parent IP.
    /// @return The mint fee for the given parent IP.
    function getMintFeeForSingleParent(
        address childIpId,
        address parentIpId,
        address licenseTemplate,
        address licenseRegistry,
        uint256 amount,
        uint256 licenseTermsId
    ) internal returns (uint256) {
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);

        // Get mint fee set by license terms
        (address royaltyPolicy, , uint256 mintFeeSetByLicenseTerms, ) = lct.getRoyaltyPolicy(licenseTermsId);

        // If no royalty policy, return 0
        if (royaltyPolicy == address(0)) return 0;

        uint256 mintFeeSetByHook = 0;

        Licensing.LicensingConfig memory licensingConfig = ILicenseRegistry(licenseRegistry).getLicensingConfig({
            ipId: parentIpId,
            licenseTemplate: licenseTemplate,
            licenseTermsId: licenseTermsId
        });

        // Get mint fee from licensing hook
        if (licensingConfig.licensingHook != address(0)) {
            mintFeeSetByHook = ILicensingHook(licensingConfig.licensingHook).beforeRegisterDerivative({
                caller: address(this),
                childIpId: childIpId,
                parentIpId: parentIpId,
                licenseTemplate: licenseTemplate,
                licenseTermsId: licenseTermsId,
                hookData: licensingConfig.hookData
            });
        }

        if (!licensingConfig.isSet) return mintFeeSetByLicenseTerms * amount;
        if (licensingConfig.licensingHook == address(0)) return licensingConfig.mintingFee * amount;

        return mintFeeSetByHook;
    }
}
