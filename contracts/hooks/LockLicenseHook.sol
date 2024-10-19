// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { BaseModule } from "@storyprotocol/core/modules/BaseModule.sol";
import { ILicensingHook } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingHook.sol";

contract LockLicenseHook is BaseModule, ILicensingHook {
    string public constant override name = "LockLicenseHook";

    /// @notice Emitted when attempting to perform an action on a locked license
    /// @param licensorIpId The licensor IP id that is locked
    /// @param licenseTemplate The license template address that is locked
    /// @param licenseTermsId The license terms id that is locked
    error LockLicenseHook_LicenseLocked(address licensorIpId, address licenseTemplate, uint256 licenseTermsId);

    /// @notice This function is called when the LicensingModule mints license tokens.
    /// @dev This function will always revert to prevent any license token minting.
    /// @param caller The address of the caller who calling the mintLicenseTokens() function.
    /// @param licensorIpId The ID of licensor IP from which issue the license tokens.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template,
    /// which is used to mint license tokens.
    /// @param amount The amount of license tokens to mint.
    /// @param receiver The address of the receiver who receive the license tokens.
    /// @param hookData The data to be used by the licensing hook.
    /// @return totalMintingFee The total minting fee to be paid when minting amount of license tokens.
    function beforeMintLicenseTokens(
        address caller,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata hookData
    ) external returns (uint256 totalMintingFee) {
        revert LockLicenseHook_LicenseLocked(licensorIpId, licenseTemplate, licenseTermsId);
    }

    /// @notice This function is called before finalizing LicensingModule.registerDerivative(), after calling
    /// LicenseRegistry.registerDerivative().
    /// @dev This function will always revert to prevent any derivative registration.
    /// @param childIpId The derivative IP ID.
    /// @param parentIpId The parent IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template.
    /// @param hookData The data to be used by the licensing hook.
    /// @return mintingFee The minting fee to be paid when register child IP to the parent IP as derivative.
    function beforeRegisterDerivative(
        address caller,
        address childIpId,
        address parentIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        bytes calldata hookData
    ) external returns (uint256 mintingFee) {
        revert LockLicenseHook_LicenseLocked(parentIpId, licenseTemplate, licenseTermsId);
    }

    /// @notice This function is called when the LicensingModule calculates/predict the minting fee for license tokens.
    /// @dev This function will always return 0 to signal that license is locked/disabled.
    /// @param caller The address of the caller who calling the mintLicenseTokens() function.
    /// @param licensorIpId The ID of licensor IP from which issue the license tokens.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template,
    /// which is used to mint license tokens.
    /// @param amount The amount of license tokens to mint.
    /// @param receiver The address of the receiver who receive the license tokens.
    /// @param hookData The data to be used by the licensing hook.
    /// @return totalMintingFee The minting fee to be paid when minting amount of license tokens.
    function calculateMintingFee(
        address caller,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata hookData
    ) external view returns (uint256 totalMintingFee) {
        totalMintingFee = 0;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(ILicensingHook).interfaceId || super.supportsInterface(interfaceId);
    }
}
