// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
// solhint-disable-next-line max-line-length
import { ERC721URIStorageUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
// solhint-disable-next-line max-line-length
import { ILicensingModule } from "@story-protocol/protocol-core/contracts/interfaces/modules/licensing/ILicensingModule.sol";

import { IOrgNFT } from "../interfaces/story-nft/IOrgNFT.sol";

/// @title Organization NFT
/// @notice Each organization token represents a Story ecosystem project.
///         The root organization token represents Story.
///         Each organization token register as a IP on Story and is a derivative of the root organization IP.
contract OrgNFT is IOrgNFT, ERC721URIStorageUpgradeable, AccessManagedUpgradeable, UUPSUpgradeable, ERC721Holder {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable

    /// @notice Story Proof-of-Creativity IP Asset Registry address.
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice Story Proof-of-Creativity Licensing Module address.
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice License template address.
    address public immutable LICENSE_TEMPLATE;

    /// @notice License terms ID.
    uint256 public immutable LICENSE_TERMS_ID;

    /// @notice Story NFT Factory address.
    address public immutable STORY_NFT_FACTORY;

    /// @dev Storage structure for the OrgNFT
    /// @custom:storage-location erc7201:story-protocol-periphery.OrgNFT
    /// @param totalSupply The current total supply of the organization tokens.
    /// @param rootOrgIpId The ID of the root organization IP.
    struct OrgNFTStorage {
        uint256 totalSupply;
        address rootOrgIpId;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol-periphery.OrgNFT")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant OrgNFTStorageLocation = 0xa4a36278839a4db2ab2cd96ad705f696fd1f52c0a329c48dd114f7acbbc8db00;

    modifier onlyStoryNFTFactory() {
        if (msg.sender != address(STORY_NFT_FACTORY)) {
            revert OrgNFT__CallerNotStoryNFTFactory(msg.sender, STORY_NFT_FACTORY);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address ipAssetRegistry,
        address licensingModule,
        address storyNftFactory,
        address licenseTemplate,
        uint256 licenseTermsId
    ) {
        if (
            ipAssetRegistry == address(0) ||
            licensingModule == address(0) ||
            storyNftFactory == address(0) ||
            licenseTemplate == address(0)
        ) revert OrgNFT__ZeroAddressParam();

        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        STORY_NFT_FACTORY = storyNftFactory;
        LICENSE_TEMPLATE = licenseTemplate;
        LICENSE_TERMS_ID = licenseTermsId;

        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract.
    /// @param accessManager The address of the protocol admin contract.
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) {
            revert OrgNFT__ZeroAddressParam();
        }
        __ERC721_init("Organization NFT", "OrgNFT");
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @notice Mints the root organization token and register it as an IP.
    /// @dev This function is only callable by the StoryNFTFactory contract.
    /// @param recipient The address of the recipient of the root organization token.
    /// @param tokenURI_ The URI of the root organization token.
    /// @return rootOrgTokenId The ID of the root organization token.
    /// @return rootOrgIpId The ID of the root organization IP.
    function mintRootOrgNft(
        address recipient,
        string memory tokenURI_
    ) external onlyStoryNFTFactory returns (uint256 rootOrgTokenId, address rootOrgIpId) {
        OrgNFTStorage storage $ = _getOrgNFTStorage();
        if ($.rootOrgIpId != address(0)) revert OrgNFT__RootOrgNftAlreadyMinted();

        (rootOrgTokenId, rootOrgIpId) = _mintAndRegisterIp(recipient, tokenURI_);
        $.rootOrgIpId = rootOrgIpId;
    }

    /// @notice Mints a organization token, register it as an IP,
    /// and makes the IP as a derivative of the root organization IP.
    /// @dev This function is only callable by the StoryNFTFactory contract.
    /// @param recipient The address of the recipient of the minted organization token.
    /// @param tokenURI_ The URI of the minted organization token.
    /// @return orgTokenId The ID of the minted organization token.
    /// @return orgIpId The ID of the organization IP.
    function mintOrgNft(
        address recipient,
        string memory tokenURI_
    ) external onlyStoryNFTFactory returns (uint256 orgTokenId, address orgIpId) {
        OrgNFTStorage storage $ = _getOrgNFTStorage();
        if ($.rootOrgIpId == address(0)) revert OrgNFT__RootOrgNftNotMinted();

        // Mint the organization token and register it as an IP.
        (orgTokenId, orgIpId) = _mintAndRegisterIp(address(this), tokenURI_);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = $.rootOrgIpId;
        licenseTermsIds[0] = LICENSE_TERMS_ID;

        // Register the organization IP as a derivative of the root organization IP.
        LICENSING_MODULE.registerDerivative({
            childIpId: orgIpId,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: LICENSE_TEMPLATE,
            royaltyContext: ""
        });

        _safeTransfer(address(this), recipient, orgTokenId);
    }

    /// @notice Mints a organization token and register it as an IP.
    /// @param recipient The address of the recipient of the minted organization token.
    /// @param tokenURI_ The URI of the minted organization token.
    /// @return orgTokenId The ID of the minted organization token.
    /// @return orgIpId The ID of the organization IP.
    function _mintAndRegisterIp(
        address recipient,
        string memory tokenURI_
    ) private returns (uint256 orgTokenId, address orgIpId) {
        OrgNFTStorage storage $ = _getOrgNFTStorage();
        orgTokenId = $.totalSupply++;
        _safeMint(recipient, orgTokenId);
        _setTokenURI(orgTokenId, tokenURI_);
        orgIpId = IP_ASSET_REGISTRY.register(block.chainid, address(this), orgTokenId);

        emit OrgNFTMinted(recipient, address(this), orgTokenId, orgIpId);
    }

    /// @notice Returns the current total supply of the organization tokens.
    function totalSupply() external view returns (uint256) {
        return _getOrgNFTStorage().totalSupply;
    }

    /// @notice Returns the ID of the root organization IP.
    function getRootOrgIpId() external view returns (address) {
        return _getOrgNFTStorage().rootOrgIpId;
    }

    /// @notice IERC165 interface support.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721URIStorageUpgradeable, IERC165) returns (bool) {
        return interfaceId == type(IOrgNFT).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Returns the storage struct of OrgNFT.
    function _getOrgNFTStorage() private pure returns (OrgNFTStorage storage $) {
        assembly {
            $.slot := OrgNFTStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
