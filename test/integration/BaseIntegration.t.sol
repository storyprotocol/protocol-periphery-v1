// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { WIP } from "@wip/WIP.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { ICoreMetadataViewModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataViewModule.sol";
import { IGroupingModule } from "@storyprotocol/core/interfaces/modules/grouping/IGroupingModule.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";

// contracts
import { DerivativeWorkflows } from "../../contracts/workflows/DerivativeWorkflows.sol";
import { LicenseAttachmentWorkflows } from "../../contracts/workflows/LicenseAttachmentWorkflows.sol";
import { GroupingWorkflows } from "../../contracts/workflows/GroupingWorkflows.sol";
import { RegistrationWorkflows } from "../../contracts/workflows/RegistrationWorkflows.sol";
import { RoyaltyWorkflows } from "../../contracts/workflows/RoyaltyWorkflows.sol";
import { RoyaltyTokenDistributionWorkflows } from "../../contracts/workflows/RoyaltyTokenDistributionWorkflows.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";
import { TotalLicenseTokenLimitHook } from "../../contracts/hooks/TotalLicenseTokenLimitHook.sol";

// script
import { TestHelper } from "../utils/TestHelper.t.sol";
import { StoryProtocolCoreAddressManager } from "../../script/utils/StoryProtocolCoreAddressManager.sol";
import { StoryProtocolPeripheryAddressManager } from "../../script/utils/StoryProtocolPeripheryAddressManager.sol";

contract BaseIntegration is
    Test,
    Script,
    StoryProtocolCoreAddressManager,
    StoryProtocolPeripheryAddressManager,
    TestHelper
{
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
    RoyaltyTokenDistributionWorkflows internal royaltyTokenDistributionWorkflows;
    TotalLicenseTokenLimitHook internal totalLicenseTokenLimitHook;

    /// @dev Wrapped IP token
    WIP internal wrappedIP = WIP(payable(0x1514000000000000000000000000000000000000));

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
        _initializeTestHelper(
            accessControllerAddr,
            coreMetadataModuleAddr,
            coreMetadataViewModuleAddr,
            licenseRegistryAddr,
            licensingModuleAddr
        ); // initialize TestHelper (TestHelper.t.sol)

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
        royaltyTokenDistributionWorkflows = RoyaltyTokenDistributionWorkflows(royaltyTokenDistributionWorkflowsAddr);
        totalLicenseTokenLimitHook = TotalLicenseTokenLimitHook(totalLicenseTokenLimitHookAddr);

        // set up test data
        testCollectionName = "Test Collection";
        testCollectionSymbol = "TEST";
        testBaseURI = "https://test.com/";
        testContractURI = "https://test-contract-uri.com/";
        testMaxSupply = 100_000;
        testMintFee = 1 * 10 ** wrappedIP.decimals(); // 1 WIP
        testMintFeeToken = address(wrappedIP);
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
}
