// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IStoryNFT } from "../interfaces/story-nft/IStoryNFT.sol";
import { IOrgNFT } from "../interfaces/story-nft/IOrgNFT.sol";
import { IStoryNFTFactory } from "../interfaces/story-nft/IStoryNFTFactory.sol";

/// @title StoryNFTFactory
/// @notice StoryNFTFactory is the entrypoint for creating new Story NFT collections.
contract StoryNFTFactory is IStoryNFTFactory, AccessManagedUpgradeable, UUPSUpgradeable {
    using ERC165Checker for address;
    using MessageHashUtils for bytes32;

    /// @notice Story Proof-of-Creativity IP Asset Registry address.
    address public immutable IP_ASSET_REGISTRY;

    /// @notice Story Proof-of-Creativity Licensing Module address.
    address public immutable LICENSING_MODULE;

    /// @notice Story Proof-of-Creativity PILicense Template address.
    address public immutable PIL_TEMPLATE;

    /// @notice Story Proof-of-Creativity default license terms ID.
    uint256 public immutable DEFAULT_LICENSE_TERMS_ID;

    /// @notice Organization NFT address.
    IOrgNFT public immutable ORG_NFT;

    /// @dev Storage structure for the StoryNFTFactory
    /// @custom:storage-location erc7201:story-protocol-periphery.StoryNFTFactory
    /// @param signer The address of the StoryNFTFactory's whitelist signer.
    /// @param defaultStoryNftTemplate The address of the default StoryNFT template.
    /// @param deployedStoryNftsByOrgName A mapping of organization names to their corresponding StoryNFT addresses.
    /// @param deployedStoryNftsByOrgTokenId A mapping of organization token IDs to their corresponding StoryNFT addresses.
    /// @param deployedStoryNftsByOrgIpId A mapping of organization IP IDs to their corresponding StoryNFT addresses.
    /// @param usedSignatures A mapping of signatures to booleans indicating whether they have been used.
    /// @param whitelistedNftTemplates A mapping of StoryNFT templates to booleans indicating whether
    ///                                they are whitelisted.
    struct StoryNFTFactoryStorage {
        address signer;
        address defaultStoryNftTemplate;
        mapping(string orgName => address storyNft) deployedStoryNftsByOrgName;
        mapping(uint256 orgTokenId => address storyNft) deployedStoryNftsByOrgTokenId;
        mapping(address orgIpId => address storyNft) deployedStoryNftsByOrgIpId;
        mapping(bytes signature => bool used) usedSignatures;
        mapping(address storyNftTemplate => bool isWhitelisted) whitelistedNftTemplates;
    }

    // solhint-disable-next-line max-line-length
    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.StoryNFTFactory")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant StoryNFTFactoryStorageLocation =
        0xf790322fec2c69d950299f25bd2b4e4f8b183652054d59cf2f75df434f22df00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address ipAssetRegistry,
        address licensingModule,
        address pilTemplate,
        uint256 defaultLicenseTermsId,
        address orgNft
    ) {
        if (
            ipAssetRegistry == address(0) ||
            licensingModule == address(0) ||
            pilTemplate == address(0) ||
            orgNft == address(0)
        ) revert StoryNFTFactory__ZeroAddressParam();

        IP_ASSET_REGISTRY = ipAssetRegistry;
        LICENSING_MODULE = licensingModule;
        PIL_TEMPLATE = pilTemplate;
        DEFAULT_LICENSE_TERMS_ID = defaultLicenseTermsId;
        ORG_NFT = IOrgNFT(orgNft);

        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    /// @param defaultStoryNftTemplate The address of the default StoryNFT template.
    /// @param signer The address of the StoryNFTFactory's whitelist signer.
    function initialize(address accessManager, address defaultStoryNftTemplate, address signer) external initializer {
        if (accessManager == address(0) || defaultStoryNftTemplate == address(0))
            revert StoryNFTFactory__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();

        StoryNFTFactoryStorage storage $ = _getStoryNFTFactoryStorage();
        $.signer = signer;
        $.defaultStoryNftTemplate = defaultStoryNftTemplate;
        $.whitelistedNftTemplates[defaultStoryNftTemplate] = true;
    }

    /// @notice Mints a new organization NFT and deploys (creates a clone of) `storyNftTemplate` as the StoryNFT
    /// associated with the new organization NFT.
    /// @param storyNftTemplate The address of a whitelisted StoryNFT template to be cloned.
    /// @param orgNftRecipient The address of the recipient of the organization NFT.
    /// @param orgName The name of the organization.
    /// @param orgTokenURI The token URI of the organization NFT.
    /// @param signature The signature from the StoryNFTFactory's whitelist signer. This signautre is genreated by
    ///  having the whitelist signer sign the caller's address (msg.sender) for this `deployStoryNft` function.
    /// @param storyNftInitParams The initialization data for the StoryNFT (see {IStoryBadgeNFT-InitParams}).
    /// @return orgNft The address of the organization NFT.
    /// @return orgTokenId The token ID of the organization NFT.
    /// @return orgIpId The ID of the organization IP.
    /// @return storyNft The address of the dployed StoryNFT
    function deployStoryNft(
        address storyNftTemplate,
        address orgNftRecipient,
        string calldata orgName,
        string calldata orgTokenURI,
        bytes calldata signature,
        IStoryNFT.StoryNftInitParams calldata storyNftInitParams
    ) external returns (address orgNft, uint256 orgTokenId, address orgIpId, address storyNft) {
        StoryNFTFactoryStorage storage $ = _getStoryNFTFactoryStorage();

        // The given story NFT template must be whitelisted
        if (!$.whitelistedNftTemplates[storyNftTemplate])
            revert StoryNFTFactory__NftTemplateNotWhitelisted(storyNftTemplate);

        // The given signature must not have been used
        if ($.usedSignatures[signature]) revert StoryNFTFactory__SignatureAlreadyUsed(signature);

        // The given organization name must not have been used
        if ($.deployedStoryNftsByOrgName[orgName] != address(0))
            revert StoryNFTFactory__OrgAlreadyDeployed(orgName, $.deployedStoryNftsByOrgName[orgName]);

        // The signature must be valid
        bytes32 hash = keccak256(abi.encodePacked(msg.sender)).toEthSignedMessageHash();
        if (!SignatureChecker.isValidSignatureNow($.signer, hash, signature))
            revert StoryNFTFactory__InvalidSignature(signature);

        // Mint the organization NFT and register it as an IP
        (orgTokenId, orgIpId) = ORG_NFT.mintOrgNft(orgNftRecipient, orgTokenURI);

        orgNft = address(ORG_NFT);

        // Clones the story NFT template and initializes it
        storyNft = Clones.clone(storyNftTemplate);
        IStoryNFT(storyNft).initialize(orgTokenId, orgIpId, storyNftInitParams);

        // Stores the deployed story NFT address
        $.deployedStoryNftsByOrgName[orgName] = storyNft;
        $.deployedStoryNftsByOrgTokenId[orgTokenId] = storyNft;
        $.deployedStoryNftsByOrgIpId[orgIpId] = storyNft;

        // Mark the signature as used
        $.usedSignatures[signature] = true;

        emit StoryNftDeployed(orgName, orgNft, orgTokenId, orgIpId, storyNft);
    }

    /// @notice Mints a new organization NFT and deploys (creates a clone of) `storyNftTemplate` as the StoryNFT
    /// associated with the new organization NFT.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param storyNftTemplate The address of a whitelisted StoryNFT template to be cloned.
    /// @param orgNftRecipient The address of the recipient of the organization NFT.
    /// @param orgName The name of the organization.
    /// @param orgTokenURI The token URI of the organization NFT.
    /// @param storyNftInitParams The initialization data for the StoryNFT (see {IStoryBadgeNFT-InitParams}).
    /// @param isRootOrg Whether the organization is the root organization.
    /// @return orgNft The address of the organization NFT.
    /// @return orgTokenId The token ID of the organization NFT.
    /// @return orgIpId The ID of the organization IP.
    /// @return storyNft The address of the dployed StoryNFT
    function deployStoryNftByAdmin(
        address storyNftTemplate,
        address orgNftRecipient,
        string calldata orgName,
        string calldata orgTokenURI,
        IStoryNFT.StoryNftInitParams calldata storyNftInitParams,
        bool isRootOrg
    ) external restricted returns (address orgNft, uint256 orgTokenId, address orgIpId, address storyNft) {
        StoryNFTFactoryStorage storage $ = _getStoryNFTFactoryStorage();

        // The given story NFT template must be whitelisted
        if (!$.whitelistedNftTemplates[storyNftTemplate])
            revert StoryNFTFactory__NftTemplateNotWhitelisted(storyNftTemplate);

        // The given organization name must not have been used
        if ($.deployedStoryNftsByOrgName[orgName] != address(0))
            revert StoryNFTFactory__OrgAlreadyDeployed(orgName, $.deployedStoryNftsByOrgName[orgName]);

        // Mint the organization NFT and register it as an IP
        if (isRootOrg) {
            (orgTokenId, orgIpId) = ORG_NFT.mintRootOrgNft(orgNftRecipient, orgTokenURI);
        } else {
            (orgTokenId, orgIpId) = ORG_NFT.mintOrgNft(orgNftRecipient, orgTokenURI);
        }

        orgNft = address(ORG_NFT);

        // Clones the story NFT template and initializes it
        storyNft = Clones.clone(storyNftTemplate);
        IStoryNFT(storyNft).initialize(orgTokenId, orgIpId, storyNftInitParams);

        // Stores the deployed story NFT address
        $.deployedStoryNftsByOrgName[orgName] = storyNft;
        $.deployedStoryNftsByOrgTokenId[orgTokenId] = storyNft;
        $.deployedStoryNftsByOrgIpId[orgIpId] = storyNft;

        emit StoryNftDeployed(orgName, orgNft, orgTokenId, orgIpId, storyNft);
    }

    /// @notice Sets the default StoryNFT template of the StoryNFTFactory.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param defaultStoryNftTemplate The new default StoryNFT template.
    function setDefaultStoryNftTemplate(address defaultStoryNftTemplate) external restricted {
        if (defaultStoryNftTemplate == address(0)) revert StoryNFTFactory__ZeroAddressParam();
        if (!defaultStoryNftTemplate.supportsInterface(type(IStoryNFT).interfaceId))
            revert StoryNFTFactory__UnsupportedIStoryNFT(defaultStoryNftTemplate);

        _getStoryNFTFactoryStorage().whitelistedNftTemplates[defaultStoryNftTemplate] = true;
        _getStoryNFTFactoryStorage().defaultStoryNftTemplate = defaultStoryNftTemplate;
        emit StoryNFTFactoryDefaultStoryNftTemplateUpdated(defaultStoryNftTemplate);
    }

    /// @notice Sets the signer of the StoryNFTFactory.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param signer The new signer of the StoryNFTFactory.
    function setSigner(address signer) external restricted {
        if (signer == address(0)) revert StoryNFTFactory__ZeroAddressParam();
        _getStoryNFTFactoryStorage().signer = signer;
        emit StoryNFTFactorySignerUpdated(signer);
    }

    /// @notice Whitelists a new StoryNFT template.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param storyNftTemplate The new StoryNFT template to be whitelisted.
    function whitelistNftTemplate(address storyNftTemplate) external restricted {
        if (storyNftTemplate == address(0)) revert StoryNFTFactory__ZeroAddressParam();

        // The given story NFT template must implement IStoryNFT
        if (!storyNftTemplate.supportsInterface(type(IStoryNFT).interfaceId))
            revert StoryNFTFactory__UnsupportedIStoryNFT(storyNftTemplate);

        _getStoryNFTFactoryStorage().whitelistedNftTemplates[storyNftTemplate] = true;
        emit StoryNFTFactoryNftTemplateWhitelisted(storyNftTemplate);
    }

    /// @notice Returns the address of the default StoryNFT template.
    function getDefaultStoryNftTemplate() external view returns (address) {
        return _getStoryNFTFactoryStorage().defaultStoryNftTemplate;
    }

    /// @notice Returns the address of the StoryNFT for a given organization name.
    /// @param orgName The name of the organization.
    function getStoryNftAddressByOrgName(string calldata orgName) external view returns (address storyNft) {
        storyNft = _getStoryNFTFactoryStorage().deployedStoryNftsByOrgName[orgName];
        if (storyNft == address(0)) revert StoryNFTFactory__OrgNotFoundByOrgName(orgName);
    }

    /// @notice Returns the address of the StoryNFT for a given organization token ID.
    /// @param orgTokenId The token ID of the organization.
    function getStoryNftAddressByOrgTokenId(uint256 orgTokenId) external view returns (address storyNft) {
        storyNft = _getStoryNFTFactoryStorage().deployedStoryNftsByOrgTokenId[orgTokenId];
        if (storyNft == address(0)) revert StoryNFTFactory__OrgNotFoundByOrgTokenId(orgTokenId);
    }

    /// @notice Returns the address of the StoryNFT for a given organization IP ID.
    /// @param orgIpId The ID of the organization IP.
    function getStoryNftAddressByOrgIpId(address orgIpId) external view returns (address storyNft) {
        storyNft = _getStoryNFTFactoryStorage().deployedStoryNftsByOrgIpId[orgIpId];
        if (storyNft == address(0)) revert StoryNFTFactory__OrgNotFoundByOrgIpId(orgIpId);
    }

    /// @notice Returns whether a given StoryNFT template is whitelisted.
    /// @param storyNftTemplate The address of the StoryNFT template.
    function isNftTemplateWhitelisted(address storyNftTemplate) external view returns (bool) {
        return _getStoryNFTFactoryStorage().whitelistedNftTemplates[storyNftTemplate];
    }

    /// @dev Returns the storage struct of StoryNFTFactory.
    function _getStoryNFTFactoryStorage() private pure returns (StoryNFTFactoryStorage storage $) {
        assembly {
            $.slot := StoryNFTFactoryStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
