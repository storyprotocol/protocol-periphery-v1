// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IOrgStoryNFT } from "../interfaces/story-nft/IOrgStoryNFT.sol";
import { IOrgNFT } from "../interfaces/story-nft/IOrgNFT.sol";
import { IStoryNFT } from "../interfaces/story-nft/IStoryNFT.sol";
import { IOrgStoryNFTFactory } from "../interfaces/story-nft/IOrgStoryNFTFactory.sol";
import { WorkflowStructs } from "../lib/WorkflowStructs.sol";

/// @title Organization Story NFT Factory
/// @notice Organization Story NFT Factory is the entrypoint for creating new Story NFT collections.
contract OrgStoryNFTFactory is IOrgStoryNFTFactory, AccessManagedUpgradeable, UUPSUpgradeable {
    using ERC165Checker for address;
    using MessageHashUtils for bytes32;

    /// @notice Story Proof-of-Creativity IP Asset Registry address.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable IP_ASSET_REGISTRY;

    /// @notice Story Proof-of-Creativity Licensing Module address.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable LICENSING_MODULE;

    /// @notice Story Proof-of-Creativity PILicense Template address.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable PIL_TEMPLATE;

    /// @notice Story Proof-of-Creativity default license terms ID.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint256 public immutable DEFAULT_LICENSE_TERMS_ID;

    /// @notice Organization NFT address.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IOrgNFT public immutable ORG_NFT;

    /// @dev Storage structure for the OrgStoryNFTFactory
    /// @custom:storage-location erc7201:story-protocol-periphery.OrgStoryNFTFactory
    /// @param signer The address of the OrgStoryNFTFactory's whitelist signer.
    /// @param defaultOrgStoryNftTemplate The address of the default OrgStoryNFT template.
    /// @param deployedOrgStoryNftsByOrgName A mapping of organization names to their corresponding OrgStoryNFT addresses.
    /// @param deployedOrgStoryNftsByOrgTokenId A mapping of organization token IDs to their corresponding OrgStoryNFT addresses.
    /// @param deployedStoryNftsByOrgIpId A mapping of organization IP IDs to their corresponding StoryNFT addresses.
    /// @param usedSignatures A mapping of signatures to booleans indicating whether they have been used.
    /// @param whitelistedNftTemplates A mapping of StoryNFT templates to booleans indicating whether
    ///                                they are whitelisted.
    struct OrgStoryNFTFactoryStorage {
        address signer;
        address defaultOrgStoryNftTemplate;
        mapping(string orgName => address orgStoryNft) deployedOrgStoryNftsByOrgName;
        mapping(uint256 orgTokenId => address orgStoryNft) deployedOrgStoryNftsByOrgTokenId;
        mapping(address orgIpId => address orgStoryNft) deployedOrgStoryNftsByOrgIpId;
        mapping(bytes signature => bool used) usedSignatures;
        mapping(address orgStoryNftTemplate => bool isWhitelisted) whitelistedNftTemplates;
    }

    // solhint-disable-next-line max-line-length
    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.OrgStoryNFTFactory")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant OrgStoryNFTFactoryStorageLocation =
        0x7ed1ac2e1c0769416119d5b0f885c648d2baac2de18cef73faf81ee04f3f7300;

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
        ) revert OrgStoryNFTFactory__ZeroAddressParam();

        IP_ASSET_REGISTRY = ipAssetRegistry;
        LICENSING_MODULE = licensingModule;
        PIL_TEMPLATE = pilTemplate;
        DEFAULT_LICENSE_TERMS_ID = defaultLicenseTermsId;
        ORG_NFT = IOrgNFT(orgNft);

        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param accessManager The address of the protocol access manager.
    /// @param defaultOrgStoryNftTemplate The address of the default OrgStoryNFT template.
    /// @param signer The address of the OrgStoryNFTFactory's whitelist signer.
    function initialize(
        address accessManager,
        address defaultOrgStoryNftTemplate,
        address signer
    ) external initializer {
        if (accessManager == address(0) || defaultOrgStoryNftTemplate == address(0))
            revert OrgStoryNFTFactory__ZeroAddressParam();
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();

        OrgStoryNFTFactoryStorage storage $ = _getOrgStoryNFTFactoryStorage();
        $.signer = signer;
        $.defaultOrgStoryNftTemplate = defaultOrgStoryNftTemplate;
        $.whitelistedNftTemplates[defaultOrgStoryNftTemplate] = true;
    }

    /// @notice Mints a new organization NFT and deploys a proxy to `orgStoryNftTemplate` as the OrgStoryNFT
    /// associated with the new organization NFT.
    /// @param orgStoryNftTemplate The address of a whitelisted OrgStoryNFT template to be cloned.
    /// @param orgNftRecipient The address of the recipient of the organization NFT.
    /// @param orgName The name of the organization.
    /// @param orgIpMetadata OPTIONAL. The desired metadata for the newly minted OrgNFT and registered IP.
    /// @param signature The signature from the OrgStoryNFTFactory's whitelist signer. This signautre is genreated by
    ///  having the whitelist signer sign the caller's address (msg.sender) for this `deployStoryNft` function.
    /// @param storyNftInitParams The initialization data for the OrgStoryNFT (see {IOrgStoryNFT-InitParams}).
    /// @return orgNft The address of the organization NFT.
    /// @return orgTokenId The token ID of the organization NFT.
    /// @return orgIpId The ID of the organization IP.
    /// @return orgStoryNft The address of the dployed OrgStoryNFT
    function deployOrgStoryNft(
        address orgStoryNftTemplate,
        address orgNftRecipient,
        string calldata orgName,
        WorkflowStructs.IPMetadata calldata orgIpMetadata,
        bytes calldata signature,
        IStoryNFT.StoryNftInitParams calldata storyNftInitParams
    ) external returns (address orgNft, uint256 orgTokenId, address orgIpId, address orgStoryNft) {
        OrgStoryNFTFactoryStorage storage $ = _getOrgStoryNFTFactoryStorage();

        // The given story NFT template must be whitelisted
        if (!$.whitelistedNftTemplates[orgStoryNftTemplate])
            revert OrgStoryNFTFactory__NftTemplateNotWhitelisted(orgStoryNftTemplate);

        // The given signature must not have been used
        if ($.usedSignatures[signature]) revert OrgStoryNFTFactory__SignatureAlreadyUsed(signature);

        // Mark the signature as used
        $.usedSignatures[signature] = true;

        // The given organization name must not have been used
        if ($.deployedOrgStoryNftsByOrgName[orgName] != address(0))
            revert OrgStoryNFTFactory__OrgAlreadyDeployed(orgName, $.deployedOrgStoryNftsByOrgName[orgName]);

        // The signature must be valid
        bytes32 hash = keccak256(abi.encodePacked(msg.sender)).toEthSignedMessageHash();
        if (!SignatureChecker.isValidSignatureNow($.signer, hash, signature))
            revert OrgStoryNFTFactory__InvalidSignature(signature);

        // Mint the organization NFT and register it as an IP
        (orgTokenId, orgIpId) = ORG_NFT.mintOrgNft(orgNftRecipient, orgIpMetadata);

        orgNft = address(ORG_NFT);

        // Creates a new BeaconProxy for the story NFT template and initializes it
        orgStoryNft = address(
            new BeaconProxy(
                IOrgStoryNFT(orgStoryNftTemplate).getBeacon(),
                abi.encodeWithSelector(IOrgStoryNFT.initialize.selector, orgTokenId, orgIpId, storyNftInitParams)
            )
        );

        // Stores the deployed story NFT address
        $.deployedOrgStoryNftsByOrgName[orgName] = orgStoryNft;
        $.deployedOrgStoryNftsByOrgTokenId[orgTokenId] = orgStoryNft;
        $.deployedOrgStoryNftsByOrgIpId[orgIpId] = orgStoryNft;

        emit OrgStoryNftDeployed(orgName, orgNft, orgTokenId, orgIpId, orgStoryNft);
    }

    /// @notice Mints a new organization NFT and deploys a proxy to `orgStoryNftTemplate` as the OrgStoryNFT
    /// associated with the new organization NFT.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param orgStoryNftTemplate The address of a whitelisted OrgStoryNFT template to be cloned.
    /// @param orgNftRecipient The address of the recipient of the organization NFT.
    /// @param orgName The name of the organization.
    /// @param orgIpMetadata OPTIONAL. The desired metadata for the newly minted OrgNFT and registered IP.
    /// @param storyNftInitParams The initialization data for the OrgStoryNFT (see {IOrgStoryNFT-InitParams}).
    /// @param isRootOrg Whether the organization is the root organization.
    /// @return orgNft The address of the organization NFT.
    /// @return orgTokenId The token ID of the organization NFT.
    /// @return orgIpId The ID of the organization IP.
    /// @return orgStoryNft The address of the dployed OrgStoryNFT
    function deployOrgStoryNftByAdmin(
        address orgStoryNftTemplate,
        address orgNftRecipient,
        string calldata orgName,
        WorkflowStructs.IPMetadata calldata orgIpMetadata,
        IStoryNFT.StoryNftInitParams calldata storyNftInitParams,
        bool isRootOrg
    ) external restricted returns (address orgNft, uint256 orgTokenId, address orgIpId, address orgStoryNft) {
        OrgStoryNFTFactoryStorage storage $ = _getOrgStoryNFTFactoryStorage();

        // The given story NFT template must be whitelisted
        if (!$.whitelistedNftTemplates[orgStoryNftTemplate])
            revert OrgStoryNFTFactory__NftTemplateNotWhitelisted(orgStoryNftTemplate);

        // The given organization name must not have been used
        if ($.deployedOrgStoryNftsByOrgName[orgName] != address(0))
            revert OrgStoryNFTFactory__OrgAlreadyDeployed(orgName, $.deployedOrgStoryNftsByOrgName[orgName]);

        // Mint the organization NFT and register it as an IP
        if (isRootOrg) {
            (orgTokenId, orgIpId) = ORG_NFT.mintRootOrgNft(orgNftRecipient, orgIpMetadata);
        } else {
            (orgTokenId, orgIpId) = ORG_NFT.mintOrgNft(orgNftRecipient, orgIpMetadata);
        }

        orgNft = address(ORG_NFT);

        // Creates a new BeaconProxy for the story NFT template and initializes it
        orgStoryNft = address(
            new BeaconProxy(
                IOrgStoryNFT(orgStoryNftTemplate).getBeacon(),
                abi.encodeWithSelector(IOrgStoryNFT.initialize.selector, orgTokenId, orgIpId, storyNftInitParams)
            )
        );

        // Stores the deployed story NFT address
        $.deployedOrgStoryNftsByOrgName[orgName] = orgStoryNft;
        $.deployedOrgStoryNftsByOrgTokenId[orgTokenId] = orgStoryNft;
        $.deployedOrgStoryNftsByOrgIpId[orgIpId] = orgStoryNft;

        emit OrgStoryNftDeployed(orgName, orgNft, orgTokenId, orgIpId, orgStoryNft);
    }

    /// @notice Sets the default StoryNFT template of the OrgStoryNFTFactory.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param defaultOrgStoryNftTemplate The new default OrgStoryNFT template.
    function setDefaultOrgStoryNftTemplate(address defaultOrgStoryNftTemplate) external restricted {
        if (defaultOrgStoryNftTemplate == address(0)) revert OrgStoryNFTFactory__ZeroAddressParam();
        if (!defaultOrgStoryNftTemplate.supportsInterface(type(IOrgStoryNFT).interfaceId))
            revert OrgStoryNFTFactory__UnsupportedIOrgStoryNFT(defaultOrgStoryNftTemplate);

        _getOrgStoryNFTFactoryStorage().whitelistedNftTemplates[defaultOrgStoryNftTemplate] = true;
        _getOrgStoryNFTFactoryStorage().defaultOrgStoryNftTemplate = defaultOrgStoryNftTemplate;
        emit DefaultOrgStoryNftTemplateUpdated(defaultOrgStoryNftTemplate);
    }

    /// @notice Sets the signer of the OrgStoryNFTFactory.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param signer The new signer of the OrgStoryNFTFactory.
    function setSigner(address signer) external restricted {
        if (signer == address(0)) revert OrgStoryNFTFactory__ZeroAddressParam();
        _getOrgStoryNFTFactoryStorage().signer = signer;
        emit OrgStoryNFTFactorySignerUpdated(signer);
    }

    /// @notice Whitelists a new StoryNFT template.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param orgStoryNftTemplate The new OrgStoryNFT template to be whitelisted.
    function whitelistNftTemplate(address orgStoryNftTemplate) external restricted {
        if (orgStoryNftTemplate == address(0)) revert OrgStoryNFTFactory__ZeroAddressParam();

        // The given story NFT template must implement IOrgStoryNFT
        if (!orgStoryNftTemplate.supportsInterface(type(IOrgStoryNFT).interfaceId))
            revert OrgStoryNFTFactory__UnsupportedIOrgStoryNFT(orgStoryNftTemplate);

        _getOrgStoryNFTFactoryStorage().whitelistedNftTemplates[orgStoryNftTemplate] = true;
        emit NftTemplateWhitelisted(orgStoryNftTemplate);
    }

    /// @notice Returns the address of the default StoryNFT template.
    function getDefaultOrgStoryNftTemplate() external view returns (address) {
        return _getOrgStoryNFTFactoryStorage().defaultOrgStoryNftTemplate;
    }

    /// @notice Returns the address of the OrgStoryNFT for a given organization name.
    /// @param orgName The name of the organization.
    function getOrgStoryNftAddressByOrgName(string calldata orgName) external view returns (address orgStoryNft) {
        orgStoryNft = _getOrgStoryNFTFactoryStorage().deployedOrgStoryNftsByOrgName[orgName];
        if (orgStoryNft == address(0)) revert OrgStoryNFTFactory__OrgNotFoundByOrgName(orgName);
    }

    /// @notice Returns the address of the OrgStoryNFT for a given organization token ID.
    /// @param orgTokenId The token ID of the organization.
    function getOrgStoryNftAddressByOrgTokenId(uint256 orgTokenId) external view returns (address orgStoryNft) {
        orgStoryNft = _getOrgStoryNFTFactoryStorage().deployedOrgStoryNftsByOrgTokenId[orgTokenId];
        if (orgStoryNft == address(0)) revert OrgStoryNFTFactory__OrgNotFoundByOrgTokenId(orgTokenId);
    }

    /// @notice Returns the address of the OrgStoryNFT for a given organization IP ID.
    /// @param orgIpId The ID of the organization IP.
    function getOrgStoryNftAddressByOrgIpId(address orgIpId) external view returns (address orgStoryNft) {
        orgStoryNft = _getOrgStoryNFTFactoryStorage().deployedOrgStoryNftsByOrgIpId[orgIpId];
        if (orgStoryNft == address(0)) revert OrgStoryNFTFactory__OrgNotFoundByOrgIpId(orgIpId);
    }

    /// @notice Returns whether a given OrgStoryNFT template is whitelisted.
    /// @param nftTemplate The address of the OrgStoryNFT template.
    function isNftTemplateWhitelisted(address nftTemplate) external view returns (bool) {
        return _getOrgStoryNFTFactoryStorage().whitelistedNftTemplates[nftTemplate];
    }

    /// @dev Returns the storage struct of OrgStoryNFTFactory.
    function _getOrgStoryNFTFactoryStorage() private pure returns (OrgStoryNFTFactoryStorage storage $) {
        assembly {
            $.slot := OrgStoryNFTFactoryStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
