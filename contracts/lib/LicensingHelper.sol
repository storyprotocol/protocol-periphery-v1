// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Errors as CoreErrors } from "@storyprotocol/core/lib/Errors.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate, PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { WorkflowStructs } from "../lib/WorkflowStructs.sol";

/// @title Periphery Licensing Helper Library
/// @notice Library for all licensing related helper functions for Periphery contracts.
library LicensingHelper {
    /// @dev Registers PIL License Terms and attaches them to the given IP.
    /// @param ipId The ID of the IP.
    /// @param pilTemplate The address of the PIL License Template.
    /// @param licensingModule The address of the Licensing Module.
    /// @param terms The PIL terms to be registered.
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

    /// @dev Attaches license terms to the given IP.
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

    /// @dev Registers PIL License Terms and attaches them to the given IP on behalf of the owner with a signature.
    /// @param ipId The ID of the IP to which the license terms will be attached.
    /// @param pilTemplate The address of the PIL License Template.
    /// @param licensingModule The address of the Licensing Module.
    /// @param terms The PIL terms to be registered.
    /// @param sigAttach Signature data for attachLicenseTerms to the IP via the Licensing Module.
    /// @return licenseTermsId The ID of the registered PIL terms.
    function registerPILTermsAndAttachWithSig(
        address ipId,
        address pilTemplate,
        address licensingModule,
        PILTerms calldata terms,
        WorkflowStructs.SignatureData memory sigAttach
    ) internal returns (uint256 licenseTermsId) {
        licenseTermsId = IPILicenseTemplate(pilTemplate).registerLicenseTerms(terms);
        attachLicenseTermsWithSig(ipId, licensingModule, pilTemplate, licenseTermsId, sigAttach);
    }

    /// @dev Attaches license terms to the given IP on behalf of the owner with a signature.
    /// @param ipId The ID of the IP to which the license terms will be attached.
    /// @param licensingModule The address of the Licensing Module.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms to be attached.
    /// @param sigAttach Signature data for attachLicenseTerms to the IP via the Licensing Module.
    function attachLicenseTermsWithSig(
        address ipId,
        address licensingModule,
        address licenseTemplate,
        uint256 licenseTermsId,
        WorkflowStructs.SignatureData memory sigAttach
    ) internal {
        try
            IIPAccount(payable(ipId)).executeWithSig({
                to: address(licensingModule),
                value: 0,
                data: abi.encodeWithSelector(
                    ILicensingModule.attachLicenseTerms.selector,
                    ipId,
                    licenseTemplate,
                    licenseTermsId
                ),
                signer: sigAttach.signer,
                deadline: sigAttach.deadline,
                signature: sigAttach.signature
            })
        {
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
