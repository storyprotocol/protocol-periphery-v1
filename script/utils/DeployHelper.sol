/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { BroadcastManager } from "@storyprotocol/script/utils/BroadcastManager.s.sol";
import { ICreate3Deployer } from "@storyprotocol/script/utils/ICreate3Deployer.sol";
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
import { IModuleRegistry } from "@storyprotocol/core/interfaces/registries/IModuleRegistry.sol";
import { ModuleRegistry } from "@storyprotocol/core/registries/ModuleRegistry.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import { RoyaltyModule } from "@storyprotocol/core/modules/royalty/RoyaltyModule.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { RoyaltyPolicyLRP } from "@storyprotocol/core/modules/royalty/policies/LRP/RoyaltyPolicyLRP.sol";
import { StorageLayoutChecker } from "@storyprotocol/script/utils/upgrades/StorageLayoutCheck.s.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { TestProxyHelper } from "@storyprotocol/test/utils/TestProxyHelper.sol";
import { ProtocolAdmin } from "@storyprotocol/core/lib/ProtocolAdmin.sol";
import { JsonDeploymentHandler } from "@storyprotocol/script/utils/JsonDeploymentHandler.s.sol";
import { ProtocolPausableUpgradeable } from "@storyprotocol/core/pause/ProtocolPausableUpgradeable.sol";

// contracts
import { SPGNFT } from "../../contracts/SPGNFT.sol";
import { DerivativeWorkflows } from "../../contracts/workflows/DerivativeWorkflows.sol";
import { GroupingWorkflows } from "../../contracts/workflows/GroupingWorkflows.sol";
import { LicenseAttachmentWorkflows } from "../../contracts/workflows/LicenseAttachmentWorkflows.sol";
import { OrgNFT } from "../../contracts/story-nft/OrgNFT.sol";
import { RegistrationWorkflows } from "../../contracts/workflows/RegistrationWorkflows.sol";
import { IRegistrationWorkflows } from "../../contracts/interfaces/workflows/IRegistrationWorkflows.sol";
import { RoyaltyWorkflows } from "../../contracts/workflows/RoyaltyWorkflows.sol";
import { RoyaltyTokenDistributionWorkflows } from "../../contracts/workflows/RoyaltyTokenDistributionWorkflows.sol";
import { StoryBadgeNFT } from "../../contracts/story-nft/StoryBadgeNFT.sol";
import { OrgStoryNFTFactory } from "../../contracts/story-nft/OrgStoryNFTFactory.sol";
import { OwnableERC20 } from "../../contracts/modules/tokenizer/OwnableERC20.sol";
import { ITokenizerModule } from "../../contracts/interfaces/modules/tokenizer/ITokenizerModule.sol";
import { TokenizerModule } from "../../contracts/modules/tokenizer/TokenizerModule.sol";
import { LockLicenseHook } from "../../contracts/hooks/LockLicenseHook.sol";
import { TotalLicenseTokenLimitHook } from "../../contracts/hooks/TotalLicenseTokenLimitHook.sol";

// script
import { StoryProtocolCoreAddressManager } from "./StoryProtocolCoreAddressManager.sol";
import { StoryProtocolPeripheryAddressManager } from "./StoryProtocolPeripheryAddressManager.sol";
import { StringUtil } from "./StringUtil.sol";

// test
import { MockERC20 } from "../../test/mocks/MockERC20.sol";

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

    // WIP address
    address internal wipAddr = 0x1514000000000000000000000000000000000000;

    // IPAccount contracts
    IPAccountImpl internal ipAccountImplCode;
    UpgradeableBeacon internal ipAccountImplBeacon;
    BeaconProxy internal ipAccountImpl;
    string internal constant IP_ACCOUNT_IMPL_CODE = "IPAccountImplCode";
    string internal constant IP_ACCOUNT_IMPL_BEACON = "IPAccountImplBeacon";
    string internal constant IP_ACCOUNT_IMPL_BEACON_PROXY = "IPAccountImplBeaconProxy";

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
    RoyaltyTokenDistributionWorkflows internal royaltyTokenDistributionWorkflows;

    // StoryNFT
    OrgStoryNFTFactory internal orgStoryNftFactory;
    OrgNFT internal orgNft;
    address internal defaultOrgStoryNftTemplate;
    address internal defaultOrgStoryNftBeacon;

    // Tokenizer Module
    TokenizerModule internal tokenizerModule;
    address internal ownableERC20Template;
    UpgradeableBeacon internal ownableERC20Beacon;

    // LicensingHooks
    LockLicenseHook internal lockLicenseHook;
    TotalLicenseTokenLimitHook internal totalLicenseTokenLimitHook;

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
    MockERC20 internal wip;

    // mock core contract deployer
    address internal mockDeployer;

    string private version;

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
        bool isTest,
        string memory version_
    ) public virtual {
        create3SaltSeed = create3SaltSeed_;
        writeDeploys = writeDeploys_;
        version = version_;

        // This will run OZ storage layout check for all contracts. Requires --ffi flag.
        if (runStorageLayoutCheck) _validate(); // StorageLayoutChecker.s.sol

        if (isTest) {
            // local test deployment
            deployer = mockDeployer;
            _deployMockCoreContracts();
            _configureMockCoreContracts();
            _deployPeripheryContracts();
            _configurePeripheryContracts();
        } else {
            // production deployment
            _readStoryProtocolCoreAddresses(); // StoryProtocolCoreAddressManager.s.sol
            _beginBroadcast(); // BroadcastManager.s.sol
            _deployPeripheryContracts();
            _configurePeripheryContracts();

            // Check deployment configuration.
            if (spgNftBeacon.owner() != address(registrationWorkflows))
                revert DeploymentConfigError("RegistrationWorkflows is not the owner of SPGNFTBeacon");


            if (ownableERC20Beacon.owner() != address(tokenizerModule))
                revert DeploymentConfigError("TokenizerModule is not the owner of OwnableERC20Beacon");

            if (writeDeploys) _writeDeployment(version); // JsonDeploymentHandler.s.sol
            _endBroadcast(); // BroadcastManager.s.sol
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
                coreMetadataModuleAddr,
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
            coreMetadataModuleAddr,
            _getDeployedAddress("DefaultOrgStoryNFTBeacon"),
            address(orgNft),
            pilTemplateAddr,
            licenseTermsId_
        ));
        _postdeploy("DefaultOrgStoryNFTTemplate", defaultOrgStoryNftTemplate);

        // Upgradeable Beacon for DefaultOrgStoryNFTTemplate
        _predeploy("DefaultOrgStoryNFTBeacon");
        defaultOrgStoryNftBeacon = address(UpgradeableBeacon(
            create3Deployer.deployDeterministic(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(defaultOrgStoryNftTemplate, deployer)),
                _getSalt("DefaultOrgStoryNFTBeacon")
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
            if (writeDeploys) _writeDeployment(version);
            _endBroadcast();
        }
    }

    function _deployPeripheryContracts() private {
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

        _predeploy("RoyaltyTokenDistributionWorkflows");
        impl = address(new RoyaltyTokenDistributionWorkflows(
            accessControllerAddr,
            coreMetadataModuleAddr,
            ipAssetRegistryAddr,
            licenseRegistryAddr,
            licensingModuleAddr,
            pilTemplateAddr,
            royaltyModuleAddr,
            royaltyPolicyLRPAddr,
            wipAddr
        ));
        royaltyTokenDistributionWorkflows = RoyaltyTokenDistributionWorkflows(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RoyaltyTokenDistributionWorkflows).name),
                impl,
                abi.encodeCall(RoyaltyTokenDistributionWorkflows.initialize, address(protocolAccessManagerAddr))
            )
        );
        impl = address(0);
        _postdeploy("RoyaltyTokenDistributionWorkflows", address(royaltyTokenDistributionWorkflows));

        // SPGNFT contracts
        _predeploy("SPGNFTImpl");
        spgNftImpl = SPGNFT(
            create3Deployer.deployDeterministic(
                abi.encodePacked(type(SPGNFT).creationCode,
                    abi.encode(
                        address(derivativeWorkflows),
                        address(groupingWorkflows),
                        address(licenseAttachmentWorkflows),
                        address(registrationWorkflows),
                        address(royaltyTokenDistributionWorkflows)
                    )
                ),
                _getSalt(type(SPGNFT).name)
            )
        );
        _postdeploy("SPGNFTImpl", address(spgNftImpl));

        _predeploy("SPGNFTBeacon");
        spgNftBeacon = UpgradeableBeacon(
            create3Deployer.deployDeterministic(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(address(spgNftImpl), deployer)),
                _getSalt(type(UpgradeableBeacon).name)
            )
        );
        _postdeploy("SPGNFTBeacon", address(spgNftBeacon));

        // Tokenizer Module
        _predeploy("TokenizerModule");
        impl = address(new TokenizerModule(accessControllerAddr, ipAssetRegistryAddr, licenseRegistryAddr, disputeModuleAddr));
        tokenizerModule = TokenizerModule(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(TokenizerModule).name),
                impl,
                abi.encodeCall(TokenizerModule.initialize, protocolAccessManagerAddr)
            )
        );
        impl = address(0);
        _postdeploy("TokenizerModule", address(tokenizerModule));

        // OwnableERC20 template
        _predeploy("OwnableERC20Template");
        ownableERC20Template = address(create3Deployer.deployDeterministic(
            abi.encodePacked(type(OwnableERC20).creationCode,
                abi.encode(
                    _getDeployedAddress("OwnableERC20Beacon")
                )
            ),
            _getSalt(string.concat(type(OwnableERC20).name))
        ));
        _postdeploy("OwnableERC20Template", ownableERC20Template);

        // Upgradeable Beacon for OwnableERC20Template
        _predeploy("OwnableERC20Beacon");
        ownableERC20Beacon = UpgradeableBeacon(
            create3Deployer.deployDeterministic(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(ownableERC20Template, deployer)),
                _getSalt("OwnableERC20Beacon")
            )
        );
        _postdeploy("OwnableERC20Beacon", address(ownableERC20Beacon));
        require(
            UpgradeableBeacon(ownableERC20Beacon).implementation() == address(ownableERC20Template),
            "DeployHelper: Invalid beacon implementation"
        );
        require(
            OwnableERC20(ownableERC20Template).upgradableBeacon() == address(ownableERC20Beacon),
            "DeployHelper: Invalid beacon address in template"
        );

        // LicensingHooks
        _predeploy("LockLicenseHook");
        lockLicenseHook = LockLicenseHook(
            create3Deployer.deployDeterministic(
                abi.encodePacked(
                    type(LockLicenseHook).creationCode
                ),
                _getSalt("LockLicenseHook")
            )
        );
        _postdeploy("LockLicenseHook", address(lockLicenseHook));

        _predeploy("TotalLicenseTokenLimitHook");
        totalLicenseTokenLimitHook = TotalLicenseTokenLimitHook(
            create3Deployer.deployDeterministic(
                abi.encodePacked(
                    type(TotalLicenseTokenLimitHook).creationCode,
                    abi.encode(
                        accessControllerAddr,
                        ipAssetRegistryAddr
                    )
                ),
                _getSalt("TotalLicenseTokenLimitHook")
            )
        );
        _postdeploy("TotalLicenseTokenLimitHook", address(totalLicenseTokenLimitHook));
    }

    function _configurePeripheryContracts() private {
       // Transfer ownership of beacon proxy to RegistrationWorkflows
       spgNftBeacon.transferOwnership(address(registrationWorkflows));
       ownableERC20Beacon.transferOwnership(address(tokenizerModule));
       registrationWorkflows.setNftContractBeacon(address(spgNftBeacon));
       tokenizerModule.whitelistTokenTemplate(address(ownableERC20Template), true);
       IModuleRegistry(moduleRegistryAddr).registerModule("TOKENIZER_MODULE", address(tokenizerModule));
       IModuleRegistry(moduleRegistryAddr).registerModule("LOCK_LICENSE_HOOK", address(lockLicenseHook));
       IModuleRegistry(moduleRegistryAddr).registerModule("TOTAL_LICENSE_TOKEN_LIMIT_HOOK", address(totalLicenseTokenLimitHook));
       // add upgrade role and pause role to tokenizer module
       bytes4[] memory selectors = new bytes4[](1);
       selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;
        AccessManager(protocolAccessManagerAddr).setTargetFunctionRole(
            address(derivativeWorkflows),
            selectors,
            ProtocolAdmin.UPGRADER_ROLE
        );
        AccessManager(protocolAccessManagerAddr).setTargetFunctionRole(
            address(groupingWorkflows),
            selectors,
            ProtocolAdmin.UPGRADER_ROLE
        );
        AccessManager(protocolAccessManagerAddr).setTargetFunctionRole(
            address(licenseAttachmentWorkflows),
            selectors,
            ProtocolAdmin.UPGRADER_ROLE
        );
        AccessManager(protocolAccessManagerAddr).setTargetFunctionRole(
            address(royaltyTokenDistributionWorkflows),
            selectors,
            ProtocolAdmin.UPGRADER_ROLE
        );
        AccessManager(protocolAccessManagerAddr).setTargetFunctionRole(
            address(royaltyWorkflows),
            selectors,
            ProtocolAdmin.UPGRADER_ROLE
        );

        selectors = new bytes4[](2);
        selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;
        selectors[1] = ITokenizerModule.upgradeWhitelistedTokenTemplate.selector;
        AccessManager(protocolAccessManagerAddr).setTargetFunctionRole(
            address(tokenizerModule),
            selectors,
            ProtocolAdmin.UPGRADER_ROLE
        );

        selectors = new bytes4[](2);
        selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;
        selectors[1] = IRegistrationWorkflows.upgradeCollections.selector;
        AccessManager(protocolAccessManagerAddr).setTargetFunctionRole(
            address(registrationWorkflows),
            selectors,
            ProtocolAdmin.UPGRADER_ROLE
        );

        // Module Registry
        // Upgrading Licensing Hooks requires both removeModule and registerModule
        selectors = new bytes4[](2);
        selectors[0] = ModuleRegistry.removeModule.selector;
        selectors[1] = bytes4(keccak256("registerModule(string,address)"));
        AccessManager(protocolAccessManagerAddr).setTargetFunctionRole(moduleRegistryAddr, selectors, ProtocolAdmin.UPGRADER_ROLE);

        selectors = new bytes4[](2);
        selectors[0] = ProtocolPausableUpgradeable.pause.selector;
        selectors[1] = ProtocolPausableUpgradeable.unpause.selector;
        AccessManager(protocolAccessManagerAddr).setTargetFunctionRole(
            address(tokenizerModule),
            selectors,
            ProtocolAdmin.PAUSE_ADMIN_ROLE
        );
    }

    function _deployMockCoreContracts() private {
        ERC6551Registry erc6551Registry = new ERC6551Registry();
        address impl = address(0);

        // protocolAccessManager
        protocolAccessManager = AccessManager(
            create3Deployer.deployDeterministic(
                abi.encodePacked(type(AccessManager).creationCode, abi.encode(deployer)),
                _getSalt(type(AccessManager).name)
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
        moduleRegistryAddr = address(moduleRegistry);
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
                _getDeployedAddress(IP_ACCOUNT_IMPL_BEACON_PROXY),
                _getDeployedAddress(type(GroupingModule).name),
                _getDeployedAddress(IP_ACCOUNT_IMPL_BEACON)
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
                address(ipAssetRegistry),
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

        // IPAccountImpl contracts
        bytes memory ipAccountImplCodeBytes = abi.encodePacked(
            type(IPAccountImpl).creationCode,
            abi.encode(
                address(accessController),
                address(ipAssetRegistry),
                address(licenseRegistry),
                address(moduleRegistry)
            )
        );
        _predeploy(IP_ACCOUNT_IMPL_CODE);
        ipAccountImplCode = IPAccountImpl(
            payable(create3Deployer.deployDeterministic(ipAccountImplCodeBytes, _getSalt(IP_ACCOUNT_IMPL_CODE)))
        );
        _postdeploy(IP_ACCOUNT_IMPL_CODE, address(ipAccountImplCode));
        require(
            _getDeployedAddress(IP_ACCOUNT_IMPL_CODE) == address(ipAccountImplCode),
            "Deploy: IP Account Impl Code Address Mismatch"
        );

        _predeploy(IP_ACCOUNT_IMPL_BEACON);
        ipAccountImplBeacon = UpgradeableBeacon(
            create3Deployer.deployDeterministic(
                abi.encodePacked(
                    type(UpgradeableBeacon).creationCode,
                    abi.encode(address(ipAccountImplCode), deployer)
                ),
                _getSalt(IP_ACCOUNT_IMPL_BEACON)
            )
        );
        _postdeploy(IP_ACCOUNT_IMPL_BEACON, address(ipAccountImplBeacon));

        _predeploy(IP_ACCOUNT_IMPL_BEACON_PROXY);
        ipAccountImpl = BeaconProxy(payable(
            create3Deployer.deployDeterministic(
                abi.encodePacked(
                    type(BeaconProxy).creationCode,
                    abi.encode(address(ipAccountImplBeacon), "")
                ),
                _getSalt(IP_ACCOUNT_IMPL_BEACON_PROXY)
            ))
        );
        _postdeploy(IP_ACCOUNT_IMPL_BEACON_PROXY, address(ipAccountImpl));

        // disputeModule
        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(
            new DisputeModule(address(accessController), address(ipAssetRegistry), address(licenseRegistry), address(ipGraphACL))
        );
        disputeModule = DisputeModule(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(DisputeModule).name),
                impl,
                abi.encodeCall(DisputeModule.initialize, address(protocolAccessManager))
            )
        );
        disputeModuleAddr = address(disputeModule);
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
                address(ipAssetRegistry),
                address(ipGraphACL)
            )
        );
        royaltyModule = RoyaltyModule(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RoyaltyModule).name),
                impl,
                abi.encodeCall(RoyaltyModule.initialize, (address(protocolAccessManager), uint256(15)))
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
                _getDeployedAddress(type(LicenseToken).name),
                address(ipGraphACL)
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
        royaltyPolicyLAPAddr = address(royaltyPolicyLAP);
        require(
            _getDeployedAddress(type(RoyaltyPolicyLAP).name) == address(royaltyPolicyLAP),
            "Deploy: Royalty Policy LAP Address Mismatch"
        );
        require(_loadProxyImpl(address(royaltyPolicyLAP)) == impl, "RoyaltyPolicyLAP Proxy Implementation Mismatch");

        // royaltyPolicyLRP
        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(new RoyaltyPolicyLRP(address(royaltyModule), address(royaltyPolicyLAP), address(ipGraphACL)));
        royaltyPolicyLRP = RoyaltyPolicyLRP(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RoyaltyPolicyLRP).name),
                impl,
                abi.encodeCall(RoyaltyPolicyLRP.initialize, address(protocolAccessManager))
            )
        );
        royaltyPolicyLRPAddr = address(royaltyPolicyLRP);
        require(
            _getDeployedAddress(type(RoyaltyPolicyLRP).name) == address(royaltyPolicyLRP),
            "Deploy: Royalty Policy LRP Address Mismatch"
        );
        require(_loadProxyImpl(address(royaltyPolicyLRP)) == impl, "RoyaltyPolicyLRP Proxy Implementation Mismatch");

        // ipRoyaltyVaultImpl
        ipRoyaltyVaultImpl = IpRoyaltyVault(
            create3Deployer.deployDeterministic(
                abi.encodePacked(
                    type(IpRoyaltyVault).creationCode,
                    abi.encode(address(disputeModule), address(royaltyModule), address(ipAssetRegistry), _getDeployedAddress(type(GroupingModule).name))
                ),
                _getSalt(type(IpRoyaltyVault).name)
            )
        );

        // ipRoyaltyVaultBeacon
        ipRoyaltyVaultBeacon = UpgradeableBeacon(
            create3Deployer.deployDeterministic(
                abi.encodePacked(
                    type(UpgradeableBeacon).creationCode,
                    abi.encode(address(ipRoyaltyVaultImpl), deployer)
                ),
                _getSalt("ipRoyaltyVaultBeacon")
            )
        );

        // licenseToken
        impl = address(0); // Make sure we don't deploy wrong impl
        impl = address(new LicenseToken(address(licensingModule), address(disputeModule), address(licenseRegistry)));
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
                address(royaltyModule),
                address(moduleRegistry)
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
            create3Deployer.deployDeterministic(
                abi.encodePacked(
                    type(CoreMetadataModule).creationCode,
                    abi.encode(address(accessController), address(ipAssetRegistry))
                ),
                _getSalt(type(CoreMetadataModule).name)
            )
        );
        coreMetadataModuleAddr = address(coreMetadataModule);

        // coreMetadataViewModule
        coreMetadataViewModule = CoreMetadataViewModule(
            create3Deployer.deployDeterministic(
                abi.encodePacked(
                    type(CoreMetadataViewModule).creationCode,
                    abi.encode(address(ipAssetRegistry), address(moduleRegistry))
                ),
                _getSalt(type(CoreMetadataViewModule).name)
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
                address(royaltyModule),
                address(disputeModule)
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

        // WIP
        wip = new MockERC20("Wrapped IP", "WIP");
        wipAddr = address(wip);
    }

    function _configureMockCoreContracts() private {
        moduleRegistry.registerModule("DISPUTE_MODULE", address(disputeModule));
        moduleRegistry.registerModule("LICENSING_MODULE", address(licensingModule));
        moduleRegistry.registerModule("ROYALTY_MODULE", address(royaltyModule));
        moduleRegistry.registerModule("CORE_METADATA_MODULE", address(coreMetadataModule));
        moduleRegistry.registerModule("CORE_METADATA_VIEW_MODULE", address(coreMetadataViewModule));
        moduleRegistry.registerModule("GROUPING_MODULE", address(groupingModule));

        ipGraphACL.whitelistAddress(address(licenseRegistry));
        ipGraphACL.whitelistAddress(address(royaltyPolicyLAP));
        ipGraphACL.whitelistAddress(address(royaltyPolicyLRP));
        ipGraphACL.whitelistAddress(address(royaltyModule));
        ipGraphACL.whitelistAddress(address(disputeModule));
        ipGraphACL.whitelistAddress(address(licensingModule));

        coreMetadataViewModule.updateCoreMetadataModule();

        // set up default license terms
        pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        licenseRegistry.registerLicenseTemplate(address(pilTemplate));
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), PILFlavors.getNonCommercialSocialRemixingId(pilTemplate));

        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLRP), true);
        royaltyModule.setIpRoyaltyVaultBeacon(address(ipRoyaltyVaultBeacon));
        royaltyModule.whitelistRoyaltyToken(address(wip), true);
        ipRoyaltyVaultBeacon.transferOwnership(address(royaltyPolicyLAP));

        // add evenSplitGroupPool to whitelist of group pools
        groupingModule.whitelistGroupRewardPool(address(evenSplitGroupPool), true);

        // grant roles
        protocolAccessManager.grantRole(ProtocolAdmin.UPGRADER_ROLE, mockDeployer, 0);
        protocolAccessManager.grantRole(ProtocolAdmin.PROTOCOL_ADMIN_ROLE, mockDeployer, 0);
        protocolAccessManager.grantRole(ProtocolAdmin.PAUSE_ADMIN_ROLE, mockDeployer, 0);
    }

    /// @dev get the salt for the contract deployment with CREATE3
    function _getSalt(string memory name) internal view returns (bytes32 salt) {
        salt = keccak256(abi.encode(name, create3SaltSeed));
    }

    /// @dev Get the deterministic deployed address of a contract with CREATE3
    function _getDeployedAddress(string memory name) internal view returns (address) {
        return create3Deployer.predictDeterministicAddress(_getSalt(name));
    }

    /// @dev Load the implementation address from the proxy contract
    function _loadProxyImpl(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
    }

    function _predeploy(string memory contractKey) internal view {
        if (writeDeploys) console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) internal {
        if (writeDeploys) {
            _writeAddress(contractKey, newAddress);
            console2.log(string.concat(contractKey, " deployed to:"), newAddress);
        }
    }
}
