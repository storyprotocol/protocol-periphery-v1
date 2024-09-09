/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { ICreate3Deployer } from "@create3-deployer/contracts/ICreate3Deployer.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { StorageLayoutChecker } from "@storyprotocol/script/utils/upgrades/StorageLayoutCheck.s.sol";

// contracts
import { SPGNFT } from "../../contracts/SPGNFT.sol";
import { GroupingWorkflows } from "../../contracts/GroupingWorkflows.sol";
import { StoryProtocolGateway } from "../../contracts/StoryProtocolGateway.sol";

// script
import { StringUtil } from "./StringUtil.sol";
import { BroadcastManager } from "./BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "./JsonDeploymentHandler.s.sol";
import { StoryProtocolCoreAddressManager } from "./StoryProtocolCoreAddressManager.sol";

// test
import { TestProxyHelper } from "../../test/utils/TestProxyHelper.t.sol";

contract DeployHelper is
    Script,
    BroadcastManager,
    StorageLayoutChecker,
    JsonDeploymentHandler,
    StoryProtocolCoreAddressManager
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
    StoryProtocolGateway internal spg;
    GroupingWorkflows internal groupingWorkflows;

    // DeployHelper variable
    bool private writeDeploys;

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
    function run(uint256 create3SaltSeed_, bool runStorageLayoutCheck, bool writeDeploys_) public virtual {
        create3SaltSeed = create3SaltSeed_;
        writeDeploys = writeDeploys_;

        // This will run OZ storage layout check for all contracts. Requires --ffi flag.
        if (runStorageLayoutCheck) super.run();

        _readStoryProtocolCoreAddresses(); // StoryProtocolCoreAddressManager.s.sol
        _beginBroadcast(); // BroadcastManager.s.sol

        _deployPeripheryContracts();
        _configureDeployment();

        // Check deployment configuration.
        if (spgNftBeacon.owner() != address(spg)) {
            revert DeploymentConfigError("SPG is not the owner of SPGNFTBeacon");
        }

        if (writeDeploys) _writeDeployment();
        _endBroadcast(); // BroadcastManager.s.sol

        // Set SPGNFTBeacon for periphery workflow contracts, access controlled
        // can't be done in deployment script:
        // spg.setSPGNFTBeacon(address(spgNftBeacon));
        // groupingWorkflows.setSPGNFTBeacon(address(spgNftBeacon));
    }

    function _deployPeripheryContracts() private {
        address impl;

        // Periphery workflow contracts
        _predeploy("SPG");
        impl = address(
            new StoryProtocolGateway(
                accessControllerAddr,
                ipAssetRegistryAddr,
                licensingModuleAddr,
                licenseRegistryAddr,
                royaltyModuleAddr,
                coreMetadataModuleAddr,
                pilTemplateAddr,
                licenseTokenAddr
            )
        );
        spg = StoryProtocolGateway(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(StoryProtocolGateway).name),
                impl,
                abi.encodeCall(StoryProtocolGateway.initialize, address(protocolAccessManagerAddr))
            )
        );
        impl = address(0);
        _postdeploy("SPG", address(spg));

        _predeploy("GroupingWorkflows");
        impl = address(
            new GroupingWorkflows(
                accessControllerAddr,
                coreMetadataModuleAddr,
                groupingModuleAddr,
                groupNFTAddr,
                ipAssetRegistryAddr,
                licensingModuleAddr,
                licenseRegistryAddr,
                pilTemplateAddr
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

        // SPGNFT contracts
        _predeploy("SPGNFTImpl");
        spgNftImpl = SPGNFT(
            create3Deployer.deploy(
                _getSalt(type(SPGNFT).name),
                abi.encodePacked(type(SPGNFT).creationCode, abi.encode(address(spg), address(groupingWorkflows)))
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

    function _predeploy(string memory contractKey) private view {
        if (writeDeploys) console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        if (writeDeploys) {
            _writeAddress(contractKey, newAddress);
            console2.log(string.concat(contractKey, " deployed to:"), newAddress);
        }
    }

    function _configureDeployment() private {
       // Transfer ownership of beacon proxy to SPG
       spgNftBeacon.transferOwnership(address(spg));

       // more configurations may be added here
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
