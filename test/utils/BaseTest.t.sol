// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { Test } from "forge-std/Test.sol";
import { Create3Deployer, ICreate3Deployer } from "@create3-deployer/contracts/Create3Deployer.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
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
import { CoreMetadataModule } from "@storyprotocol/core/modules/metadata/CoreMetadataModule.sol";
import { CoreMetadataViewModule } from "@storyprotocol/core/modules/metadata/CoreMetadataViewModule.sol";

import { StoryProtocolGateway } from "../../contracts/StoryProtocolGateway.sol";
import { SPGNFT } from "../../contracts/SPGNFT.sol";
import { TestProxyHelper } from "./TestProxyHelper.t.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

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
    CoreMetadataModule internal coreMetadataModule;
    CoreMetadataViewModule internal coreMetadataViewModule;
    PILicenseTemplate internal pilTemplate;
    LicenseToken internal licenseToken;

    StoryProtocolGateway internal spg;
    SPGNFT internal spgNftImpl;
    UpgradeableBeacon internal spgNftBeacon;

    MockERC20 internal mockToken;

    uint256 internal deployerPk = 0xddd111;
    uint256 internal alicePk = 0xa11ce;
    uint256 internal bobPk = 0xb0b;
    uint256 internal calPk = 0xca1;

    address payable internal deployer = payable(vm.addr(deployerPk));
    address payable internal alice = payable(vm.addr(alicePk));
    address payable internal bob = payable(vm.addr(bobPk));
    address payable internal cal = payable(vm.addr(calPk));

    function setUp() public virtual {
        create3Deployer = new Create3Deployer();
        create3SaltSeed = 1;

        vm.startPrank(deployer);
        setUp_test_Core();
        setUp_test_Periphery();
        setUp_test_Misc();
        vm.stopPrank();
    }

    function setUp_test_Core() public {
        address impl;

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

        impl = address(new IPAssetRegistry(address(erc6551Registry), _getDeployedAddress(type(IPAccountImpl).name)));
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

        impl = address(
            new LicenseRegistry(
                _getDeployedAddress(type(LicensingModule).name),
                _getDeployedAddress(type(DisputeModule).name)
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

        impl = address(
            new RoyaltyModule(
                _getDeployedAddress(type(LicensingModule).name),
                address(disputeModule),
                address(licenseRegistry)
            )
        );
        RoyaltyModule royaltyModule = RoyaltyModule(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RoyaltyModule).name),
                impl,
                abi.encodeCall(RoyaltyModule.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(RoyaltyModule).name) == address(royaltyModule),
            "Deploy: Royalty Module Address Mismatch"
        );
        require(_loadProxyImpl(address(royaltyModule)) == impl, "RoyaltyModule Proxy Implementation Mismatch");

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

        moduleRegistry.registerModule("DISPUTE_MODULE", address(disputeModule));
        moduleRegistry.registerModule("LICENSING_MODULE", address(licensingModule));
        moduleRegistry.registerModule("ROYALTY_MODULE", address(royaltyModule));
        moduleRegistry.registerModule("CORE_METADATA_MODULE", address(coreMetadataModule));
        moduleRegistry.registerModule("CORE_METADATA_VIEW_MODULE", address(coreMetadataViewModule));

        coreMetadataViewModule.updateCoreMetadataModule();
        licenseRegistry.registerLicenseTemplate(address(pilTemplate));
    }

    function setUp_test_Periphery() public {
        address impl = address(
            new StoryProtocolGateway(
                address(accessController),
                address(ipAssetRegistry),
                address(licensingModule),
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

        spgNftImpl = SPGNFT(
            create3Deployer.deploy(
                _getSalt(type(SPGNFT).name),
                abi.encodePacked(type(SPGNFT).creationCode, abi.encode(address(spg)))
            )
        );

        spgNftBeacon = UpgradeableBeacon(
            create3Deployer.deploy(
                _getSalt(type(UpgradeableBeacon).name),
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(address(spgNftImpl), deployer))
            )
        );

        spg.setNftContractBeacon(address(spgNftBeacon));

        // bytes4[] memory selectors = new bytes4[](1);
        // selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;
        // protocolAccessManager.setTargetFunctionRole(address(spg), selectors, ProtocolAdmin.UPGRADER_ROLE);
        // protocolAccessManager.setTargetFunctionRole(address(spgNftBeacon), selectors, ProtocolAdmin.UPGRADER_ROLE);
    }

    function setUp_test_Misc() public {
        mockToken = new MockERC20();

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(cal, "Cal");

        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.deal(cal, 1000 ether);
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
