// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { Test } from "forge-std/Test.sol";
import { Create3Deployer, ICreate3Deployer } from "@create3-deployer/contracts/Create3Deployer.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { IPAccountImpl } from "@storyprotocol/core/IPAccountImpl.sol";
import { LicenseToken } from "@storyprotocol/core/LicenseToken.sol";
import { AccessController } from "@storyprotocol/core/access/AccessController.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";
import { ModuleRegistry } from "@storyprotocol/core/registries/ModuleRegistry.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import { DisputeModule } from "@storyprotocol/core/modules/dispute/DisputeModule.sol";
import { RoyaltyModule } from "@storyprotocol/core/modules/royalty/RoyaltyModule.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { IpRoyaltyVault } from "@storyprotocol/core/modules/royalty/policies/IpRoyaltyVault.sol";
import { CoreMetadataModule } from "@storyprotocol/core/modules/metadata/CoreMetadataModule.sol";
import { CoreMetadataViewModule } from "@storyprotocol/core/modules/metadata/CoreMetadataViewModule.sol";
import { LicenseToken } from "@storyprotocol/core/LicenseToken.sol";
import { GroupNFT } from "@storyprotocol/core/GroupNFT.sol";
import { MetaTx } from "@storyprotocol/core/lib/MetaTx.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";
import { GroupingModule } from "@storyprotocol/core/modules/grouping/GroupingModule.sol";
import { IPGraphACL } from "@storyprotocol/core/access/IPGraphACL.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";

import { StoryProtocolGateway } from "../../contracts/StoryProtocolGateway.sol";
import { IStoryProtocolGateway as ISPG } from "../../contracts/interfaces/IStoryProtocolGateway.sol";
import { GroupingWorkflows } from "../../contracts/GroupingWorkflows.sol";
import { SPGNFT } from "../../contracts/SPGNFT.sol";
import { ISPGNFT } from "../../contracts/interfaces/ISPGNFT.sol";
import { TestProxyHelper } from "./TestProxyHelper.t.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockIPGraph } from "../mocks/MockIPGraph.sol";
import { MockEvenSplitGroupPool } from "../mocks/MockEvenSplitGroupPool.sol";

/// @title Base Test Contract
contract BaseTest is Test {
    uint256 internal create3SaltSeed;

    // PROXY 1967 IMPLEMENTATION STORAGE SLOTS
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    ICreate3Deployer internal create3Deployer;

    AccessManager internal protocolAccessManager;
    AccessController internal accessController;
    ModuleRegistry internal moduleRegistry;
    IPAssetRegistry internal ipAssetRegistry;
    LicenseRegistry internal licenseRegistry;
    LicensingModule internal licensingModule;
    RoyaltyModule internal royaltyModule;
    RoyaltyPolicyLAP internal royaltyPolicyLAP;
    UpgradeableBeacon internal ipRoyaltyVaultBeacon;
    IpRoyaltyVault internal ipRoyaltyVaultImpl;
    CoreMetadataModule internal coreMetadataModule;
    CoreMetadataViewModule internal coreMetadataViewModule;
    PILicenseTemplate internal pilTemplate;
    LicenseToken internal licenseToken;
    GroupingModule internal groupingModule;
    GroupNFT internal groupNFT;
    IPGraphACL internal ipGraphACL;
    MockEvenSplitGroupPool public rewardPool;

    StoryProtocolGateway internal spg;
    SPGNFT internal spgNftImpl;
    UpgradeableBeacon internal spgNftBeacon;
    GroupingWorkflows internal groupingWorkflows;

    MockERC20 internal mockToken;
    MockIPGraph internal ipGraph = MockIPGraph(address(0x1A));

    uint256 internal deployerPk = 0xddd111;
    uint256 internal alicePk = 0xa11ce;
    uint256 internal bobPk = 0xb0b;
    uint256 internal calPk = 0xca1;

    address payable internal deployer = payable(vm.addr(deployerPk));
    address payable internal alice = payable(vm.addr(alicePk));
    address payable internal bob = payable(vm.addr(bobPk));
    address payable internal cal = payable(vm.addr(calPk));

    address internal minter;
    address internal caller;
    address internal feeRecipient;

    ISPGNFT internal nftContract;
    ISPGNFT[] internal nftContracts;

    ISPG.IPMetadata internal ipMetadataEmpty;
    ISPG.IPMetadata internal ipMetadataDefault;

    modifier withCollection() {
        nftContract = SPGNFT(
            spg.createCollection({
                name: "Test Collection",
                symbol: "TEST",
                maxSupply: 100,
                mintFee: 100 * 10 ** mockToken.decimals(),
                mintFeeToken: address(mockToken),
                mintFeeRecipient: feeRecipient,
                owner: minter,
                mintOpen: true,
                isPublicMinting: false
            })
        );
        _;
    }

    modifier whenCallerHasMinterRole() {
        caller = alice;
        vm.startPrank(caller);
        _;
    }

    modifier withEnoughTokens() {
        require(caller != address(0), "withEnoughTokens: caller not set");
        mockToken.mint(address(caller), 10000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 10000 * 10 ** mockToken.decimals());
        mockToken.approve(address(spg), 10000 * 10 ** mockToken.decimals());
        _;
    }

    function setUp() public virtual {
        create3Deployer = new Create3Deployer();
        create3SaltSeed = 1;

        vm.etch(address(0x1A), address(new MockIPGraph()).code);
        vm.startPrank(deployer);
        setUp_test_Core();
        setUp_test_Periphery();
        setUp_test_Misc();
        vm.stopPrank();
    }

    function setUp_test_Core() public {
        address impl = address(0); // Make sure we don't deploy wrong impl

        ERC6551Registry erc6551Registry = new ERC6551Registry();

        protocolAccessManager = AccessManager(
            create3Deployer.deploy(
                _getSalt(type(AccessManager).name),
                abi.encodePacked(type(AccessManager).creationCode, abi.encode(deployer))
            )
        );
        require(
            _getDeployedAddress(type(AccessManager).name) == address(protocolAccessManager),
            "Deploy: Protocol Access Manager Address Mismatch"
        );

        impl = address(new ModuleRegistry());
        moduleRegistry = ModuleRegistry(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(ModuleRegistry).name),
                impl,
                abi.encodeCall(ModuleRegistry.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(ModuleRegistry).name) == address(moduleRegistry),
            "Deploy: Module Registry Address Mismatch"
        );
        require(_loadProxyImpl(address(moduleRegistry)) == impl, "ModuleRegistry Proxy Implementation Mismatch");

        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(
            new IPAssetRegistry(
                address(erc6551Registry),
                _getDeployedAddress(type(IPAccountImpl).name),
                _getDeployedAddress(type(GroupingModule).name)
            )
        );
        ipAssetRegistry = IPAssetRegistry(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(IPAssetRegistry).name),
                impl,
                abi.encodeCall(IPAssetRegistry.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(IPAssetRegistry).name) == address(ipAssetRegistry),
            "Deploy: IP Asset Registry Address Mismatch"
        );
        require(_loadProxyImpl(address(ipAssetRegistry)) == impl, "IPAssetRegistry Proxy Implementation Mismatch");

        impl = address(0); // Make sure we don't deploy wrong impl
        address ipAccountRegistry = address(ipAssetRegistry);

        impl = address(new AccessController(address(ipAssetRegistry), address(moduleRegistry)));
        accessController = AccessController(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(AccessController).name),
                impl,
                abi.encodeCall(AccessController.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(AccessController).name) == address(accessController),
            "Deploy: Access Controller Address Mismatch"
        );
        require(_loadProxyImpl(address(accessController)) == impl, "AccessController Proxy Implementation Mismatch");

        ipGraphACL = new IPGraphACL(address(protocolAccessManager));
        ipGraphACL.whitelistAddress(_getDeployedAddress(type(RoyaltyPolicyLAP).name));
        ipGraphACL.whitelistAddress(_getDeployedAddress(type(LicenseRegistry).name));

        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(
            new LicenseRegistry(
                _getDeployedAddress(type(LicensingModule).name),
                _getDeployedAddress(type(DisputeModule).name),
                address(ipGraphACL)
            )
        );

        licenseRegistry = LicenseRegistry(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(LicenseRegistry).name),
                impl,
                abi.encodeCall(LicenseRegistry.initialize, (address(protocolAccessManager)))
            )
        );
        require(
            _getDeployedAddress(type(LicenseRegistry).name) == address(licenseRegistry),
            "Deploy: License Registry Address Mismatch"
        );
        require(_loadProxyImpl(address(licenseRegistry)) == impl, "LicenseRegistry Proxy Implementation Mismatch");

        bytes memory ipAccountImplCode = abi.encodePacked(
            type(IPAccountImpl).creationCode,
            abi.encode(
                address(accessController),
                address(ipAssetRegistry),
                address(licenseRegistry),
                address(moduleRegistry)
            )
        );
        IPAccountImpl ipAccountImpl = IPAccountImpl(
            payable(create3Deployer.deploy(_getSalt(type(IPAccountImpl).name), ipAccountImplCode))
        );
        require(
            _getDeployedAddress(type(IPAccountImpl).name) == address(ipAccountImpl),
            "Deploy: IP Account Impl Address Mismatch"
        );

        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(
            new DisputeModule(address(accessController), address(ipAssetRegistry), address(licenseRegistry))
        );
        DisputeModule disputeModule = DisputeModule(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(DisputeModule).name),
                impl,
                abi.encodeCall(DisputeModule.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(DisputeModule).name) == address(disputeModule),
            "Deploy: Dispute Module Address Mismatch"
        );
        require(_loadProxyImpl(address(disputeModule)) == impl, "DisputeModule Proxy Implementation Mismatch");

        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(
            new RoyaltyModule(
                _getDeployedAddress(type(LicensingModule).name),
                address(disputeModule),
                address(licenseRegistry),
                address(ipAssetRegistry)
            )
        );
        royaltyModule = RoyaltyModule(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RoyaltyModule).name),
                impl,
                abi.encodeCall(RoyaltyModule.initialize, (address(protocolAccessManager), 1024, 1024, 10))
            )
        );
        require(
            _getDeployedAddress(type(RoyaltyModule).name) == address(royaltyModule),
            "Deploy: Royalty Module Address Mismatch"
        );
        require(_loadProxyImpl(address(royaltyModule)) == impl, "RoyaltyModule Proxy Implementation Mismatch");

        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(
            new LicensingModule(
                address(accessController),
                address(ipAccountRegistry),
                address(moduleRegistry),
                address(royaltyModule),
                address(licenseRegistry),
                address(disputeModule),
                _getDeployedAddress(type(LicenseToken).name)
            )
        );
        licensingModule = LicensingModule(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(LicensingModule).name),
                impl,
                abi.encodeCall(LicensingModule.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(LicensingModule).name) == address(licensingModule),
            "Deploy: Licensing Module Address Mismatch"
        );
        require(_loadProxyImpl(address(licensingModule)) == impl, "LicensingModule Proxy Implementation Mismatch");

        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(new RoyaltyPolicyLAP(address(royaltyModule), address(licensingModule), address(ipGraphACL)));
        royaltyPolicyLAP = RoyaltyPolicyLAP(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RoyaltyPolicyLAP).name),
                impl,
                abi.encodeCall(RoyaltyPolicyLAP.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(RoyaltyPolicyLAP).name) == address(royaltyPolicyLAP),
            "Deploy: Royalty Policy LAP Address Mismatch"
        );
        require(_loadProxyImpl(address(royaltyPolicyLAP)) == impl, "RoyaltyPolicyLAP Proxy Implementation Mismatch");

        ipRoyaltyVaultImpl = IpRoyaltyVault(
            create3Deployer.deploy(
                _getSalt(type(IpRoyaltyVault).name),
                abi.encodePacked(
                    type(IpRoyaltyVault).creationCode,
                    abi.encode(address(disputeModule), address(royaltyModule))
                )
            )
        );

        ipRoyaltyVaultBeacon = UpgradeableBeacon(
            create3Deployer.deploy(
                _getSalt("ipRoyaltyVaultBeacon"),
                abi.encodePacked(
                    type(UpgradeableBeacon).creationCode,
                    abi.encode(address(ipRoyaltyVaultImpl), deployer)
                )
            )
        );

        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(new LicenseToken(address(licensingModule), address(disputeModule)));
        licenseToken = LicenseToken(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(LicenseToken).name),
                impl,
                abi.encodeCall(
                    LicenseToken.initialize,
                    (
                        address(protocolAccessManager),
                        "https://github.com/storyprotocol/protocol-core/blob/main/assets/license-image.gif"
                    )
                )
            )
        );
        require(
            _getDeployedAddress(type(LicenseToken).name) == address(licenseToken),
            "Deploy: License Token Address Mismatch"
        );
        require(_loadProxyImpl(address(licenseToken)) == impl, "LicenseToken Proxy Implementation Mismatch");

        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(
            new PILicenseTemplate(
                address(accessController),
                address(ipAccountRegistry),
                address(licenseRegistry),
                address(royaltyModule)
            )
        );
        pilTemplate = PILicenseTemplate(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(PILicenseTemplate).name),
                impl,
                abi.encodeCall(
                    PILicenseTemplate.initialize,
                    (
                        address(protocolAccessManager),
                        "pil",
                        "https://github.com/storyprotocol/protocol-core/blob/main/PIL_Beta_Final_2024_02.pdf"
                    )
                )
            )
        );
        require(
            _getDeployedAddress(type(PILicenseTemplate).name) == address(pilTemplate),
            "Deploy: PI License Template Address Mismatch"
        );
        require(_loadProxyImpl(address(pilTemplate)) == impl, "PILicenseTemplate Proxy Implementation Mismatch");

        coreMetadataModule = CoreMetadataModule(
            create3Deployer.deploy(
                _getSalt(type(CoreMetadataModule).name),
                abi.encodePacked(
                    type(CoreMetadataModule).creationCode,
                    abi.encode(address(accessController), address(ipAssetRegistry))
                )
            )
        );

        coreMetadataViewModule = CoreMetadataViewModule(
            create3Deployer.deploy(
                _getSalt(type(CoreMetadataViewModule).name),
                abi.encodePacked(
                    type(CoreMetadataViewModule).creationCode,
                    abi.encode(address(ipAssetRegistry), address(moduleRegistry))
                )
            )
        );

        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(new GroupNFT(_getDeployedAddress(type(GroupingModule).name)));
        groupNFT = GroupNFT(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(GroupNFT).name),
                impl,
                abi.encodeCall(
                    GroupNFT.initialize,
                    (
                        address(protocolAccessManager),
                        "https://github.com/storyprotocol/protocol-core/blob/main/assets/license-image.gif"
                    )
                )
            )
        );
        require(_getDeployedAddress(type(GroupNFT).name) == address(groupNFT), "Deploy: Group NFT Address Mismatch");
        require(_loadProxyImpl(address(groupNFT)) == impl, "GroupNFT Proxy Implementation Mismatch");

        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(
            new GroupingModule(
                address(accessController),
                address(ipAssetRegistry),
                address(licenseRegistry),
                address(licenseToken),
                address(groupNFT)
            )
        );
        groupingModule = GroupingModule(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(GroupingModule).name),
                impl,
                abi.encodeCall(GroupingModule.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(GroupingModule).name) == address(groupingModule),
            "Deploy: Grouping Module Address Mismatch"
        );
        require(_loadProxyImpl(address(groupingModule)) == impl, "GroupingModule Proxy Implementation Mismatch");

        moduleRegistry.registerModule("DISPUTE_MODULE", address(disputeModule));
        moduleRegistry.registerModule("LICENSING_MODULE", address(licensingModule));
        moduleRegistry.registerModule("ROYALTY_MODULE", address(royaltyModule));
        moduleRegistry.registerModule("CORE_METADATA_MODULE", address(coreMetadataModule));
        moduleRegistry.registerModule("CORE_METADATA_VIEW_MODULE", address(coreMetadataViewModule));
        moduleRegistry.registerModule("GROUPING_MODULE", address(groupingModule));

        coreMetadataViewModule.updateCoreMetadataModule();
        licenseRegistry.registerLicenseTemplate(address(pilTemplate));

        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        royaltyModule.setIpRoyaltyVaultBeacon(address(ipRoyaltyVaultBeacon));
        ipRoyaltyVaultBeacon.transferOwnership(address(royaltyPolicyLAP));
    }

    function setUp_test_Periphery() public {
        address impl = address(
            new StoryProtocolGateway(
                address(accessController),
                address(ipAssetRegistry),
                address(licensingModule),
                address(licenseRegistry),
                address(royaltyModule),
                address(coreMetadataModule),
                address(pilTemplate),
                address(licenseToken)
            )
        );
        spg = StoryProtocolGateway(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(StoryProtocolGateway).name),
                impl,
                abi.encodeCall(StoryProtocolGateway.initialize, address(protocolAccessManager))
            )
        );

        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(
            new GroupingWorkflows(
                address(accessController),
                address(coreMetadataModule),
                address(groupingModule),
                address(groupNFT),
                address(ipAssetRegistry),
                address(licensingModule),
                address(licenseRegistry),
                address(pilTemplate)
            )
        );

        groupingWorkflows = GroupingWorkflows(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(GroupingWorkflows).name),
                impl,
                abi.encodeCall(GroupingWorkflows.initialize, address(protocolAccessManager))
            )
        );

        spgNftImpl = SPGNFT(
            create3Deployer.deploy(
                _getSalt(type(SPGNFT).name),
                abi.encodePacked(type(SPGNFT).creationCode, abi.encode(address(spg), address(groupingWorkflows)))
            )
        );

        spgNftBeacon = UpgradeableBeacon(
            create3Deployer.deploy(
                _getSalt(type(UpgradeableBeacon).name),
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(address(spgNftImpl), deployer))
            )
        );

        spg.setNftContractBeacon(address(spgNftBeacon));
        groupingWorkflows.setNftContractBeacon(address(spgNftBeacon));

        // bytes4[] memory selectors = new bytes4[](1);
        // selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;
        // protocolAccessManager.setTargetFunctionRole(address(spg), selectors, ProtocolAdmin.UPGRADER_ROLE);
        // protocolAccessManager.setTargetFunctionRole(address(spgNftBeacon), selectors, ProtocolAdmin.UPGRADER_ROLE);
    }

    function setUp_test_Misc() public {
        mockToken = new MockERC20();
        rewardPool = new MockEvenSplitGroupPool();

        royaltyModule.whitelistRoyaltyToken(address(mockToken), true);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), 0);
        groupingModule.whitelistGroupRewardPool(address(rewardPool));

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(cal, "Cal");

        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.deal(cal, 1000 ether);

        ipMetadataEmpty = ISPG.IPMetadata({
            ipMetadataURI: "",
            ipMetadataHash: "",
            nftMetadataURI: "",
            nftMetadataHash: ""
        });

        ipMetadataDefault = ISPG.IPMetadata({
            ipMetadataURI: "test-ip-uri",
            ipMetadataHash: "test-ip-hash",
            nftMetadataURI: "test-nft-uri",
            nftMetadataHash: "test-nft-hash"
        });
    }

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
        permissionList = new AccessPermission.Permission[](modules.length);

        modules[0] = address(coreMetadataModule);
        modules[1] = address(licensingModule);
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
    /// @param signerPk The private key of the signer.
    /// @return signature The signature for setting the batch permission.
    /// @return expectedState The expected IPAccount's state after setting batch permission.
    /// @return data The call data for executing the setBatchPermissions function.
    function _getSetBatchPermissionSigForPeriphery(
        address ipId,
        AccessPermission.Permission[] memory permissionList,
        uint256 deadline,
        bytes32 state,
        uint256 signerPk
    ) internal view returns (bytes memory signature, bytes32 expectedState, bytes memory data) {
        expectedState = keccak256(
            abi.encode(
                state, // ipAccount.state()
                abi.encodeWithSelector(
                    IIPAccount.execute.selector,
                    address(accessController),
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
                    to: address(accessController),
                    value: 0,
                    data: data,
                    nonce: expectedState,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /// @dev Get the signature for setting permission for the IP by the SPG.
    /// @param ipId The ID of the IP.
    /// @param to The address of the periphery contract to receive the permission.
    /// @param module The address of the module to set the permission for.
    /// @param selector The selector of the function to be permitted for execution.
    /// @param deadline The deadline for the signature.
    /// @param state IPAccount's internal nonce
    /// @param signerPk The private key of the signer.
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
        uint256 signerPk
    ) internal view returns (bytes memory signature, bytes32 expectedState, bytes memory data) {
        expectedState = keccak256(
            abi.encode(
                state, // ipAccount.state()
                abi.encodeWithSelector(
                    IIPAccount.execute.selector,
                    address(accessController),
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
                    to: address(accessController),
                    value: 0,
                    data: data,
                    nonce: expectedState,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /// @dev Assert metadata for the SPGNFT.
    function assertSPGNFTMetadata(uint256 tokenId, string memory expectedMetadata) internal {
        assertEq(nftContract.tokenURI(tokenId), expectedMetadata);
    }

    /// @dev Assert metadata for the IP.
    function assertMetadata(address ipId, ISPG.IPMetadata memory expectedMetadata) internal {
        assertEq(coreMetadataViewModule.getMetadataURI(ipId), expectedMetadata.ipMetadataURI);
        assertEq(coreMetadataViewModule.getMetadataHash(ipId), expectedMetadata.ipMetadataHash);
        assertEq(coreMetadataViewModule.getNftMetadataHash(ipId), expectedMetadata.nftMetadataHash);
    }

    /// @dev get the salt for the contract deployment with CREATE3
    function _getSalt(string memory name) private view returns (bytes32 salt) {
        salt = keccak256(abi.encode(name, create3SaltSeed));
    }

    /// @dev Get the deterministic deployed address of a contract with CREATE3
    function _getDeployedAddress(string memory name) private view returns (address) {
        return create3Deployer.getDeployed(_getSalt(name));
    }

    /// @dev Load the implementation address from the proxy contract
    function _loadProxyImpl(address proxy) private view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
    }
}
