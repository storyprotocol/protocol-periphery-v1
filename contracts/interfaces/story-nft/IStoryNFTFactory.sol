// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IStoryNFT } from "./IStoryNFT.sol";

/// @title Story NFT Factory Interface
/// @notice Story NFT Factory is the entrypoint for creating new Story NFT collections.
interface IStoryNFTFactory {
    ////////////////////////////////////////////////////////////////////////////
    //                              Errors                                    //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Invalid signature provided to StoryNFTFactory functions.
    /// @param signature The signature that is invalid.
    error StoryNFTFactory__InvalidSignature(bytes signature);

    /// @notice NftTemplate is not whitelisted to be used as a StoryNFT.
    /// @param nftTemplate The NFT template that is not whitelisted.
    error StoryNFTFactory__NftTemplateNotWhitelisted(address nftTemplate);

    /// @notice Organization is already deployed by the StoryNFTFactory.
    /// @param orgName The name of the organization that is already deployed.
    /// @param deployedStoryNft The address of the already deployed StoryNFT for the organization.
    error StoryNFTFactory__OrgAlreadyDeployed(string orgName, address deployedStoryNft);

    /// @notice Organization is not found in the StoryNFTFactory.
    /// @param orgName The name of the organization that is not found.
    error StoryNFTFactory__OrgNotFoundByOrgName(string orgName);

    /// @notice Organization is not found in the StoryNFTFactory.
    /// @param orgTokenId The token ID of the organization that is not found.
    error StoryNFTFactory__OrgNotFoundByOrgTokenId(uint256 orgTokenId);

    /// @notice Organization is not found in the StoryNFTFactory.
    /// @param orgIpId The ID of the organization IP that is not found.
    error StoryNFTFactory__OrgNotFoundByOrgIpId(address orgIpId);

    /// @notice Signature is already used to deploy a StoryNFT.
    /// @param signature The signature that is already used.
    error StoryNFTFactory__SignatureAlreadyUsed(bytes signature);

    /// @notice BaseStoryNFT is not supported by the StoryNFTFactory.
    /// @param tokenContract The address of the token contract that does not implement IOrgStoryNFT.
    error StoryNFTFactory__UnsupportedIOrgStoryNFT(address tokenContract);

    /// @notice Zero address provided as a param to StoryNFTFactory functions.
    error StoryNFTFactory__ZeroAddressParam();

    ////////////////////////////////////////////////////////////////////////////
    //                              Events                                    //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Emitted when the default StoryNFT template is updated.
    /// @param defaultStoryNftTemplate The new default StoryNFT template.
    event StoryNFTFactoryDefaultStoryNftTemplateUpdated(address defaultStoryNftTemplate);

    /// @notice Emitted when a new orgnization NFT is minted and a new StoryNFT associated with it is deployed.
    /// @param orgName The name of the organization.
    /// @param orgNft The address of the organization NFT.
    /// @param orgTokenId The token ID of the organization NFT.
    /// @param orgIpId The ID of the organization IP.
    /// @param storyNft The address of the deployed StoryNFT.
    event StoryNftDeployed(string orgName, address orgNft, uint256 orgTokenId, address orgIpId, address storyNft);

    /// @notice Emitted when the signer of the StoryNFTFactory is updated.
    /// @param signer The new signer of the StoryNFTFactory.
    event StoryNFTFactorySignerUpdated(address signer);

    /// @notice Emitted when a new Story NFT template is whitelisted.
    /// @param nftTemplate The new Story NFT template that is whitelisted to be used in StoryNFTFactory.
    event StoryNFTFactoryNftTemplateWhitelisted(address nftTemplate);

    ////////////////////////////////////////////////////////////////////////////
    //                             Functions                                  //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Mints a new organization NFT and deploys (creates a clone of) `storyNftTemplate` as the StoryNFT
    /// associated with the new organization NFT.
    /// @param storyNftTemplate The address of a whitelisted StoryNFT template to be cloned.
    /// @param orgNftRecipient The address of the recipient of the organization NFT.
    /// @param orgName The name of the organization.
    /// @param orgTokenURI The token URI of the organization NFT.
    /// @param signature The signature from the StoryNFTFactory's whitelist signer. This signautre is genreated by
    /// having the whitelist signer sign the caller's address (msg.sender) for this `deployStoryNft` function.
    /// @param storyNftInitParams The initialization parameters for StoryNFT {see {IStoryNFT-StoryNftInitParams}}.
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
    ) external returns (address orgNft, uint256 orgTokenId, address orgIpId, address storyNft);

    /// @notice Mints a new organization NFT and deploys (creates a clone of) `storyNftTemplate` as the StoryNFT
    /// associated with the new organization NFT.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param storyNftTemplate The address of a whitelisted StoryNFT template to be cloned.
    /// @param orgNftRecipient The address of the recipient of the organization NFT.
    /// @param orgName The name of the organization.
    /// @param orgTokenURI The token URI of the organization NFT.
    /// @param storyNftInitParams The initialization parameters for StoryNFT {see {IStoryNFT-StoryNftInitParams}}.
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
    ) external returns (address orgNft, uint256 orgTokenId, address orgIpId, address storyNft);

    /// @notice Sets the default StoryNFT template of the StoryNFTFactory.
    /// @param defaultStoryNftTemplate The new default StoryNFT template.
    function setDefaultStoryNftTemplate(address defaultStoryNftTemplate) external;

    /// @notice Sets the signer of the StoryNFTFactory.
    /// @param signer The new signer of the StoryNFTFactory.
    function setSigner(address signer) external;

    /// @notice Whitelists a new StoryNFT template.
    /// @param storyNftTemplate The new StoryNFT template to be whitelisted.
    function whitelistNftTemplate(address storyNftTemplate) external;

    /// @notice Returns the default StoryNFT template address.
    function getDefaultStoryNftTemplate() external view returns (address);

    /// @notice Returns the address of the StoryNFT for a given organization name.
    /// @param orgName The name of the organization.
    function getStoryNftAddressByOrgName(string calldata orgName) external view returns (address);

    /// @notice Returns the address of the StoryNFT for a given organization token ID.
    /// @param orgTokenId The token ID of the organization.
    function getStoryNftAddressByOrgTokenId(uint256 orgTokenId) external view returns (address);

    /// @notice Returns the address of the StoryNFT for a given organization IP ID.
    /// @param orgIpId The ID of the organization IP.
    function getStoryNftAddressByOrgIpId(address orgIpId) external view returns (address);

    /// @notice Returns whether a given StoryNFT template is whitelisted.
    /// @param storyNftTemplate The address of the StoryNFT template.
    function isNftTemplateWhitelisted(address storyNftTemplate) external view returns (bool);
}
