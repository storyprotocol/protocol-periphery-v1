// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { console2 } from "forge-std/console2.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { SPGNFTLib } from "../../../contracts/lib/SPGNFTLib.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

/**
 * @title SpgNftIntegration
 * @notice Integration test for SPGNFT with focus on token URI functionality
 */
contract SpgNftIntegration is BaseIntegration {
    using Strings for uint256;

    // Constants
    string private constant CUSTOM_TOKEN_URI = "test-token-uri";
    bytes32 private constant CUSTOM_IP_HASH = bytes32("custom-ip-hash");
    bytes32 private constant CUSTOM_NFT_HASH = bytes32("custom-nft-hash");
    string private constant CUSTOM_IP_URI = "custom-ip-uri";

    // Contract instance
    ISPGNFT private spgNftContract;

    // Events for better traceability
    event TokenURIUpdated(uint256 indexed tokenId, string oldUri, string newUri);

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/SpgNftIntegration.t.sol:SpgNftIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();

        // Create NFT collection with empty baseURI to test setTokenURI more effectively
        spgNftContract = _createNftCollection();

        // Run the test
        _test_SpgNftIntegration_setTokenURI();
        _endBroadcast();
    }

    /**
     * @dev Creates a new NFT collection with test parameters
     * @return ISPGNFT instance of the created collection
     */
    function _createNftCollection() private returns (ISPGNFT) {
        return
            ISPGNFT(
                registrationWorkflows.createCollection(
                    ISPGNFT.InitParams({
                        name: testCollectionName,
                        symbol: testCollectionSymbol,
                        baseURI: testBaseURI,
                        contractURI: testContractURI,
                        maxSupply: testMaxSupply,
                        mintFee: testMintFee,
                        mintFeeToken: testMintFeeToken,
                        mintFeeRecipient: testSender,
                        owner: testSender,
                        mintOpen: true,
                        isPublicMinting: true // Public minting enabled for easy testing
                    })
                )
            );
    }

    /**
     * @dev Test function to verify the setTokenURI functionality
     * The test mints an NFT with empty nftMetadataURI and then sets a custom token URI
     */
    function _test_SpgNftIntegration_setTokenURI()
        private
        logTest("test_SpgNftIntegration_setTokenURI")
    {
        // Prepare token for minting
        _prepareForMinting();

        // Mint and register IP
        (address ipId, uint256 tokenId) = _mintAndRegisterIp(testIpMetadata);

        // Set and verify custom token URI
        _setAndVerifyTokenURI(tokenId);
    }

    /**
     * @dev Prepare for minting by depositing and approving tokens
     */
    function _prepareForMinting() private {
        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);
    }

    /**
     * @dev Mint and register IP using the provided metadata
     * @param ipMetadata Metadata to use for the new IP
     * @return ipId Address of the registered IP
     * @return tokenId ID of the minted token
     */
    function _mintAndRegisterIp(WorkflowStructs.IPMetadata memory ipMetadata) 
        private 
        returns (address ipId, uint256 tokenId) 
    {
        return registrationWorkflows.mintAndRegisterIp({
                spgNftContract: address(spgNftContract),
                recipient: testSender,
                ipMetadata: ipMetadata,
                allowDuplicates: true
            });
    }

    /**
     * @dev Set and verify a custom token URI
     * @param tokenId The token ID to update
     */
    function _setAndVerifyTokenURI(uint256 tokenId) private {
        // Get the initial URI for comparison
        string memory initialUri = spgNftContract.tokenURI(tokenId);
        console2.log("Initial URI:", initialUri);

        assertEq(initialUri, string.concat(testBaseURI, testIpMetadata.nftMetadataURI));

        // Update the token URI
        spgNftContract.setTokenURI(tokenId, CUSTOM_TOKEN_URI);

        // Get and verify the updated URI
        string memory updatedUri = spgNftContract.tokenURI(tokenId);
        console2.log("Updated token URI:", updatedUri);

        assertEq(updatedUri, string.concat(testBaseURI, CUSTOM_TOKEN_URI));
    }
}
