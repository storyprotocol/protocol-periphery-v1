// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { BaseModule } from "@storyprotocol/core/modules/BaseModule.sol";
import { AccessControlled } from "@storyprotocol/core/access/AccessControlled.sol";
import { ILicensingHook } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingHook.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { ILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/ILicenseTemplate.sol";

contract TotalLicenseTokenLimitHook is BaseModule, AccessControlled, ILicensingHook {
    string public constant override name = "TOTAL_LICENSE_TOKEN_LIMIT_HOOK";

    /// @notice The address of the License Registry.
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice The address of the License Token.
    ILicenseToken public immutable LICENSE_TOKEN;

    // ipId => totalLicenseTokenLimit
    mapping(address => uint256) public ipIdToTotalLicenseTokenLimit;

    /// @notice Emitted when the total license token limit is set
    /// @param licensorIpId The licensor IP id
    /// @param limit The total license token limit for the specific license of the licensor IP
    event SetTotalLicenseTokenLimit(address indexed licensorIpId, uint256 limit);

    /// @notice Emitted when the total license token limit is exceeded
    /// @param totalSupply The total supply of the license tokens
    /// @param amount The amount of license tokens to mint
    /// @param limit The total license token limit
    error TotalLicenseTokenLimitHook_TotalLicenseTokenLimitExceeded(uint256 totalSupply, uint256 amount, uint256 limit);

    /// @notice Emitted when the limit is lower than the existing supply
    /// @param totalSupply The total supply of the license tokens
    /// @param limit The total license token limit
    error TotalLicenseTokenLimitHook_LimitLowerThanTotalSupply(uint256 totalSupply, uint256 limit);

    /// @notice Emitted when the license registry is the zero address
    error TotalLicenseTokenLimitHook_ZeroLicenseRegistry();

    /// @notice Emitted when the license token is the zero address
    error TotalLicenseTokenLimitHook_ZeroLicenseToken();

    constructor(
        address licenseRegistry,
        address licenseToken,
        address accessController,
        address ipAssetRegistry
    ) AccessControlled(accessController, ipAssetRegistry) {
        if (licenseRegistry == address(0)) revert TotalLicenseTokenLimitHook_ZeroLicenseRegistry();
        if (licenseToken == address(0)) revert TotalLicenseTokenLimitHook_ZeroLicenseToken();
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        LICENSE_TOKEN = ILicenseToken(licenseToken);
    }

    /// @notice Set the total license token limit for a specific licensor IP
    /// @param licensorIpId The licensor IP id
    /// @param limit The total license token limit, 0 means no limit
    function setTotalLicenseTokenLimit(address licensorIpId, uint256 limit) external verifyPermission(licensorIpId) {
        uint256 totalSupply = _getTotalSupply(licensorIpId);
        if (limit != 0 && limit < totalSupply)
            revert TotalLicenseTokenLimitHook_LimitLowerThanTotalSupply(totalSupply, limit);
        ipIdToTotalLicenseTokenLimit[licensorIpId] = limit;
        emit SetTotalLicenseTokenLimit(licensorIpId, limit);
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
        _checkTotalTokenLimit(licensorIpId, amount);
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
        _checkTotalTokenLimit(parentIpId, 1);
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

    /// @notice Get the total license token limit for a specific licensor IP
    /// @param licensorIpId The licensor IP id
    /// @return limit The total license token limit
    function getTotalLicenseTokenLimit(address licensorIpId) external view returns (uint256 limit) {
        limit = ipIdToTotalLicenseTokenLimit[licensorIpId];
    }

    function _checkTotalTokenLimit(address licensorIpId, uint256 amount) internal view {
        uint256 limit = ipIdToTotalLicenseTokenLimit[licensorIpId];
        if (limit != 0) {
            // derivative IPs are also considered as minted license tokens
            uint256 totalSupply = _getTotalSupply(licensorIpId);
            if (totalSupply + amount > limit) {
                revert TotalLicenseTokenLimitHook_TotalLicenseTokenLimitExceeded(totalSupply, amount, limit);
            }
        }
    }

    function _calculateFee(
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount
    ) internal view returns (uint256 totalMintingFee) {
        (, , uint256 mintingFee, ) = ILicenseTemplate(licenseTemplate).getRoyaltyPolicy(licenseTermsId);
        return amount * mintingFee;
    }

    function _getTotalSupply(address licensorIpId) internal view returns (uint256) {
        return
            LICENSE_REGISTRY.getDerivativeIpCount(licensorIpId) + LICENSE_TOKEN.getTotalTokensByLicensor(licensorIpId);
    }

    ////////////////////////////////////////////////////////////////////////////
    //       DEPRECATED FUNCTIONS, WILL BE REMOVED IN THE NEXT RELEASE        //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Set the total license token limit for a specific licensor IP
    /// @dev Deprecated function, will be removed in the next release
    /// @param licensorIpId The licensor IP id
    /// @param licenseTemplate Deprecated, no longer used
    /// @param licenseTermsId Deprecated, no longer used
    /// @param limit The total license token limit, 0 means no limit
    function setTotalLicenseTokenLimit(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 limit
    ) external verifyPermission(licensorIpId) {
        uint256 totalSupply = _getTotalSupply(licensorIpId);
        if (limit != 0 && limit < totalSupply)
            revert TotalLicenseTokenLimitHook_LimitLowerThanTotalSupply(totalSupply, limit);
        ipIdToTotalLicenseTokenLimit[licensorIpId] = limit;
        emit SetTotalLicenseTokenLimit(licensorIpId, limit);
    }

    /// @notice Get the total license token limit for a specific licensor IP
    /// @dev Deprecated function, will be removed in the next release
    /// @param licensorIpId The licensor IP id
    /// @param licenseTemplate Deprecated, no longer used
    /// @param licenseTermsId Deprecated, no longer used
    /// @return limit The total license token limit
    function getTotalLicenseTokenLimit(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (uint256 limit) {
        limit = ipIdToTotalLicenseTokenLimit[licensorIpId];
    }
}
