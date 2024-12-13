// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
import { ILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/ILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate, PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

/// @title Periphery Licensing Helper Library
/// @notice Library for all licensing related helper functions for Periphery contracts.
library LicensingHelper {
    using SafeERC20 for IERC20;

    /// @dev Registers multiple PIL License Terms and attaches them to the given IP.
    /// @param ipId The ID of the IP.
    /// @param pilTemplate The address of the PIL License Template.
    /// @param licensingModule The address of the Licensing Module.
    /// @param licenseRegistry The address of the License Registry.
    /// @param terms The PIL terms to be registered.
    /// @return licenseTermsIds The IDs of the registered PIL terms.
    function registerPILTermsAndAttach(
        address ipId,
        address pilTemplate,
        address licensingModule,
        address licenseRegistry,
        PILTerms[] memory terms
    ) internal returns (uint256[] memory licenseTermsIds) {
        licenseTermsIds = new uint256[](terms.length);
        for (uint256 i = 0; i < terms.length; i++) {
            licenseTermsIds[i] = registerPILTermsAndAttach(
                ipId,
                pilTemplate,
                licensingModule,
                licenseRegistry,
                terms[i]
            );
        }
    }

    /// @dev Registers a single PIL License and attaches it to the given IP.
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
        PILTerms memory terms
    ) internal returns (uint256 licenseTermsId) {
        licenseTermsId = IPILicenseTemplate(pilTemplate).registerLicenseTerms(terms);
        attachLicenseTerms(ipId, licensingModule, licenseRegistry, pilTemplate, licenseTermsId);
    }

    /// @dev Attaches license terms to the given IP.
    /// @param ipId The ID of the IP.
    /// @param licensingModule The address of the Licensing Module.
    /// @param licenseRegistry The address of the License Registry.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms to be attached.
    function attachLicenseTerms(
        address ipId,
        address licensingModule,
        address licenseRegistry,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal {
        try ILicensingModule(licensingModule).attachLicenseTerms(ipId, licenseTemplate, licenseTermsId) {
            return; // license terms are attached successfully
        } catch (bytes memory reason) {
            // if the error is not that the license terms are already attached, revert with the original error
            if (CoreErrors.LicenseRegistry__LicenseTermsAlreadyAttached.selector != bytes4(reason)) {
                assembly {
                    revert(add(reason, 32), mload(reason))
                }
            }
        }
    }

    /// @dev Collect mint fees for all parent IPs from the payer and set approval for Royalty Module to spend mint fees.
    /// @param payerAddress The address of the payer for the license mint fees.
    /// @param royaltyModule The address of the Royalty Module.
    /// @param licensingModule The address of the Licensing Module.
    /// @param licenseTemplate The address of the license template.
    /// @param parentIpIds The IDs of all the parent IPs.
    /// @param licenseTermsIds The IDs of the license terms for each corresponding parent IP.
    function collectMintFeesAndSetApproval(
        address payerAddress,
        address royaltyModule,
        address licensingModule,
        address licenseTemplate,
        address[] memory parentIpIds,
        uint256[] memory licenseTermsIds
    ) internal {
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        (address royaltyPolicy, , , address mintFeeCurrencyToken) = lct.getRoyaltyPolicy(licenseTermsIds[0]);

        if (royaltyPolicy != address(0)) {
            // Get total mint fee for all parent IPs
            uint256 totalMintFee = aggregateMintFees({
                payerAddress: payerAddress,
                licensingModule: licensingModule,
                licenseTemplate: licenseTemplate,
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
    /// @param payerAddress The address of the payer for the license mint fees.
    /// @param licensingModule The address of the Licensing Module.
    /// @param licenseTemplate The address of the license template.
    /// @param parentIpIds The IDs of all the parent IPs.
    /// @param licenseTermsIds The IDs of the license terms for each corresponding parent IP.
    /// @return totalMintFee The sum of license mint fees across all parent IPs.
    function aggregateMintFees(
        address payerAddress,
        address licensingModule,
        address licenseTemplate,
        address[] memory parentIpIds,
        uint256[] memory licenseTermsIds
    ) internal view returns (uint256 totalMintFee) {
        uint256 mintFee;

        for (uint256 i = 0; i < parentIpIds.length; i++) {
            (, mintFee) = ILicensingModule(licensingModule).predictMintingLicenseFee({
                licensorIpId: parentIpIds[i],
                licenseTemplate: licenseTemplate,
                licenseTermsId: licenseTermsIds[i],
                amount: 1,
                receiver: payerAddress,
                royaltyContext: ""
            });
            totalMintFee += mintFee;
        }
    }
}
