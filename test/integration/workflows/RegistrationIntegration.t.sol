// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { SPGNFTLib } from "../../../contracts/lib/SPGNFTLib.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

contract RegistrationIntegration is BaseIntegration {
    using Strings for uint256;

    ISPGNFT private spgNftContract;

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/RegistrationIntegration.t.sol:RegistrationIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();
        _test_RegistrationIntegration_createCollection();
        _test_RegistrationIntegration_createCollection();
        _test_RegistrationIntegration_mintAndRegisterIp();
        _test_RegistrationIntegration_registerIp();
        _test_RegistrationIntegration_multicall_createCollection();
        _test_RegistrationIntegration_multicall_mintAndRegisterIp();
        _endBroadcast();
    }

    function _test_RegistrationIntegration_createCollection()
        private
        logTest("test_RegistrationIntegration_createCollection")
    {
        spgNftContract = ISPGNFT(
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

        assertEq(spgNftContract.name(), testCollectionName);
        assertEq(spgNftContract.symbol(), testCollectionSymbol);
        assertEq(spgNftContract.baseURI(), testBaseURI);
        assertEq(spgNftContract.contractURI(), testContractURI);
        assertEq(spgNftContract.totalSupply(), 0);
        assertEq(spgNftContract.mintFee(), testMintFee);
        assertEq(spgNftContract.mintFeeToken(), testMintFeeToken);
        assertEq(spgNftContract.mintFeeRecipient(), testSender);
        assertTrue(spgNftContract.hasRole(SPGNFTLib.MINTER_ROLE, testSender));
        assertTrue(spgNftContract.hasRole(SPGNFTLib.ADMIN_ROLE, testSender));
        assertTrue(spgNftContract.mintOpen());
        assertTrue(spgNftContract.publicMinting());
    }

    function _test_RegistrationIntegration_mintAndRegisterIp()
        private
        logTest("test_RegistrationIntegration_mintAndRegisterIp")
    {
        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);
        (address ipId, uint256 tokenId) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftContract),
            recipient: testSender,
            ipMetadata: testIpMetadata,
            allowDuplicates: true
        });

        assertEq(tokenId, 1);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(spgNftContract.tokenURI(tokenId), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
        assertMetadata(ipId, testIpMetadata);
    }

    function _test_RegistrationIntegration_registerIp() private logTest("test_RegistrationIntegration_registerIp") {
        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);
        uint256 tokenId = spgNftContract.mint(testSender, "", bytes32(0), true);

        // get signature for setting IP metadata
        uint256 deadline = block.timestamp + 1000;
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId);
        (bytes memory sigMetadata, bytes32 expectedState) = _getSigForExecuteWithSig({
            ipId: expectedIpId,
            to: coreMetadataModuleAddr,
            deadline: deadline,
            state: bytes32(0),
            data: abi.encodeWithSelector(
                ICoreMetadataModule.setAll.selector,
                expectedIpId,
                testIpMetadata.ipMetadataURI,
                testIpMetadata.ipMetadataHash,
                testIpMetadata.nftMetadataHash
            ),
            signerSk: testSenderSk
        });

        address actualIpId = registrationWorkflows.registerIp({
            nftContract: address(spgNftContract),
            tokenId: tokenId,
            ipMetadata: testIpMetadata,
            sigMetadata: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadata
            })
        });

        assertEq(actualIpId, expectedIpId);
        assertEq(IIPAccount(payable(actualIpId)).state(), expectedState);
        assertTrue(ipAssetRegistry.isRegistered(actualIpId));
        assertEq(spgNftContract.tokenURI(tokenId), string.concat(testBaseURI, tokenId.toString()));
        assertMetadata(actualIpId, testIpMetadata);
    }

    function _test_RegistrationIntegration_multicall_createCollection()
        private
        logTest("test_RegistrationIntegration_multicall_createCollection")
    {
        uint256 totalCollections = 10;

        ISPGNFT[] memory nftContracts = new ISPGNFT[](totalCollections);
        bytes[] memory data = new bytes[](totalCollections);
        for (uint256 i = 0; i < totalCollections; i++) {
            data[i] = abi.encodeWithSelector(
                registrationWorkflows.createCollection.selector,
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
                    isPublicMinting: false
                })
            );
        }

        bytes[] memory results = registrationWorkflows.multicall(data);
        for (uint256 i = 0; i < totalCollections; i++) {
            nftContracts[i] = ISPGNFT(abi.decode(results[i], (address)));
        }

        for (uint256 i = 0; i < totalCollections; i++) {
            assertEq(nftContracts[i].name(), testCollectionName);
            assertEq(nftContracts[i].symbol(), testCollectionSymbol);
            assertEq(nftContracts[i].totalSupply(), 0);
            assertTrue(nftContracts[i].hasRole(SPGNFTLib.MINTER_ROLE, testSender));
            assertEq(nftContracts[i].mintFee(), testMintFee);
            assertEq(nftContracts[i].mintFeeToken(), testMintFeeToken);
            assertEq(nftContracts[i].mintFeeRecipient(), testSender);
            assertTrue(nftContracts[i].mintOpen());
            assertFalse(nftContracts[i].publicMinting());
            assertEq(nftContracts[i].contractURI(), testContractURI);
        }
    }

    function _test_RegistrationIntegration_multicall_mintAndRegisterIp()
        private
        logTest("test_RegistrationIntegration_multicall_mintAndRegisterIp")
    {
        uint256 totalIps = 10;
        StoryUSD.mint(testSender, testMintFee * totalIps);
        StoryUSD.approve(address(spgNftContract), testMintFee * totalIps);

        bytes[] memory data = new bytes[](totalIps);
        for (uint256 i = 0; i < totalIps; i++) {
            data[i] = abi.encodeWithSelector(
                registrationWorkflows.mintAndRegisterIp.selector,
                address(spgNftContract),
                testSender,
                testIpMetadata
            );
        }
        bytes[] memory results = registrationWorkflows.multicall(data);
        address[] memory ipIds = new address[](totalIps);
        uint256[] memory tokenIds = new uint256[](totalIps);

        for (uint256 i = 0; i < totalIps; i++) {
            (ipIds[i], tokenIds[i]) = abi.decode(results[i], (address, uint256));
            assertTrue(ipAssetRegistry.isRegistered(ipIds[i]));
            assertEq(spgNftContract.tokenURI(tokenIds[i]), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipIds[i], testIpMetadata);
        }
    }
}
