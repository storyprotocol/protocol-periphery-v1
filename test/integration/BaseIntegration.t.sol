// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { SUSD } from "@storyprotocol/test/mocks/token/SUSD.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { ICoreMetadataViewModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataViewModule.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { MetaTx } from "@storyprotocol/core/lib/MetaTx.sol";
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";

// contracts
import { DerivativeWorkflows } from "../../contracts/workflows/DerivativeWorkflows.sol";
import { LicenseAttachmentWorkflows } from "../../contracts/workflows/LicenseAttachmentWorkflows.sol";
import { GroupingWorkflows } from "../../contracts/workflows/GroupingWorkflows.sol";
import { RegistrationWorkflows } from "../../contracts/workflows/RegistrationWorkflows.sol";
import { RoyaltyWorkflows } from "../../contracts/workflows/RoyaltyWorkflows.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// script
import { StoryProtocolCoreAddressManager } from "../../script/utils/StoryProtocolCoreAddressManager.sol";
import { StoryProtocolPeripheryAddressManager } from "../../script/utils/StoryProtocolPeripheryAddressManager.sol";

contract BaseIntegration is Test, Script, StoryProtocolCoreAddressManager, StoryProtocolPeripheryAddressManager {
    /// @dev Test user
    address internal testSender;
    uint256 internal testSenderSk;

    /// @dev Core contracts
    ICoreMetadataViewModule internal coreMetadataViewModule;
    IGroupingModule internal groupingModule;
    IIPAssetRegistry internal ipAssetRegistry;
    ILicenseRegistry internal licenseRegistry;
    ILicenseToken internal licenseToken;
    ILicensingModule internal licensingModule;
    IPILicenseTemplate internal pilTemplate;
    IRoyaltyModule internal royaltyModule;

    /// @dev Periphery contracts
    DerivativeWorkflows internal derivativeWorkflows;
    LicenseAttachmentWorkflows internal licenseAttachmentWorkflows;
    GroupingWorkflows internal groupingWorkflows;
    RegistrationWorkflows internal registrationWorkflows;
    RoyaltyWorkflows internal royaltyWorkflows;

    /// @dev Story USD
    SUSD internal StoryUSD = SUSD(0x6058bB8A2a51a8e63Bd18cE897D08616331C25a7);

    /// @dev Test data
    string internal testCollectionName;
    string internal testCollectionSymbol;
    string internal testBaseURI;
    string internal testContractURI;
    uint32 internal testMaxSupply;
    uint256 internal testMintFee;
    address internal testMintFeeToken;
    WorkflowStructs.IPMetadata internal testIpMetadata;

    modifier logTest(string memory testName) {
        console2.log(unicode"🏃 Running", testName, "...");
        _;
        console2.log(unicode"✅", testName, "passed!");
    }

    function run() public virtual {
        // mock IPGraph precompile
        vm.etch(address(0x0101), address(new MockIPGraph()).code);
        _setUp();
    }

    function _setUp() internal {
        _readStoryProtocolCoreAddresses(); // StoryProtocolCoreAddressManager
        _readStoryProtocolPeripheryAddresses(); // StoryProtocolPeripheryAddressManager

        // read tester info from .env
        testSender = vm.envAddress("TEST_SENDER_ADDRESS");
        testSenderSk = vm.envUint("TEST_SENDER_SECRETKEY");

        // set up core contracts
        coreMetadataViewModule = ICoreMetadataViewModule(coreMetadataViewModuleAddr);
        groupingModule = IGroupingModule(groupingModuleAddr);
        ipAssetRegistry = IIPAssetRegistry(ipAssetRegistryAddr);
        licenseRegistry = ILicenseRegistry(licenseRegistryAddr);
        licenseToken = ILicenseToken(licenseTokenAddr);
        licensingModule = ILicensingModule(licensingModuleAddr);
        pilTemplate = IPILicenseTemplate(pilTemplateAddr);
        royaltyModule = IRoyaltyModule(royaltyModuleAddr);

        // set up periphery contracts
        derivativeWorkflows = DerivativeWorkflows(derivativeWorkflowsAddr);
        licenseAttachmentWorkflows = LicenseAttachmentWorkflows(licenseAttachmentWorkflowsAddr);
        groupingWorkflows = GroupingWorkflows(groupingWorkflowsAddr);
        registrationWorkflows = RegistrationWorkflows(registrationWorkflowsAddr);
        royaltyWorkflows = RoyaltyWorkflows(royaltyWorkflowsAddr);

        // set up test data
        testCollectionName = "Test Collection";
        testCollectionSymbol = "TEST";
        testBaseURI = "https://test.com/";
        testContractURI = "https://test-contract-uri.com/";
        testMaxSupply = 100_000;
        testMintFee = 10 * 10 ** StoryUSD.decimals(); // 10 SUSD
        testMintFeeToken = address(StoryUSD);
        testIpMetadata = WorkflowStructs.IPMetadata({
            ipMetadataURI: "test-ip-uri",
            ipMetadataHash: "test-ip-hash",
            nftMetadataURI: "test-nft-uri",
            nftMetadataHash: "test-nft-hash"
        });
    }

    function _beginBroadcast() internal {
        vm.startBroadcast(testSenderSk);
    }

    function _endBroadcast() internal {
        vm.stopBroadcast();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/
    /// @dev Get the signature for executing a function on behalf of the IP via {IIPAccount.executeWithSig}.
    /// @param ipId The ID of the IP whose account will execute the function.
    /// @param to The address of the contract to execute the function on.
    /// @param deadline The deadline for the signature.
    /// @param state IPAccount's internal nonce
    /// @param data the call data for the function.
    /// @param signerSk The secret key of the signer.
    /// @return signature The signature for executing the function.
    /// @return expectedState The expected IPAccount's state after executing the function.
    function _getSigForExecuteWithSig(
        address ipId,
        address to,
        uint256 deadline,
        bytes32 state,
        bytes memory data,
        uint256 signerSk
    ) internal view returns (bytes memory signature, bytes32 expectedState) {
        expectedState = keccak256(
            abi.encode(
                state, // ipAccount.state()
                abi.encodeWithSelector(
                    IIPAccount.execute.selector,
                    to, // to
                    0, // value
                    data
                )
            )
        );

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(ipId),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({ to: to, value: 0, data: data, nonce: expectedState, deadline: deadline })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /// @dev Assert metadata for the IP.
    function assertMetadata(address ipId, WorkflowStructs.IPMetadata memory expectedMetadata) internal view {
        assertEq(coreMetadataViewModule.getMetadataURI(ipId), expectedMetadata.ipMetadataURI);
        assertEq(coreMetadataViewModule.getMetadataHash(ipId), expectedMetadata.ipMetadataHash);
        assertEq(coreMetadataViewModule.getNftMetadataHash(ipId), expectedMetadata.nftMetadataHash);
    }
}
