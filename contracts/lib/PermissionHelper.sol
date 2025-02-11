// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";

import { WorkflowStructs } from "./WorkflowStructs.sol";

/// @title Periphery Permission Helper Library
/// @notice Library for all permissions related helper functions for Periphery contracts.
library PermissionHelper {
    /// @notice Error for when the length of modules and selectors mismatch.
    error PermissionHelper__ModulesAndSelectorsMismatch();

    /// @dev Sets transient permission via signature to allow this contract to interact with the Licensing Module on behalf of the
    /// provided IP Account.
    /// @param ipId The ID of the IP.
    /// @param module The address of the module to set the permission for.
    /// @param accessController The address of the Access Controller contract.
    /// @param selector The selector of the function to be permitted for execution.
    /// @param sigData Signature data for setting the permission.
    function setTransientPermissionForModule(
        address ipId,
        address module,
        address accessController,
        bytes4 selector,
        WorkflowStructs.SignatureData calldata sigData
    ) internal {
        IIPAccount(payable(ipId)).executeWithSig(
            accessController,
            0,
            abi.encodeWithSelector(
                IAccessController.setTransientPermission.selector,
                address(ipId),
                address(this),
                address(module),
                selector,
                AccessPermission.ALLOW
            ),
            sigData.signer,
            sigData.deadline,
            sigData.signature
        );
    }

    /// @dev Sets batch transient permission via signature to allow this contract to interact with multiple modules
    /// on behalf of the provided IP Account.
    /// @param ipId The ID of the IP.
    /// @param accessController The address of the Access Controller contract.
    /// @param modules The addresses of the modules to set the permission for.
    /// @param selectors The selectors of the functions to be permitted for execution.
    /// @param sigData Signature data for setting the batch permission.
    function setBatchTransientPermissionForModules(
        address ipId,
        address accessController,
        address[] memory modules,
        bytes4[] memory selectors,
        WorkflowStructs.SignatureData calldata sigData
    ) internal {
        if (modules.length != selectors.length) revert PermissionHelper__ModulesAndSelectorsMismatch();

        AccessPermission.Permission[] memory permissionList = new AccessPermission.Permission[](modules.length);
        for (uint256 i = 0; i < modules.length; i++) {
            permissionList[i] = AccessPermission.Permission({
                ipAccount: ipId,
                signer: address(this),
                to: modules[i],
                func: selectors[i],
                permission: AccessPermission.ALLOW
            });
        }

        IIPAccount(payable(ipId)).executeWithSig(
            accessController,
            0,
            abi.encodeWithSelector(IAccessController.setBatchTransientPermissions.selector, permissionList),
            sigData.signer,
            sigData.deadline,
            sigData.signature
        );
    }
}
