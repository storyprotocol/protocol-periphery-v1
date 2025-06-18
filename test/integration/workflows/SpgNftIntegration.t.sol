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
import { IERC7572 } from "../../../contracts/interfaces/story-nft/IERC7572.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

/**
 * @title SpgNftIntegration
 * @notice Integration test for SPGNFT with focus on token URI functionality
 */
contract SpgNftIntegration is BaseIntegration {
    string private constant CUSTOM_TOKEN_URI = "test-token-uri";

    ISPGNFT private spgNftContract;

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/SpgNftIntegration.t.sol:SpgNftIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();

        // Create SPG NFT collection
        spgNftContract = _createNftCollection();

        // Run the tests
        _test_SpgNftIntegration_setTokenURI();
        _test_SpgNftIntegration_contractURI();
        _endBroadcast();
    }

    /**
     * @dev Test function to verify the setTokenURI functionality
     */
    function _test_SpgNftIntegration_setTokenURI() private logTest("test_SpgNftIntegration_setTokenURI") {
        wrappedIP.deposit{ value: testMintFee }();
        wrappedIP.approve(address(spgNftContract), testMintFee);

        // Mint and register IP
        (address ipId, uint256 tokenId) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftContract),
            recipient: testSender,
            ipMetadata: testIpMetadata,
            allowDuplicates: true
        });

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

    /**
     * @dev Test function to verify the contractURI functionality and ContractURIUpdated event
     */
    function _test_SpgNftIntegration_contractURI() private logTest("test_SpgNftIntegration_contractURI") {
        // Verify initial contract URI
        assertEq(spgNftContract.contractURI(), testContractURI);

        // Test setting new contract URI
        string memory newContractURI = "new-contract-uri";
        vm.expectEmit(address(spgNftContract));
        emit IERC7572.ContractURIUpdated();
        spgNftContract.setContractURI(newContractURI);
        assertEq(spgNftContract.contractURI(), newContractURI);

        // Test setting back to original contract URI
        vm.expectEmit(address(spgNftContract));
        emit IERC7572.ContractURIUpdated();
        spgNftContract.setContractURI(testContractURI);
        assertEq(spgNftContract.contractURI(), testContractURI);
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
                        isPublicMinting: true
                    })
                )
            );
    }
}
