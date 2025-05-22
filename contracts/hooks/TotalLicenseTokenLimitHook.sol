// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { BaseModule } from "@storyprotocol/core/modules/BaseModule.sol";
import { AccessControlled } from "@storyprotocol/core/access/AccessControlled.sol";
import { ILicensingHook } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingHook.sol";
import { ILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/ILicenseTemplate.sol";

/// @title Total License Token Limit Hook
/// @notice Enforces a maximum limit on the total number of license tokens that can be minted
///         for a specific license attached to an IP. To use this hook, set the `licensingHook` field
///         in the licensing config to the address of this hook.
/// @dev This hook tracks and limits license token minting only for when this license hook is
///      configured and active on a license. This hook does not account for tokens minted prior to
///      its activation on a specific license. For instance, if a limit of 20 is set, and 10 tokens
///      were minted before this hook was active for that license, the hook will still allow an
///      additional 20 tokens to be minted.
contract TotalLicenseTokenLimitHook is BaseModule, AccessControlled, ILicensingHook {
    string public constant override name = "TOTAL_LICENSE_TOKEN_LIMIT_HOOK";

    /// @notice Stores the total license token limit for a given license.
    /// @dev The key is keccak256(licensorIpId, licenseTemplate, licenseTermsId).
    mapping(bytes32 => uint256) private totalLicenseTokenLimit;

    /// @notice Stores the total number of license tokens minted for a given license.
    /// @dev The key is keccak256(licensorIpId, licenseTemplate, licenseTermsId).
    /// @dev Derivative IPs are also considered as minted license tokens.
    mapping(bytes32 => uint256) private totalLicenseTokenMinted;

    /// @notice Emitted when the total license token limit is set
    /// @param licensorIpId The licensor IP id
    /// @param licenseTemplate The license template address
    /// @param licenseTermsId The license terms id
    /// @param limit The total license token limit for the specific license of the licensor IP
    event SetTotalLicenseTokenLimit(
        address indexed licensorIpId,
        address indexed licenseTemplate,
        uint256 indexed licenseTermsId,
        uint256 limit
    );

    /// @notice Emitted when the total license token limit is exceeded
    /// @param totalSupply The total supply of the license tokens
    /// @param amount The amount of license tokens to mint
    /// @param limit The total license token limit
    error TotalLicenseTokenLimitHook_TotalLicenseTokenLimitExceeded(uint256 totalSupply, uint256 amount, uint256 limit);

    /// @notice Emitted when the limit is lower than the existing supply
    /// @param totalSupply The total supply of the license tokens
    /// @param limit The total license token limit
    error TotalLicenseTokenLimitHook_LimitLowerThanTotalSupply(uint256 totalSupply, uint256 limit);

    constructor(
        address accessController,
        address ipAssetRegistry
    ) AccessControlled(accessController, ipAssetRegistry) {}

    /// @notice Set the total license token limit for a specific license
    /// @param licensorIpId The licensor IP id
    /// @param licenseTemplate The license template address
    /// @param licenseTermsId The license terms id
    /// @param limit The total license token limit, 0 means no limit
    function setTotalLicenseTokenLimit(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 limit
    ) external verifyPermission(licensorIpId) {
        bytes32 key = keccak256(abi.encodePacked(licensorIpId, licenseTemplate, licenseTermsId));
        uint256 totalSupply = _getTotalSupply(licensorIpId, licenseTemplate, licenseTermsId);
        if (limit != 0 && limit < totalSupply)
            revert TotalLicenseTokenLimitHook_LimitLowerThanTotalSupply(totalSupply, limit);
        totalLicenseTokenLimit[key] = limit;
        emit SetTotalLicenseTokenLimit(licensorIpId, licenseTemplate, licenseTermsId, limit);
    }

    /// @notice This function is called when the LicensingModule mints license tokens.
    /// @dev The hook can be used to implement various checks and determine the minting price.
    /// The hook should revert if the minting is not allowed.
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
        _checkTotalTokenLimit(licensorIpId, licenseTemplate, licenseTermsId, amount);
        totalLicenseTokenMinted[keccak256(abi.encodePacked(licensorIpId, licenseTemplate, licenseTermsId))] += amount;
        return _calculateFee(licenseTemplate, licenseTermsId, amount);
    }

    /// @notice This function is called before finalizing LicensingModule.registerDerivative(), after calling
    /// LicenseRegistry.registerDerivative().
    /// @dev The hook can be used to implement various checks and determine the minting price.
    /// The hook should revert if the registering of derivative is not allowed.
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
        _checkTotalTokenLimit(parentIpId, licenseTemplate, licenseTermsId, 1);
        // derivative IPs are also considered as minted license tokens
        totalLicenseTokenMinted[keccak256(abi.encodePacked(parentIpId, licenseTemplate, licenseTermsId))] += 1;
        return _calculateFee(licenseTemplate, licenseTermsId, 1);
    }

    /// @notice This function is called when the LicensingModule calculates/predict the minting fee for license tokens.
    /// @dev The hook should guarantee the minting fee calculation is correct and return the minting fee which is
    /// the exact same amount with returned by beforeMintLicenseTokens().
    /// The hook should revert if the minting fee calculation is not allowed.
    /// @param caller The address of the caller who calling the mintLicenseTokens() function.
    /// @param licensorIpId The ID of licensor IP from which issue the license tokens.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template,
    /// which is used to mint license tokens.
    /// @param amount The amount of license tokens to mint.
    /// @param receiver The address of the receiver who receive the license tokens.
    /// @param hookData The data to be used by the licensing hook.
    /// @return totalMintingFee The total minting fee to be paid when minting amount of license tokens.
    function calculateMintingFee(
        address caller,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata hookData
    ) external view returns (uint256 totalMintingFee) {
        return _calculateFee(licenseTemplate, licenseTermsId, amount);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(ILicensingHook).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Get the total license token limit for a specific license
    /// @param licensorIpId The licensor IP id
    /// @param licenseTemplate The license template address
    /// @param licenseTermsId The license terms id
    /// @return limit The total license token limit
    function getTotalLicenseTokenLimit(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (uint256 limit) {
        bytes32 key = keccak256(abi.encodePacked(licensorIpId, licenseTemplate, licenseTermsId));
        limit = totalLicenseTokenLimit[key];
    }

    /// @notice Get the total license token supply (number of minted license tokens
    ///         + number of derivative IPs) for a specific license
    /// @param licensorIpId The licensor IP id
    /// @param licenseTemplate The license template address
    /// @param licenseTermsId The license terms id
    /// @return supply The total license token supply
    function getTotalLicenseTokenSupply(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (uint256) {
        return _getTotalSupply(licensorIpId, licenseTemplate, licenseTermsId);
    }

    /// @dev checks if the total license token limit is exceeded
    /// @param licensorIpId The licensor IP id
    /// @param licenseTemplate The license template address
    /// @param licenseTermsId The license terms id
    /// @param amount The amount of license tokens to mint
    function _checkTotalTokenLimit(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount
    ) internal view {
        bytes32 key = keccak256(abi.encodePacked(licensorIpId, licenseTemplate, licenseTermsId));
        uint256 limit = totalLicenseTokenLimit[key];
        if (limit != 0) {
            // derivative IPs are also considered as minted license tokens
            uint256 totalSupply = _getTotalSupply(licensorIpId, licenseTemplate, licenseTermsId);
            if (totalSupply + amount > limit) {
                revert TotalLicenseTokenLimitHook_TotalLicenseTokenLimitExceeded(totalSupply, amount, limit);
            }
        }
    }

    /// @dev calculates the minting fee for a given license
    /// @param licenseTemplate The license template address
    /// @param licenseTermsId The license terms id
    /// @param amount The amount of license tokens to mint
    /// @return totalMintingFee The total minting fee to be paid when minting amount of license tokens
    function _calculateFee(
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount
    ) internal view returns (uint256 totalMintingFee) {
        (, , uint256 mintingFee, ) = ILicenseTemplate(licenseTemplate).getRoyaltyPolicy(licenseTermsId);
        return amount * mintingFee;
    }

    /// @dev gets the total number of license tokens minted for a given license
    /// @param licensorIpId The licensor IP id
    /// @param licenseTemplate The license template address
    /// @param licenseTermsId The license terms id
    /// @return totalSupply The total number of license tokens minted for the given license
    function _getTotalSupply(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal view returns (uint256) {
        return totalLicenseTokenMinted[keccak256(abi.encodePacked(licensorIpId, licenseTemplate, licenseTermsId))];
    }
}
