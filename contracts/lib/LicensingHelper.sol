// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";

import { WorkflowStructs } from "./WorkflowStructs.sol";

/// @title Periphery Licensing Helper Library
/// @notice Library for all licensing related helper functions for Periphery contracts.
library LicensingHelper {
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
        try ILicensingModule(licensingModule).attachLicenseTerms(ipId, licenseTemplate, licenseTermsId) {
            // license terms are attached successfully, now we set the licensing config
            ILicensingModule(licensingModule).setLicensingConfig(
                ipId,
                licenseTemplate,
                licenseTermsId,
                licensingConfig
            );
        } catch (bytes memory reason) {
            // if the error is not that the license terms are already attached, revert with the original error
            if (CoreErrors.LicenseRegistry__LicenseTermsAlreadyAttached.selector != bytes4(reason)) {
                assembly {
                    revert(add(reason, 32), mload(reason))
                }
            }
        }
    }
}
