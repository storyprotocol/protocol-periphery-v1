// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Test } from "forge-std/Test.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MetaTx } from "@storyprotocol/core/lib/MetaTx.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { ICoreMetadataViewModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataViewModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";

// contracts
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

contract TestHelper is Test {
    using MessageHashUtils for bytes32;

    uint256 internal constant _ERC6551_STATE_SLOT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffb919c7a5;

    address private _accessControllerAddr;
    address private _licensingModuleAddr;
    address private _coreMetadataModuleAddr;

    ICoreMetadataViewModule private _coreMetadataViewModule;
    ILicenseRegistry private _licenseRegistry;

    constructor() {}

    function _initializeTestHelper(
        address accessControllerAddr,
        address coreMetadataModuleAddr,
        address coreMetadataViewModuleAddr,
        address licenseRegistryAddr,
        address licensingModuleAddr
    ) internal {
        _accessControllerAddr = accessControllerAddr;
        _coreMetadataModuleAddr = coreMetadataModuleAddr;
        _licensingModuleAddr = licensingModuleAddr;

        _coreMetadataViewModule = ICoreMetadataViewModule(coreMetadataViewModuleAddr);
        _licenseRegistry = ILicenseRegistry(licenseRegistryAddr);
    }

    /// @dev Get the permission list for setting metadata and registering a derivative for the IP.
    /// @param ipId The ID of the IP that the permissions are for.
    /// @param to The address of the periphery contract to receive the permission.
    /// @param withLicenseToken Whether to use license tokens for the derivative registration.
    /// @return permissionList The list of permissions for setting metadata and registering a derivative.
    function _getMetadataAndDerivativeRegistrationPermissionList(
        address ipId,
        address to,
        bool withLicenseToken
    ) internal view returns (AccessPermission.Permission[] memory permissionList) {
        address[] memory modules = new address[](2);
        bytes4[] memory selectors = new bytes4[](2);
        permissionList = new AccessPermission.Permission[](2);
        modules[0] = _coreMetadataModuleAddr;
        modules[1] = _licensingModuleAddr;
        selectors[0] = ICoreMetadataModule.setAll.selector;
        if (withLicenseToken) {
            selectors[1] = ILicensingModule.registerDerivativeWithLicenseTokens.selector;
        } else {
            selectors[1] = ILicensingModule.registerDerivative.selector;
        }
        for (uint256 i = 0; i < 2; i++) {
            permissionList[i] = AccessPermission.Permission({
                ipAccount: ipId,
                signer: to,
                to: modules[i],
                func: selectors[i],
                permission: AccessPermission.ALLOW
            });
        }
    }

    /// @dev Get the permission list for setting metadata and attaching default license terms for the IP.
    /// @param ipId The ID of the IP that the permissions are for.
    /// @param to The address of the periphery contract to receive the permission.
    /// @return permissionList The list of permissions for setting metadata and attaching default license terms.
    function _getMetadataAndDefaultTermsPermissionList(
        address ipId,
        address to
    ) internal view returns (AccessPermission.Permission[] memory permissionList) {
        address[] memory modules = new address[](2);
        bytes4[] memory selectors = new bytes4[](2);
        permissionList = new AccessPermission.Permission[](2);
        modules[0] = _coreMetadataModuleAddr;
        modules[1] = _licensingModuleAddr;
        selectors[0] = ICoreMetadataModule.setAll.selector;
        selectors[1] = ILicensingModule.attachDefaultLicenseTerms.selector;
        for (uint256 i = 0; i < 2; i++) {
            permissionList[i] = AccessPermission.Permission({
                ipAccount: ipId,
                signer: to,
                to: modules[i],
                func: selectors[i],
                permission: AccessPermission.ALLOW
            });
        }
    }

    /// @dev Get the permission list for attaching license terms and setting licensing config for the IP.
    /// @param ipId The ID of the IP that the permissions are for.
    /// @param to The address of the periphery contract to receive the permission.
    /// @return permissionList The list of permissions for attaching license terms and setting licensing config.
    function _getAttachTermsAndConfigPermissionList(
        address ipId,
        address to
    ) internal view returns (AccessPermission.Permission[] memory permissionList) {
        address[] memory modules = new address[](2);
        bytes4[] memory selectors = new bytes4[](2);
        permissionList = new AccessPermission.Permission[](2);
        modules[0] = _licensingModuleAddr;
        modules[1] = _licensingModuleAddr;
        selectors[0] = ILicensingModule.attachLicenseTerms.selector;
        selectors[1] = ILicensingModule.setLicensingConfig.selector;
        for (uint256 i = 0; i < 2; i++) {
            permissionList[i] = AccessPermission.Permission({
                ipAccount: ipId,
                signer: to,
                to: modules[i],
                func: selectors[i],
                permission: AccessPermission.ALLOW
            });
        }
    }

    /// @dev Get the permission list for setting metadata and attaching license terms for the IP.
    /// @param ipId The ID of the IP that the permissions are for.
    /// @param to The address of the periphery contract to receive the permission.
    /// @return permissionList The list of permissions for setting metadata, attaching license terms, and
    /// setting licensing config.
    function _getMetadataAndAttachTermsAndConfigPermissionList(
        address ipId,
        address to
    ) internal view returns (AccessPermission.Permission[] memory permissionList) {
        address[] memory modules = new address[](3);
        bytes4[] memory selectors = new bytes4[](3);
        permissionList = new AccessPermission.Permission[](3);

        modules[0] = _coreMetadataModuleAddr;
        modules[1] = _licensingModuleAddr;
        modules[2] = _licensingModuleAddr;
        selectors[0] = ICoreMetadataModule.setAll.selector;
        selectors[1] = ILicensingModule.attachLicenseTerms.selector;
        selectors[2] = ILicensingModule.setLicensingConfig.selector;
        for (uint256 i = 0; i < 3; i++) {
            permissionList[i] = AccessPermission.Permission({
                ipAccount: ipId,
                signer: to,
                to: modules[i],
                func: selectors[i],
                permission: AccessPermission.ALLOW
            });
        }
    }

    /// @dev Get the signature for setting batch permission for the IP by the SPG.
    /// @param ipId The ID of the IP to set the permissions for.
    /// @param permissionList A list of permissions to set.
    /// @param deadline The deadline for the signature.
    /// @param state IPAccount's internal state
    /// @param signerSk The secret key of the signer.
    /// @return signature The signature for setting the batch permission.
    /// @return expectedState The expected IPAccount's state after setting batch permission.
    /// @return data The call data for executing the setBatchPermissions function.
    function _getSetBatchPermissionSigForPeriphery(
        address ipId,
        AccessPermission.Permission[] memory permissionList,
        uint256 deadline,
        bytes32 state,
        uint256 signerSk
    ) internal view returns (bytes memory signature, bytes32 expectedState, bytes memory data) {
        expectedState = keccak256(
            abi.encode(
                state, // ipAccount.state()
                abi.encodeWithSelector(
                    IIPAccount.execute.selector,
                    address(_accessControllerAddr),
                    0, // amount of ether to send
                    abi.encodeWithSelector(IAccessController.setBatchTransientPermissions.selector, permissionList)
                )
            )
        );

        data = abi.encodeWithSelector(IAccessController.setBatchTransientPermissions.selector, permissionList);

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(ipId),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(_accessControllerAddr),
                    value: 0,
                    data: data,
                    nonce: expectedState,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /// @dev Get the signature for setting permission for the IP by the SPG.
    /// @param ipId The ID of the IP.
    /// @param to The address of the periphery contract to receive the permission.
    /// @param module The address of the module to set the permission for.
    /// @param selector The selector of the function to be permitted for execution.
    /// @param deadline The deadline for the signature.
    /// @param state IPAccount's internal nonce
    /// @param signerSk The secret key of the signer.
    /// @return signature The signature for setting the permission.
    /// @return expectedState The expected IPAccount's state after setting the permission.
    /// @return data The call data for executing the setPermission function.
    function _getSetPermissionSigForPeriphery(
        address ipId,
        address to,
        address module,
        bytes4 selector,
        uint256 deadline,
        bytes32 state,
        uint256 signerSk
    ) internal view returns (bytes memory signature, bytes32 expectedState, bytes memory data) {
        expectedState = keccak256(
            abi.encode(
                state, // ipAccount.state()
                abi.encodeWithSelector(
                    IIPAccount.execute.selector,
                    address(_accessControllerAddr),
                    0, // amount of ether to send
                    abi.encodeWithSelector(
                        IAccessController.setTransientPermission.selector,
                        ipId,
                        to,
                        address(module),
                        selector,
                        AccessPermission.ALLOW
                    )
                )
            )
        );

        data = abi.encodeWithSelector(
            IAccessController.setTransientPermission.selector,
            ipId,
            to,
            address(module),
            selector,
            AccessPermission.ALLOW
        );

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(ipId),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(_accessControllerAddr),
                    value: 0,
                    data: data,
                    nonce: expectedState,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /// @dev Predicts the next state given the current state and the calldata of the next function call.
    /// @notice This function is based on Solady's ERC6551 implementation.
    /// see: https://github.com/Vectorized/solady/blob/724c39bdfebb593157c2dfa6797c07a25dfb564c/src/accounts/ERC6551.sol#L187
    /// @param currentState The current state value stored in _ERC6551_STATE_SLOT.
    /// @param nextCalldata The complete calldata of the next function call.
    /// @return nextState The predicted next state.
    function _predictNextState(
        address signer,
        address to,
        bytes32 currentState,
        bytes memory nextCalldata
    ) internal pure returns (bytes32 nextState) {
        nextState = keccak256(
            abi.encode(
                currentState,
                abi.encodeWithSelector(IIPAccount.updateStateForValidSigner.selector, signer, to, nextCalldata)
            )
        );
    }

    /// @dev Predicts the state after multiple function calls
    /// @param currentState The current state value
    /// @param calldataSequence Array of calldata for each function call in sequence
    /// @return The final predicted state
    function _predictStateSequence(
        bytes32 currentState,
        address[] memory signers,
        address[] memory tos,
        bytes[] memory calldataSequence
    ) internal pure returns (bytes32) {
        bytes32 state = currentState;
        for (uint256 i = 0; i < calldataSequence.length; i++) {
            state = _predictNextState(signers[i], tos[i], state, calldataSequence[i]);
        }
        return state;
    }

    /// @dev Uses `signerSk` to sign `recipient` and return the signature.
    function _signAddress(uint256 signerSk, address recipient) internal pure returns (bytes memory signature) {
        bytes32 digest = keccak256(abi.encodePacked(recipient)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /// @dev Uses `signerSk` to sign `recipient` and `badgeAddr` and return the signature.
    function _signAddress(
        uint256 signerSk,
        address recipient,
        address badgeAddr
    ) internal pure returns (bytes memory signature) {
        bytes32 digest = keccak256(abi.encodePacked(recipient, badgeAddr)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /// @dev Assert metadata for the IP.
    function assertMetadata(address ipId, WorkflowStructs.IPMetadata memory expectedMetadata) internal view {
        assertEq(_coreMetadataViewModule.getMetadataURI(ipId), expectedMetadata.ipMetadataURI);
        assertEq(_coreMetadataViewModule.getMetadataHash(ipId), expectedMetadata.ipMetadataHash);
        assertEq(_coreMetadataViewModule.getNftMetadataHash(ipId), expectedMetadata.nftMetadataHash);
    }

    /// @dev Assert parent and derivative relationship.
    function assertParentChild(
        address parentIpId,
        address childIpId,
        uint256 expectedParentCount,
        uint256 expectedParentIndex
    ) internal view {
        assertTrue(_licenseRegistry.hasDerivativeIps(parentIpId));
        assertTrue(_licenseRegistry.isDerivativeIp(childIpId));
        assertTrue(_licenseRegistry.isParentIp({ parentIpId: parentIpId, childIpId: childIpId }));
        assertEq(_licenseRegistry.getParentIpCount(childIpId), expectedParentCount);
        assertEq(_licenseRegistry.getParentIp(childIpId, expectedParentIndex), parentIpId);
    }
}
