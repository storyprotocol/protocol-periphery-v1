// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IStoryNFT } from "./IStoryNFT.sol";

/// @title Organization Story NFT Factory Interface
/// @notice Organization Story NFT Factory is the entrypoint for creating new Story NFT collections.
interface IOrgStoryNFTFactory {
    ////////////////////////////////////////////////////////////////////////////
    //                              Errors                                    //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Invalid signature provided to OrgStoryNFTFactory functions.
    /// @param signature The signature that is invalid.
    error OrgStoryNFTFactory__InvalidSignature(bytes signature);

    /// @notice NftTemplate is not whitelisted to be used as a OrgStoryNFT.
    /// @param nftTemplate The NFT template that is not whitelisted.
    error OrgStoryNFTFactory__NftTemplateNotWhitelisted(address nftTemplate);

    /// @notice Organization is already deployed by the OrgStoryNFTFactory.
    /// @param orgName The name of the organization that is already deployed.
    /// @param deployedOrgStoryNft The address of the already deployed OrgStoryNFT for the organization.
    error OrgStoryNFTFactory__OrgAlreadyDeployed(string orgName, address deployedOrgStoryNft);

    /// @notice Organization is not found in the OrgStoryNFTFactory.
    /// @param orgName The name of the organization that is not found.
    error OrgStoryNFTFactory__OrgNotFoundByOrgName(string orgName);

    /// @notice Organization is not found in the OrgStoryNFTFactory.
    /// @param orgTokenId The token ID of the organization that is not found.
    error OrgStoryNFTFactory__OrgNotFoundByOrgTokenId(uint256 orgTokenId);

    /// @notice Organization is not found in the OrgStoryNFTFactory.
    /// @param orgIpId The ID of the organization IP that is not found.
    error OrgStoryNFTFactory__OrgNotFoundByOrgIpId(address orgIpId);

    /// @notice Signature is already used to deploy a OrgStoryNFT.
    /// @param signature The signature that is already used.
    error OrgStoryNFTFactory__SignatureAlreadyUsed(bytes signature);

    /// @notice BaseOrgStoryNFT is not supported by the OrgStoryNFTFactory.
    /// @param tokenContract The address of the token contract that does not implement IOrgStoryNFT.
    error OrgStoryNFTFactory__UnsupportedIOrgStoryNFT(address tokenContract);

    /// @notice Zero address provided as a param to OrgStoryNFTFactory functions.
    error OrgStoryNFTFactory__ZeroAddressParam();

    ////////////////////////////////////////////////////////////////////////////
    //                              Events                                    //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Emitted when the default OrgStoryNFT template is updated.
    /// @param defaultOrgStoryNftTemplate The new default OrgStoryNFT template.
    event DefaultOrgStoryNftTemplateUpdated(address defaultOrgStoryNftTemplate);

    /// @notice Emitted when a new orgnization NFT is minted and a new Organization StoryNFT associated with it is deployed.
    /// @param orgName The name of the organization.
    /// @param orgNft The address of the organization NFT.
    /// @param orgTokenId The token ID of the organization NFT.
    /// @param orgIpId The ID of the organization IP.
    /// @param orgStoryNft The address of the deployed OrgStoryNFT.
    event OrgStoryNftDeployed(string orgName, address orgNft, uint256 orgTokenId, address orgIpId, address orgStoryNft);

    /// @notice Emitted when the signer of the OrgStoryNFTFactory is updated.
    /// @param signer The new signer of the OrgStoryNFTFactory.
    event OrgStoryNFTFactorySignerUpdated(address signer);

    /// @notice Emitted when a new OrgStoryNFT template is whitelisted.
    /// @param nftTemplate The new OrgStoryNFT template that is whitelisted to be used in OrgStoryNFTFactory.
    event NftTemplateWhitelisted(address nftTemplate);

    ////////////////////////////////////////////////////////////////////////////
    //                             Functions                                  //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Mints a new organization NFT and deploys a proxy to `orgStoryNftTemplate` as the OrgStoryNFT
    /// associated with the new organization NFT.
    /// @param orgStoryNftTemplate The address of a whitelisted OrgStoryNFT template to be cloned.
    /// @param orgNftRecipient The address of the recipient of the organization NFT.
    /// @param orgName The name of the organization.
    /// @param orgTokenURI The token URI of the organization NFT.
    /// @param signature The signature from the OrgStoryNFTFactory's whitelist signer. This signautre is genreated by
    /// having the whitelist signer sign the caller's address (msg.sender) for this `deployOrgStoryNft` function.
    /// @param storyNftInitParams The initialization parameters for StoryNFT {see {IStoryNFT-StoryNftInitParams}}.
    /// @return orgNft The address of the organization NFT.
    /// @return orgTokenId The token ID of the organization NFT.
    /// @return orgIpId The ID of the organization IP.
    /// @return orgStoryNft The address of the dployed OrgStoryNFT
    function deployOrgStoryNft(
        address orgStoryNftTemplate,
        address orgNftRecipient,
        string calldata orgName,
        string calldata orgTokenURI,
        bytes calldata signature,
        IStoryNFT.StoryNftInitParams calldata storyNftInitParams
    ) external returns (address orgNft, uint256 orgTokenId, address orgIpId, address orgStoryNft);

    /// @notice Mints a new organization NFT and deploys a proxy to `orgStoryNftTemplate` as the OrgStoryNFT
    /// associated with the new organization NFT.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param orgStoryNftTemplate The address of a whitelisted OrgStoryNFT template to be cloned.
    /// @param orgNftRecipient The address of the recipient of the organization NFT.
    /// @param orgName The name of the organization.
    /// @param orgTokenURI The token URI of the organization NFT.
    /// @param storyNftInitParams The initialization parameters for StoryNFT {see {IStoryNFT-StoryNftInitParams}}.
    /// @param isRootOrg Whether the organization is the root organization.
    /// @return orgNft The address of the organization NFT.
    /// @return orgTokenId The token ID of the organization NFT.
    /// @return orgIpId The ID of the organization IP.
    /// @return orgStoryNft The address of the dployed OrgStoryNFT
    function deployOrgStoryNftByAdmin(
        address orgStoryNftTemplate,
        address orgNftRecipient,
        string calldata orgName,
        string calldata orgTokenURI,
        IStoryNFT.StoryNftInitParams calldata storyNftInitParams,
        bool isRootOrg
    ) external returns (address orgNft, uint256 orgTokenId, address orgIpId, address orgStoryNft);

    /// @notice Sets the default OrgStoryNFT template of the OrgStoryNFTFactory.
    /// @param defaultOrgStoryNftTemplate The new default OrgStoryNFT template.
    function setDefaultOrgStoryNftTemplate(address defaultOrgStoryNftTemplate) external;

    /// @notice Sets the signer of the OrgStoryNFTFactory.
    /// @param signer The new signer of the OrgStoryNFTFactory.
    function setSigner(address signer) external;

    /// @notice Whitelists a new OrgStoryNFT template.
    /// @param orgStoryNftTemplate The new OrgStoryNFT template to be whitelisted.
    function whitelistNftTemplate(address orgStoryNftTemplate) external;

    /// @notice Returns the default OrgStoryNFT template address.
    function getDefaultOrgStoryNftTemplate() external view returns (address);

    /// @notice Returns the address of the OrgStoryNFT for a given organization name.
    /// @param orgName The name of the organization.
    function getOrgStoryNftAddressByOrgName(string calldata orgName) external view returns (address);

    /// @notice Returns the address of the OrgStoryNFT for a given organization token ID.
    /// @param orgTokenId The token ID of the organization.
    function getOrgStoryNftAddressByOrgTokenId(uint256 orgTokenId) external view returns (address);

    /// @notice Returns the address of the OrgStoryNFT for a given organization IP ID.
    /// @param orgIpId The ID of the organization IP.
    function getOrgStoryNftAddressByOrgIpId(address orgIpId) external view returns (address);

    /// @notice Returns whether a given OrgStoryNFT template is whitelisted.
    /// @param nftTemplate The address of the OrgStoryNFT template.
    function isNftTemplateWhitelisted(address nftTemplate) external view returns (bool);
}
