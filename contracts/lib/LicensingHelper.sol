// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate, PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

/// @title Periphery Licensing Helper Library
/// @notice Library for all licensing related helper functions for Periphery contracts.
library LicensingHelper {
    /// @dev Registers PIL License Terms and attaches them to the given IP.
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
        PILTerms[] calldata terms
    ) internal returns (uint256[] memory licenseTermsIds) {
        licenseTermsIds = new uint256[](terms.length);
        for (uint256 i = 0; i < terms.length; i++) {
            licenseTermsIds[i] = IPILicenseTemplate(pilTemplate).registerLicenseTerms(terms[i]);
            attachLicenseTerms(ipId, licensingModule, licenseRegistry, pilTemplate, licenseTermsIds[i]);
        }
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
}
