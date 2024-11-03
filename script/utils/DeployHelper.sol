/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { ICreate3Deployer } from "@create3-deployer/contracts/ICreate3Deployer.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { AccessController } from "@storyprotocol/core/access/AccessController.sol";
import { CoreMetadataModule } from "@storyprotocol/core/modules/metadata/CoreMetadataModule.sol";
import { CoreMetadataViewModule } from "@storyprotocol/core/modules/metadata/CoreMetadataViewModule.sol";
import { DisputeModule } from "@storyprotocol/core/modules/dispute/DisputeModule.sol";
import { GroupingModule } from "@storyprotocol/core/modules/grouping/GroupingModule.sol";
import { EvenSplitGroupPool } from "@storyprotocol/core/modules/grouping/EvenSplitGroupPool.sol";
import { GroupNFT } from "@storyprotocol/core/GroupNFT.sol";
import { IPAccountImpl } from "@storyprotocol/core/IPAccountImpl.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { IPGraphACL } from "@storyprotocol/core/access/IPGraphACL.sol";
import { IpRoyaltyVault } from "@storyprotocol/core/modules/royalty/policies/IpRoyaltyVault.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";
import { LicenseToken } from "@storyprotocol/core/LicenseToken.sol";
import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import { ModuleRegistry } from "@storyprotocol/core/registries/ModuleRegistry.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import { RoyaltyModule } from "@storyprotocol/core/modules/royalty/RoyaltyModule.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { RoyaltyPolicyLRP } from "@storyprotocol/core/modules/royalty/policies/LRP/RoyaltyPolicyLRP.sol";
import { StorageLayoutChecker } from "@storyprotocol/script/utils/upgrades/StorageLayoutCheck.s.sol";

// contracts
import { SPGNFT } from "../../contracts/SPGNFT.sol";
import { DerivativeWorkflows } from "../../contracts/workflows/DerivativeWorkflows.sol";
import { GroupingWorkflows } from "../../contracts/workflows/GroupingWorkflows.sol";
import { LicenseAttachmentWorkflows } from "../../contracts/workflows/LicenseAttachmentWorkflows.sol";
import { OrgNFT } from "../../contracts/story-nft/OrgNFT.sol";
import { RegistrationWorkflows } from "../../contracts/workflows/RegistrationWorkflows.sol";
import { RoyaltyWorkflows } from "../../contracts/workflows/RoyaltyWorkflows.sol";
import { StoryBadgeNFT } from "../../contracts/story-nft/StoryBadgeNFT.sol";
import { OrgStoryNFTFactory } from "../../contracts/story-nft/OrgStoryNFTFactory.sol";

// script
import { BroadcastManager } from "./BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "./JsonDeploymentHandler.s.sol";
import { StoryProtocolCoreAddressManager } from "./StoryProtocolCoreAddressManager.sol";
import { StoryProtocolPeripheryAddressManager } from "./StoryProtocolPeripheryAddressManager.sol";
import { StringUtil } from "./StringUtil.sol";

// test
import { TestProxyHelper } from "../../test/utils/TestProxyHelper.t.sol";

contract DeployHelper is
    Script,
    BroadcastManager,
    StorageLayoutChecker,
    JsonDeploymentHandler,
    StoryProtocolCoreAddressManager,
    StoryProtocolPeripheryAddressManager
{
    using StringUtil for uint256;
    using stdJson for string;

    // PROXY 1967 IMPLEMENTATION STORAGE SLOTS
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    error DeploymentConfigError(string message);

    ICreate3Deployer internal immutable create3Deployer;

    // seed for CREATE3 salt
    uint256 internal create3SaltSeed;

    // SPGNFT
    SPGNFT internal spgNftImpl;
    UpgradeableBeacon internal spgNftBeacon;

    // Periphery Workflows
    DerivativeWorkflows internal derivativeWorkflows;
    GroupingWorkflows internal groupingWorkflows;
    LicenseAttachmentWorkflows internal licenseAttachmentWorkflows;
    RegistrationWorkflows internal registrationWorkflows;
    RoyaltyWorkflows internal royaltyWorkflows;

    // StoryNFT
    OrgStoryNFTFactory internal orgStoryNftFactory;
    OrgNFT internal orgNft;
    address internal defaultOrgStoryNftTemplate;
    address internal defaultOrgStoryNftBeacon;

    // DeployHelper variable
    bool internal writeDeploys;

    // Mock Core Contracts
    AccessController internal accessController;
    AccessManager internal protocolAccessManager;
    CoreMetadataModule internal coreMetadataModule;
    CoreMetadataViewModule internal coreMetadataViewModule;
    DisputeModule internal disputeModule;
    GroupingModule internal groupingModule;
    GroupNFT internal groupNFT;
    IPAssetRegistry internal ipAssetRegistry;
    IPGraphACL internal ipGraphACL;
    IpRoyaltyVault internal ipRoyaltyVaultImpl;
    LicenseRegistry internal licenseRegistry;
    LicenseToken internal licenseToken;
    LicensingModule internal licensingModule;
    ModuleRegistry internal moduleRegistry;
    PILicenseTemplate internal pilTemplate;
    RoyaltyModule internal royaltyModule;
    RoyaltyPolicyLAP internal royaltyPolicyLAP;
    RoyaltyPolicyLRP internal royaltyPolicyLRP;
    UpgradeableBeacon internal ipRoyaltyVaultBeacon;
    EvenSplitGroupPool internal evenSplitGroupPool;

    // mock core contract deployer
    address internal mockDeployer;

    constructor(
        address create3Deployer_
    ) JsonDeploymentHandler("main") {
        create3Deployer = ICreate3Deployer(create3Deployer_);
    }

    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/deployment/Main.s.sol:Main --rpc-url=$TESTNET_URL \
    /// -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run(
        uint256 create3SaltSeed_,
        bool runStorageLayoutCheck,
        bool writeDeploys_,
        bool isTest
    ) public virtual {
        create3SaltSeed = create3SaltSeed_;
        writeDeploys = writeDeploys_;

        // This will run OZ storage layout check for all contracts. Requires --ffi flag.
        if (runStorageLayoutCheck) _validate(); // StorageLayoutChecker.s.sol

        if (isTest) {
            // local test deployment
            deployer = mockDeployer;
            _deployMockCoreContracts();
            _configureMockCoreContracts();
            _deployWorkflowContracts();
            _configureWorkflowContracts();
        } else {
            // production deployment
            _readStoryProtocolCoreAddresses(); // StoryProtocolCoreAddressManager.s.sol
            _beginBroadcast(); // BroadcastManager.s.sol
            _deployWorkflowContracts();
            _configureWorkflowContracts();

            // Check deployment configuration.
            if (spgNftBeacon.owner() != address(registrationWorkflows))
                revert DeploymentConfigError("RegistrationWorkflows is not the owner of SPGNFTBeacon");

            if (writeDeploys) _writeDeployment(); // JsonDeploymentHandler.s.sol
            _endBroadcast(); // BroadcastManager.s.sol

            // Set SPGNFTBeacon for periphery workflow contracts, access controlled
            // can't be done in deployment script:
            // derivativeWorkflows.setNftContractBeacon(address(spgNftBeacon));
            // groupingWorkflows.setNftContractBeacon(address(spgNftBeacon));
            // licenseAttachmentWorkflows.setNftContractBeacon(address(spgNftBeacon));
            // registrationWorkflows.setNftContractBeacon(address(spgNftBeacon));
        }
    }

    function _deployAndConfigStoryNftContracts(
        address licenseTemplate_,
        uint256 licenseTermsId_,
        address orgStoryNftFactorySigner,
        bool isTest
    ) internal {
        if (!isTest) {
            _readStoryProtocolCoreAddresses(); // StoryProtocolCoreAddressManager.s.sol
            _readStoryProtocolPeripheryAddresses(); // StoryProtocolPeripheryAddressManager.s.sol
            _beginBroadcast(); // BroadcastManager.s.sol

            if (writeDeploys) {
                _writeAddress("DerivativeWorkflows", address(derivativeWorkflowsAddr));
                _writeAddress("GroupingWorkflows", address(groupingWorkflowsAddr));
                _writeAddress("LicenseAttachmentWorkflows", address(licenseAttachmentWorkflowsAddr));
                _writeAddress("RegistrationWorkflows", address(registrationWorkflowsAddr));
                _writeAddress("RoyaltyWorkflows", address(royaltyWorkflowsAddr));
                _writeAddress("SPGNFTBeacon", address(spgNftBeaconAddr));
                _writeAddress("SPGNFTImpl", address(spgNftImplAddr));
            }
        }
        address impl = address(0);

        // OrgNFT
        _predeploy("OrgNFT");
        impl = address(
            new OrgNFT(
                ipAssetRegistryAddr,
                licensingModuleAddr,
                _getDeployedAddress(type(OrgStoryNFTFactory).name),
                licenseTemplate_,
                licenseTermsId_
            )
        );
        orgNft = OrgNFT(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(OrgNFT).name),
                impl,
                abi.encodeCall(OrgNFT.initialize, protocolAccessManagerAddr)
            )
        );
        impl = address(0);
        _postdeploy("OrgNFT", address(orgNft));

        // Default StoryNFT template
        _predeploy("DefaultOrgStoryNFTTemplate");
        defaultOrgStoryNftTemplate = address(new StoryBadgeNFT(
            ipAssetRegistryAddr,
            licensingModuleAddr,
            _getDeployedAddress("DefaultOrgStoryNFTBeacon"),
            address(orgNft),
            pilTemplateAddr,
            licenseTermsId_
        ));
        _postdeploy("DefaultOrgStoryNFTTemplate", defaultOrgStoryNftTemplate);

        // Upgradeable Beacon for DefaultOrgStoryNFTTemplate
        _predeploy("DefaultOrgStoryNFTBeacon");
        defaultOrgStoryNftBeacon = address(UpgradeableBeacon(
            create3Deployer.deploy(
                _getSalt("DefaultOrgStoryNFTBeacon"),
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(defaultOrgStoryNftTemplate, deployer))
            )
        ));
        _postdeploy("DefaultOrgStoryNFTBeacon", address(defaultOrgStoryNftBeacon));

        require(
            UpgradeableBeacon(defaultOrgStoryNftBeacon).implementation() == address(defaultOrgStoryNftTemplate),
            "DeployHelper: Invalid beacon implementation"
        );
        require(
            StoryBadgeNFT(defaultOrgStoryNftTemplate).UPGRADEABLE_BEACON() == address(defaultOrgStoryNftBeacon),
            "DeployHelper: Invalid beacon address in template"
        );

        // OrgStoryNFTFactory
        _predeploy("OrgStoryNFTFactory");
        impl = address(
            new OrgStoryNFTFactory(
                ipAssetRegistryAddr,
                licensingModuleAddr,
                licenseTemplate_,
                licenseTermsId_,
                address(orgNft)
            )
        );
        orgStoryNftFactory = OrgStoryNFTFactory(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(OrgStoryNFTFactory).name),
                impl,
                abi.encodeCall(
                    OrgStoryNFTFactory.initialize,
                    (
                        protocolAccessManagerAddr,
                        defaultOrgStoryNftTemplate,
                        orgStoryNftFactorySigner
                    )
                )
            )
        );
        impl = address(0);
        _postdeploy("OrgStoryNFTFactory", address(orgStoryNftFactory));

        orgStoryNftFactory.setDefaultOrgStoryNftTemplate(defaultOrgStoryNftTemplate);

        if (!isTest) {
            if (writeDeploys) _writeDeployment();
            _endBroadcast();
        }
    }

    function _deployWorkflowContracts() private {
        address impl = address(0);

        // Periphery workflow contracts
        _predeploy("DerivativeWorkflows");
        impl = address(
            new DerivativeWorkflows(
                accessControllerAddr,
                coreMetadataModuleAddr,
                ipAssetRegistryAddr,
                licenseRegistryAddr,
                licenseTokenAddr,
                licensingModuleAddr,
                pilTemplateAddr,
                royaltyModuleAddr
            )
        );
        derivativeWorkflows = DerivativeWorkflows(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(DerivativeWorkflows).name),
                impl,
                abi.encodeCall(DerivativeWorkflows.initialize, address(protocolAccessManagerAddr))
            )
        );
        impl = address(0);
        _postdeploy("DerivativeWorkflows", address(derivativeWorkflows));

        _predeploy("GroupingWorkflows");
        impl = address(
            new GroupingWorkflows(
                accessControllerAddr,
                coreMetadataModuleAddr,
                groupingModuleAddr,
                groupNFTAddr,
                ipAssetRegistryAddr,
                licenseRegistryAddr,
                licensingModuleAddr,
                pilTemplateAddr,
                royaltyModuleAddr
            )
        );
        groupingWorkflows = GroupingWorkflows(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(GroupingWorkflows).name),
                impl,
                abi.encodeCall(GroupingWorkflows.initialize, address(protocolAccessManagerAddr))
            )
        );
        impl = address(0);
        _postdeploy("GroupingWorkflows", address(groupingWorkflows));

        _predeploy("LicenseAttachmentWorkflows");
        impl = address(
            new LicenseAttachmentWorkflows(
                accessControllerAddr,
                coreMetadataModuleAddr,
                ipAssetRegistryAddr,
                licenseRegistryAddr,
                licensingModuleAddr,
                pilTemplateAddr
            )
        );
        licenseAttachmentWorkflows = LicenseAttachmentWorkflows(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(LicenseAttachmentWorkflows).name),
                impl,
                abi.encodeCall(LicenseAttachmentWorkflows.initialize, address(protocolAccessManagerAddr))
            )
        );
        impl = address(0);
        _postdeploy("LicenseAttachmentWorkflows", address(licenseAttachmentWorkflows));

        _predeploy("RegistrationWorkflows");
        impl = address(
            new RegistrationWorkflows(
                accessControllerAddr,
                coreMetadataModuleAddr,
                ipAssetRegistryAddr,
                licenseRegistryAddr,
                licensingModuleAddr,
                pilTemplateAddr
            )
        );
        registrationWorkflows = RegistrationWorkflows(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RegistrationWorkflows).name),
                impl,
                abi.encodeCall(RegistrationWorkflows.initialize, address(protocolAccessManagerAddr))
            )
        );
        impl = address(0);
        _postdeploy("RegistrationWorkflows", address(registrationWorkflows));

        _predeploy("RoyaltyWorkflows");
        impl = address(new RoyaltyWorkflows(royaltyModuleAddr));
        royaltyWorkflows = RoyaltyWorkflows(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RoyaltyWorkflows).name),
                impl,
                abi.encodeCall(RoyaltyWorkflows.initialize, address(protocolAccessManagerAddr))
            )
        );
        impl = address(0);
        _postdeploy("RoyaltyWorkflows", address(royaltyWorkflows));

        // SPGNFT contracts
        _predeploy("SPGNFTImpl");
        spgNftImpl = SPGNFT(
            create3Deployer.deploy(
                _getSalt(type(SPGNFT).name),
                abi.encodePacked(type(SPGNFT).creationCode,
                    abi.encode(
                        address(derivativeWorkflows),
                        address(groupingWorkflows),
                        address(licenseAttachmentWorkflows),
                        address(registrationWorkflows)
                    )
                )
            )
        );
        _postdeploy("SPGNFTImpl", address(spgNftImpl));

        _predeploy("SPGNFTBeacon");
        spgNftBeacon = UpgradeableBeacon(
            create3Deployer.deploy(
                _getSalt(type(UpgradeableBeacon).name),
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(address(spgNftImpl), deployer))
            )
        );
        _postdeploy("SPGNFTBeacon", address(spgNftBeacon));
    }

    function _configureWorkflowContracts() private {
       // Transfer ownership of beacon proxy to RegistrationWorkflows
       spgNftBeacon.transferOwnership(address(registrationWorkflows));

       // more configurations may be added here
    }

    function _deployMockCoreContracts() private {
        ERC6551Registry erc6551Registry = new ERC6551Registry();
        address impl = address(0);

        // protocolAccessManager
        protocolAccessManager = AccessManager(
            create3Deployer.deploy(
                _getSalt(type(AccessManager).name),
                abi.encodePacked(type(AccessManager).creationCode, abi.encode(deployer))
            )
        );
        protocolAccessManagerAddr = address(protocolAccessManager);
        require(
            _getDeployedAddress(type(AccessManager).name) == address(protocolAccessManager),
            "Deploy: Protocol Access Manager Address Mismatch"
        );

        // mock IPGraph
        ipGraphACL = new IPGraphACL(address(protocolAccessManager));

        // moduleRegistry
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

        // ipAssetRegistry
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
        ipAssetRegistryAddr = address(ipAssetRegistry);
        require(
            _getDeployedAddress(type(IPAssetRegistry).name) == address(ipAssetRegistry),
            "Deploy: IP Asset Registry Address Mismatch"
        );
        require(_loadProxyImpl(address(ipAssetRegistry)) == impl, "IPAssetRegistry Proxy Implementation Mismatch");
        address ipAccountRegistry = address(ipAssetRegistry);

        // accessController
        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(new AccessController(address(ipAssetRegistry), address(moduleRegistry)));
        accessController = AccessController(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(AccessController).name),
                impl,
                abi.encodeCall(AccessController.initialize, address(protocolAccessManager))
            )
        );
        accessControllerAddr = address(accessController);
        require(
            _getDeployedAddress(type(AccessController).name) == address(accessController),
            "Deploy: Access Controller Address Mismatch"
        );
        require(_loadProxyImpl(address(accessController)) == impl, "AccessController Proxy Implementation Mismatch");

        // licenseRegistry
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
        licenseRegistryAddr = address(licenseRegistry);
        require(
            _getDeployedAddress(type(LicenseRegistry).name) == address(licenseRegistry),
            "Deploy: License Registry Address Mismatch"
        );
        require(_loadProxyImpl(address(licenseRegistry)) == impl, "LicenseRegistry Proxy Implementation Mismatch");

        // ipAccountImpl
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

        // disputeModule
        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(
            new DisputeModule(address(accessController), address(ipAssetRegistry), address(licenseRegistry))
        );
        disputeModule = DisputeModule(
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


        // royaltyModule
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
        royaltyModuleAddr = address(royaltyModule);
        require(
            _getDeployedAddress(type(RoyaltyModule).name) == address(royaltyModule),
            "Deploy: Royalty Module Address Mismatch"
        );
        require(_loadProxyImpl(address(royaltyModule)) == impl, "RoyaltyModule Proxy Implementation Mismatch");

        // licensingModule
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
        licensingModuleAddr = address(licensingModule);
        require(
            _getDeployedAddress(type(LicensingModule).name) == address(licensingModule),
            "Deploy: Licensing Module Address Mismatch"
        );
        require(_loadProxyImpl(address(licensingModule)) == impl, "LicensingModule Proxy Implementation Mismatch");

        // royaltyPolicyLAP
        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(new RoyaltyPolicyLAP(address(royaltyModule), address(ipGraphACL)));
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

        // royaltyPolicyLRP
        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(new RoyaltyPolicyLRP(address(royaltyModule), address(ipGraphACL)));
        royaltyPolicyLRP = RoyaltyPolicyLRP(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RoyaltyPolicyLRP).name),
                impl,
                abi.encodeCall(RoyaltyPolicyLRP.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(RoyaltyPolicyLRP).name) == address(royaltyPolicyLRP),
            "Deploy: Royalty Policy LRP Address Mismatch"
        );
        require(_loadProxyImpl(address(royaltyPolicyLRP)) == impl, "RoyaltyPolicyLRP Proxy Implementation Mismatch");

        // ipRoyaltyVaultImpl
        ipRoyaltyVaultImpl = IpRoyaltyVault(
            create3Deployer.deploy(
                _getSalt(type(IpRoyaltyVault).name),
                abi.encodePacked(
                    type(IpRoyaltyVault).creationCode,
                    abi.encode(address(disputeModule), address(royaltyModule), address(ipAssetRegistry), _getDeployedAddress(type(GroupingModule).name))
                )
            )
        );

        // ipRoyaltyVaultBeacon
        ipRoyaltyVaultBeacon = UpgradeableBeacon(
            create3Deployer.deploy(
                _getSalt("ipRoyaltyVaultBeacon"),
                abi.encodePacked(
                    type(UpgradeableBeacon).creationCode,
                    abi.encode(address(ipRoyaltyVaultImpl), deployer)
                )
            )
        );

        // licenseToken
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
        licenseTokenAddr = address(licenseToken);
        require(
            _getDeployedAddress(type(LicenseToken).name) == address(licenseToken),
            "Deploy: License Token Address Mismatch"
        );
        require(_loadProxyImpl(address(licenseToken)) == impl, "LicenseToken Proxy Implementation Mismatch");

        // pilTemplate
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
        pilTemplateAddr = address(pilTemplate);
        require(
            _getDeployedAddress(type(PILicenseTemplate).name) == address(pilTemplate),
            "Deploy: PI License Template Address Mismatch"
        );
        require(_loadProxyImpl(address(pilTemplate)) == impl, "PILicenseTemplate Proxy Implementation Mismatch");

        // coreMetadataModule
        coreMetadataModule = CoreMetadataModule(
            create3Deployer.deploy(
                _getSalt(type(CoreMetadataModule).name),
                abi.encodePacked(
                    type(CoreMetadataModule).creationCode,
                    abi.encode(address(accessController), address(ipAssetRegistry))
                )
            )
        );
        coreMetadataModuleAddr = address(coreMetadataModule);

        // coreMetadataViewModule
        coreMetadataViewModule = CoreMetadataViewModule(
            create3Deployer.deploy(
                _getSalt(type(CoreMetadataViewModule).name),
                abi.encodePacked(
                    type(CoreMetadataViewModule).creationCode,
                    abi.encode(address(ipAssetRegistry), address(moduleRegistry))
                )
            )
        );

        // groupNFT
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
        groupNFTAddr = address(groupNFT);
        require(_getDeployedAddress(type(GroupNFT).name) == address(groupNFT), "Deploy: Group NFT Address Mismatch");
        require(_loadProxyImpl(address(groupNFT)) == impl, "GroupNFT Proxy Implementation Mismatch");

        // groupingModule
        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(
            new GroupingModule(
                address(accessController),
                address(ipAssetRegistry),
                address(licenseRegistry),
                address(licenseToken),
                address(groupNFT),
                address(royaltyModule)
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
        groupingModuleAddr = address(groupingModule);
        require(
            _getDeployedAddress(type(GroupingModule).name) == address(groupingModule),
            "Deploy: Grouping Module Address Mismatch"
        );
        require(_loadProxyImpl(address(groupingModule)) == impl, "GroupingModule Proxy Implementation Mismatch");

         _predeploy("EvenSplitGroupPool");
        impl = address(new EvenSplitGroupPool(
            address(groupingModule),
            address(royaltyModule),
            address(ipAssetRegistry)
        ));
        evenSplitGroupPool = EvenSplitGroupPool(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(EvenSplitGroupPool).name),
                impl,
                abi.encodeCall(EvenSplitGroupPool.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(EvenSplitGroupPool).name) == address(evenSplitGroupPool),
            "Deploy: EvenSplitGroupPool Address Mismatch"
        );
        require(_loadProxyImpl(address(evenSplitGroupPool)) == impl, "EvenSplitGroupPool Proxy Implementation Mismatch");
        impl = address(0);
        _postdeploy("EvenSplitGroupPool", address(evenSplitGroupPool));
    }

    function _configureMockCoreContracts() private {
        moduleRegistry.registerModule("DISPUTE_MODULE", address(disputeModule));
        moduleRegistry.registerModule("LICENSING_MODULE", address(licensingModule));
        moduleRegistry.registerModule("ROYALTY_MODULE", address(royaltyModule));
        moduleRegistry.registerModule("CORE_METADATA_MODULE", address(coreMetadataModule));
        moduleRegistry.registerModule("CORE_METADATA_VIEW_MODULE", address(coreMetadataViewModule));
        moduleRegistry.registerModule("GROUPING_MODULE", address(groupingModule));

        ipGraphACL.whitelistAddress(_getDeployedAddress(type(RoyaltyPolicyLAP).name));
        ipGraphACL.whitelistAddress(_getDeployedAddress(type(RoyaltyPolicyLRP).name));
        ipGraphACL.whitelistAddress(_getDeployedAddress(type(LicenseRegistry).name));

        coreMetadataViewModule.updateCoreMetadataModule();

        // set up default license terms
        pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        licenseRegistry.registerLicenseTemplate(address(pilTemplate));
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), PILFlavors.getNonCommercialSocialRemixingId(pilTemplate));

        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLRP), true);
        royaltyModule.setIpRoyaltyVaultBeacon(address(ipRoyaltyVaultBeacon));
        ipRoyaltyVaultBeacon.transferOwnership(address(royaltyPolicyLAP));

        // add evenSplitGroupPool to whitelist of group pools
        groupingModule.whitelistGroupRewardPool(address(evenSplitGroupPool), true);
    }

    /// @dev get the salt for the contract deployment with CREATE3
    function _getSalt(string memory name) internal view returns (bytes32 salt) {
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

    function _predeploy(string memory contractKey) private view {
        if (writeDeploys) console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        if (writeDeploys) {
            _writeAddress(contractKey, newAddress);
            console2.log(string.concat(contractKey, " deployed to:"), newAddress);
        }
    }
}
