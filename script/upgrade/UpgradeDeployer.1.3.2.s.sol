// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/* solhint-disable no-console */

// external
import { console2 } from "forge-std/console2.sol";
import { BroadcastManager } from "@storyprotocol/script/utils/BroadcastManager.s.sol";
import { ICreate3Deployer } from "@storyprotocol/script/utils/ICreate3Deployer.sol";
import { JsonDeploymentHandler } from "@storyprotocol/script/utils/JsonDeploymentHandler.s.sol";
import { StorageLayoutChecker } from "@storyprotocol/script/utils/upgrades/StorageLayoutCheck.s.sol";
import { UpgradedImplHelper } from "@storyprotocol/script/utils/upgrades/UpgradedImplHelper.sol";

// contracts
import { DerivativeWorkflows } from "../../contracts/workflows/DerivativeWorkflows.sol";
import { GroupingWorkflows } from "../../contracts/workflows/GroupingWorkflows.sol";
import { LicenseAttachmentWorkflows } from "../../contracts/workflows/LicenseAttachmentWorkflows.sol";
import { RegistrationWorkflows } from "../../contracts/workflows/RegistrationWorkflows.sol";
import { RoyaltyWorkflows } from "../../contracts/workflows/RoyaltyWorkflows.sol";
import { RoyaltyTokenDistributionWorkflows } from "../../contracts/workflows/RoyaltyTokenDistributionWorkflows.sol";
import { SPGNFT } from "../../contracts/SPGNFT.sol";
import { OwnableERC20 } from "../../contracts/modules/tokenizer/OwnableERC20.sol";
import { TokenizerModule } from "../../contracts/modules/tokenizer/TokenizerModule.sol";
import { LockLicenseHook } from "../../contracts/hooks/LockLicenseHook.sol";
import { TotalLicenseTokenLimitHook } from "../../contracts/hooks/TotalLicenseTokenLimitHook.sol";

// script
import { StoryProtocolCoreAddressManager } from "../utils/StoryProtocolCoreAddressManager.sol";


/**
 * @title Upgrade Deployer Script
 * @dev Script for deploying new implementation contracts during protocol upgrades.
 *      This deploys the upgraded implementations of periphery contracts while maintaining
 *      existing proxy addresses. Each deployment generates upgrade proposals that can
 *      be executed via UpgradeExecutor to point the proxies to the new implementations.
 *
 *      To use run the script with the following command:
 *      forge script script/upgrade/UpgradeDeployer.example.s.sol:UpgradeDeployerExample --rpc-url=$RPC_URL --broadcast --priority-gas-price=1 --legacy --verify --verifier=blockscout --verifier-url=$VERIFIER_URL
 */
contract UpgradeDeployer is
    JsonDeploymentHandler,
    BroadcastManager,
    UpgradedImplHelper,
    StoryProtocolCoreAddressManager,
    StorageLayoutChecker
{
    // PROXY 1967 IMPLEMENTATION STORAGE SLOTS
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    address internal constant WIP_ADDR = 0x1514000000000000000000000000000000000000;

    ICreate3Deployer internal create3Deployer = ICreate3Deployer(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);
    uint256 internal CREATE3_DEFAULT_SEED = 8;


    string constant PREV_VERSION = "v1.3.1"; // previous version e.g. v1.3.0
    string constant PROPOSAL_VERSION = "v1.3.2"; // new version e.g. v1.3.1

    address derivativeWorkflowsAddr;
    address groupingWorkflowsAddr;
    address licenseAttachmentWorkflowsAddr;
    address registrationWorkflowsAddr;
    address royaltyTokenDistributionWorkflowsAddr;
    address royaltyWorkflowsAddr;
    address tokenizerModuleAddr;
    address ownableERC20BeaconAddr;

    constructor() JsonDeploymentHandler("main") {}

    function run() public {
        _readStoryProtocolCoreAddresses();
        _readDeployment(PREV_VERSION); // JsonDeploymentHandler.s.sol

        derivativeWorkflowsAddr = _readAddress("DerivativeWorkflows");
        groupingWorkflowsAddr = _readAddress("GroupingWorkflows");
        licenseAttachmentWorkflowsAddr = _readAddress("LicenseAttachmentWorkflows");
        registrationWorkflowsAddr = _readAddress("RegistrationWorkflows");
        royaltyTokenDistributionWorkflowsAddr = _readAddress("RoyaltyTokenDistributionWorkflows");
        royaltyWorkflowsAddr = _readAddress("RoyaltyWorkflows");
        tokenizerModuleAddr = _readAddress("TokenizerModule");
        ownableERC20BeaconAddr = _readAddress("OwnableERC20Beacon");

        _beginBroadcast(); // BroadcastManager.s.sol

        UpgradedImplHelper.UpgradeProposal[] memory proposals = deploy();
        _writeUpgradeProposals(PREV_VERSION, PROPOSAL_VERSION, proposals); // JsonDeploymentHandler.s.sol

        _endBroadcast(); // BroadcastManager.s.sol
    }


    function deploy() public returns (UpgradedImplHelper.UpgradeProposal[] memory) {
        string memory contractKey;
        address impl;

        // Deploy new implementations
        contractKey = "DerivativeWorkflows";
        _predeploy(contractKey);
        impl = address(new DerivativeWorkflows(
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
        _addProposal({key: contractKey, proxy: derivativeWorkflowsAddr, newImpl: impl});
        impl = address(0);

        contractKey = "GroupingWorkflows";
        _predeploy(contractKey);
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
        _addProposal({key: contractKey, proxy: groupingWorkflowsAddr, newImpl: impl});
        impl = address(0);

        contractKey = "LicenseAttachmentWorkflows";
        _predeploy(contractKey);
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
        _addProposal({key: contractKey, proxy: licenseAttachmentWorkflowsAddr, newImpl: impl});
        impl = address(0);

        contractKey = "RegistrationWorkflows";
        _predeploy(contractKey);
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
        _addProposal({key: contractKey, proxy: registrationWorkflowsAddr, newImpl: impl});
        impl = address(0);

        contractKey = "RoyaltyTokenDistributionWorkflows";
        _predeploy(contractKey);
        impl = address(new RoyaltyTokenDistributionWorkflows(
            accessControllerAddr,
            coreMetadataModuleAddr,
            ipAssetRegistryAddr,
            licenseRegistryAddr,
            licensingModuleAddr,
            pilTemplateAddr,
            royaltyModuleAddr,
            royaltyPolicyLRPAddr,
            WIP_ADDR
        ));
        _addProposal({key: contractKey, proxy: royaltyTokenDistributionWorkflowsAddr, newImpl: impl});
        impl = address(0);

        contractKey = "RoyaltyWorkflows";
        _predeploy(contractKey);
        impl = address(new RoyaltyWorkflows(royaltyModuleAddr));
        _addProposal({key: contractKey, proxy: royaltyWorkflowsAddr, newImpl: impl});
        impl = address(0);


        contractKey = "SPGNFTImpl";
        _predeploy(contractKey);
        impl = address(create3Deployer.deployDeterministic(
                abi.encodePacked(type(SPGNFT).creationCode,
                    abi.encode(
                        address(derivativeWorkflowsAddr),
                        address(groupingWorkflowsAddr),
                        address(licenseAttachmentWorkflowsAddr),
                        address(registrationWorkflowsAddr),
                        address(royaltyTokenDistributionWorkflowsAddr)
                    )
                ),
                _getSalt(string.concat(type(SPGNFT).name, PROPOSAL_VERSION))
            )
        );
        _addProposal({key: contractKey, proxy: registrationWorkflowsAddr, newImpl: impl});
        impl = address(0);

        contractKey = "TokenizerModule";
        _predeploy(contractKey);
        impl = address(new TokenizerModule(
            accessControllerAddr,
            ipAssetRegistryAddr,
            licenseRegistryAddr,
            disputeModuleAddr
        ));
        _addProposal({key: contractKey, proxy: tokenizerModuleAddr, newImpl: impl});
        impl = address(0);

        contractKey = "OwnableERC20Template";
        _predeploy(contractKey);
        impl = address(create3Deployer.deployDeterministic(
            abi.encodePacked(type(OwnableERC20).creationCode,
                abi.encode(
                    ownableERC20BeaconAddr
                )
            ),
            _getSalt(string.concat(type(OwnableERC20).name, PROPOSAL_VERSION))
        ));
        _addProposal({key: contractKey, proxy: tokenizerModuleAddr, newImpl: impl});
        impl = address(0);

        return _returnProposals();
    }

    function _returnProposals() private view returns (UpgradedImplHelper.UpgradeProposal[] memory) {
        UpgradedImplHelper.UpgradeProposal[] memory proposals = new UpgradedImplHelper.UpgradeProposal[](upgradeProposals.length);
        for (uint256 i = 0; i < upgradeProposals.length; i++) {
            proposals[i] = upgradeProposals[i];
        }
        return proposals;
    }

    function _predeploy(string memory contractKey) private view {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    /// @dev get the salt for the contract deployment with CREATE3
    function _getSalt(string memory name) private view returns (bytes32 salt) {
        salt = keccak256(abi.encode(name, PROPOSAL_VERSION));
    }
}
