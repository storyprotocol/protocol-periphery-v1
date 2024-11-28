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

    /// @dev Get the permission list for setting metadata and attaching license terms for the IP.
    /// @param ipId The ID of the IP that the permissions are for.
    /// @param to The address of the periphery contract to receive the permission.
    /// @return permissionList The list of permissions for setting metadata and attaching license terms.
    function _getMetadataAndAttachTermsPermissionList(
        address ipId,
        address to
    ) internal view returns (AccessPermission.Permission[] memory permissionList) {
        address[] memory modules = new address[](2);
        bytes4[] memory selectors = new bytes4[](2);
        permissionList = new AccessPermission.Permission[](2);

        modules[0] = coreMetadataModuleAddr;
        modules[1] = licensingModuleAddr;
        selectors[0] = ICoreMetadataModule.setAll.selector;
        selectors[1] = ILicensingModule.attachLicenseTerms.selector;

        for (uint256 i = 0; i < 2; i++) {
            permissionList[i] = AccessPermission.Permission({
                ipAccount: ipId,
                signer: to,
                to: modules[i],
                func: selectors[i],
                permission: AccessPermission.ALLOW
            });
        }
    }

    /// @dev Get the signature for setting batch permission for the IP by the SPG.
    /// @param ipId The ID of the IP to set the permissions for.
    /// @param permissionList A list of permissions to set.
    /// @param deadline The deadline for the signature.
    /// @param state IPAccount's internal state
    /// @param signerSk The secret key of the signer.
    /// @return signature The signature for setting the batch permission.
    /// @return expectedState The expected IPAccount's state after setting batch permission.
    /// @return data The call data for executing the setBatchPermissions function.
    function _getSetBatchPermissionSigForPeriphery(
        address ipId,
        AccessPermission.Permission[] memory permissionList,
        uint256 deadline,
        bytes32 state,
        uint256 signerSk
    ) internal view returns (bytes memory signature, bytes32 expectedState, bytes memory data) {
        expectedState = keccak256(
            abi.encode(
                state, // ipAccount.state()
                abi.encodeWithSelector(
                    IIPAccount.execute.selector,
                    address(accessControllerAddr),
                    0, // amount of ether to send
                    abi.encodeWithSelector(IAccessController.setBatchPermissions.selector, permissionList)
                )
            )
        );

        data = abi.encodeWithSelector(IAccessController.setBatchPermissions.selector, permissionList);

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(ipId),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(accessControllerAddr),
                    value: 0,
                    data: data,
                    nonce: expectedState,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /// @dev Get the signature for setting permission for the IP by the SPG.
    /// @param ipId The ID of the IP.
    /// @param to The address of the periphery contract to receive the permission.
    /// @param module The address of the module to set the permission for.
    /// @param selector The selector of the function to be permitted for execution.
    /// @param deadline The deadline for the signature.
    /// @param state IPAccount's internal nonce
    /// @param signerSk The secret key of the signer.
    /// @return signature The signature for setting the permission.
    /// @return expectedState The expected IPAccount's state after setting the permission.
    /// @return data The call data for executing the setPermission function.
    function _getSetPermissionSigForPeriphery(
        address ipId,
        address to,
        address module,
        bytes4 selector,
        uint256 deadline,
        bytes32 state,
        uint256 signerSk
    ) internal view returns (bytes memory signature, bytes32 expectedState, bytes memory data) {
        expectedState = keccak256(
            abi.encode(
                state, // ipAccount.state()
                abi.encodeWithSelector(
                    IIPAccount.execute.selector,
                    address(accessControllerAddr),
                    0, // amount of ether to send
                    abi.encodeWithSelector(
                        IAccessController.setPermission.selector,
                        ipId,
                        to,
                        address(module),
                        selector,
                        AccessPermission.ALLOW
                    )
                )
            )
        );

        data = abi.encodeWithSelector(
            IAccessController.setPermission.selector,
            ipId,
            to,
            address(module),
            selector,
            AccessPermission.ALLOW
        );

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(ipId),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(accessControllerAddr),
                    value: 0,
                    data: data,
                    nonce: expectedState,
                    deadline: deadline
                })
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
