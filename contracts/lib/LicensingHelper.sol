// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/ILicenseTemplate.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { WorkflowStructs } from "./WorkflowStructs.sol";

/// @title Periphery Licensing Helper Library
/// @notice Library for all licensing related helper functions for Periphery contracts.
library LicensingHelper {
    using SafeERC20 for IERC20;

    /// @dev Registers PIL License Terms and attaches them to the given IP.
    /// @param ipId The ID of the IP.
    /// @param pilTemplate The address of the PIL License Template.
    /// @param licensingModule The address of the Licensing Module.
    /// @param terms The PIL terms to be attached to the IP.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerPILTermsAndAttach(
        address ipId,
        address pilTemplate,
        address licensingModule,
        PILTerms memory terms
    ) internal returns (uint256 licenseTermsId) {
        licenseTermsId = IPILicenseTemplate(pilTemplate).registerLicenseTerms(terms);
        attachLicenseTerms(ipId, licensingModule, pilTemplate, licenseTermsId);
    }

    /// @dev Attaches license terms to the given IP, does nothing if the license terms are already attached.
    /// @param ipId The ID of the IP.
    /// @param licensingModule The address of the Licensing Module.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms to be attached.
    function attachLicenseTerms(
        address ipId,
        address licensingModule,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal {
        try ILicensingModule(licensingModule).attachLicenseTerms(ipId, licenseTemplate, licenseTermsId) {
            // license terms are attached successfully.
            return;
        } catch (bytes memory reason) {
            // if the error is not that the license terms are already attached, revert with the original error
            if (CoreErrors.LicenseRegistry__LicenseTermsAlreadyAttached.selector != bytes4(reason)) {
                assembly {
                    revert(add(reason, 32), mload(reason))
                }
            }
        }
    }

    /// @dev Registers PIL License Terms and attaches them to the given IP and sets their licensing configurations.
    /// @param ipId The ID of the IP.
    /// @param pilTemplate The address of the PIL License Template.
    /// @param licensingModule The address of the Licensing Module.
    /// @param licenseTermsData The PIL terms and licensing configuration data to be attached to the IP.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerPILTermsAndAttachAndSetConfigs(
        address ipId,
        address pilTemplate,
        address licensingModule,
        WorkflowStructs.LicenseTermsData memory licenseTermsData
    ) internal returns (uint256 licenseTermsId) {
        licenseTermsId = IPILicenseTemplate(pilTemplate).registerLicenseTerms(licenseTermsData.terms);
        attachLicenseTermsAndSetConfigs(
            ipId,
            licensingModule,
            pilTemplate,
            licenseTermsId,
            licenseTermsData.licensingConfig
        );
    }

    /// @dev Attaches license terms to the given IP and sets their licensing configurations.
    /// @param ipId The ID of the IP.
    /// @param licensingModule The address of the Licensing Module.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms to be attached.
    /// @param licensingConfig The licensing configuration for the license terms.
    function attachLicenseTermsAndSetConfigs(
        address ipId,
        address licensingModule,
        address licenseTemplate,
        uint256 licenseTermsId,
        Licensing.LicensingConfig memory licensingConfig
    ) internal {
        attachLicenseTerms(ipId, licensingModule, licenseTemplate, licenseTermsId);
        ILicensingModule(licensingModule).setLicensingConfig(ipId, licenseTemplate, licenseTermsId, licensingConfig);
    }

    /// @dev Collects mint fees and registers a derivative.
    /// @param childIpId The ID of the child IP.
    /// @param royaltyModule The address of the Royalty Module.
    /// @param licensingModule The address of the Licensing Module.
    /// @param derivData The derivative data to be used for registerDerivative.
    function collectMintFeesAndMakeDerivative(
        address childIpId,
        address royaltyModule,
        address licensingModule,
        WorkflowStructs.MakeDerivative calldata derivData
    ) internal {
        collectMintFeesAndSetApproval(
            msg.sender,
            royaltyModule,
            licensingModule,
            derivData.licenseTemplate,
            derivData.parentIpIds,
            derivData.licenseTermsIds
        );

        ILicensingModule(licensingModule).registerDerivative({
            childIpId: childIpId,
            parentIpIds: derivData.parentIpIds,
            licenseTermsIds: derivData.licenseTermsIds,
            licenseTemplate: derivData.licenseTemplate,
            royaltyContext: derivData.royaltyContext,
            maxMintingFee: derivData.maxMintingFee,
            maxRts: derivData.maxRts
        });
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
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds
    ) private {
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
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds
    ) private view returns (uint256 totalMintFee) {
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
