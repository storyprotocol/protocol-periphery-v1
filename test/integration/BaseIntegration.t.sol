//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { Test } from "forge-std/Test.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MetaTx } from "@storyprotocol/core/lib/MetaTx.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { ICoreMetadataViewModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataViewModule.sol";

// contracts
import { IStoryProtocolGateway as ISPG } from "../../contracts/interfaces/IStoryProtocolGateway.sol";

// script
import { DeployHelper } from "../../script/utils/DeployHelper.sol";

// test
import { MockIPGraph } from "../mocks/MockIPGraph.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockERC721 } from "../mocks/MockERC721.sol";
import { Users, UserSecretKeys, UsersLib } from "../utils/Users.t.sol";

contract BaseIntegration is Test, DeployHelper {
    /// @dev RPC URL for the fork
    string internal constant RPC_URL = "https://testnet.storyrpc.io"; // Iliad Testnet RPC

    uint256 internal constant FORK_CHAIN_ID = 1513; // Iliad Testnet Chain ID

    /// @dev Users struct to abstract away user management when testing
    Users internal u;

    /// @dev UserSecretKeys struct to abstract away user secret keys when testing
    UserSecretKeys internal sk;

    address internal minter;
    address internal feeRecipient;

    /// @dev Minter's secret key
    uint256 internal minterSk;

    /// @dev Multisig address
    address internal multiSig;

    /// @dev Create3 deployer address
    address internal CREATE3_DEPLOYER = 0x384a891dFDE8180b054f04D66379f16B7a678Ad6;
    uint256 internal CREATE3_DEFAULT_SEED = 1234567890;

    /// @dev Mock assets
    address internal mockToken;
    address internal mockNFT;
    address internal spgNFT;

    /// @dev IPMetadata
    ISPG.IPMetadata internal ipMetadataEmpty;
    ISPG.IPMetadata internal ipMetadataDefault;

    constructor() DeployHelper(CREATE3_DEPLOYER) {}

    /// @notice Sets up the base integration test environment
    function setUp() public virtual {
        // create and activate fork
        uint256 forkId = vm.createSelectFork(RPC_URL);
        assertEq(vm.activeFork(), forkId);
        assertEq(block.chainid, FORK_CHAIN_ID);

        // mock IPGraph precompile
        vm.etch(address(0x1A), address(new MockIPGraph()).code);

        multiSig = vm.envAddress("MULTISIG_ADDRESS");

        // initialize users and their secret keys
        _setupUsers();

        // deploy and set up periphery contracts
        _setupPeripheryContracts();

        // setup mock assets
        _setupMockAssets();

        // setup test IPMetadata
        _setupIPMetadata();
    }

    function _setupUsers() internal {
        (u, sk) = UsersLib.createMockUsers(vm);
    }

    function _setupPeripheryContracts() internal {
        // set deployer to multisig
        deployer = multiSig;
        vm.startPrank(deployer);

        // deploy periphery contracts via DeployHelper
        super.run(
            CREATE3_DEFAULT_SEED,
            false, // runStorageLayoutCheck
            false, // writeDeploys
            true // isTest
        );

        // set the NFT contract beacon for workflow contracts
        spg.setNftContractBeacon(address(spgNftBeacon));
        groupingWorkflows.setNftContractBeacon(address(spgNftBeacon));
        vm.stopPrank();
    }

    function _setupMockAssets() internal {
        vm.startPrank(u.alice);
        mockToken = address(new MockERC20());
        mockNFT = address(new MockERC721("TestNFT"));

        spgNFT = spg.createCollection({
            name: "TestSPGNFT",
            symbol: "TSPGNFT",
            maxSupply: 100_000_000,
            mintFee: 1 * 10 ** MockERC20(mockToken).decimals(), // 1 tokens
            mintFeeToken: mockToken,
            mintFeeRecipient: feeRecipient,
            owner: u.alice,
            mintOpen: true,
            isPublicMinting: true
        });
        vm.stopPrank();
    }

    function _setupIPMetadata() internal {
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

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

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

    /// @dev Assert metadata for the IP.
    function assertMetadata(address ipId, ISPG.IPMetadata memory expectedMetadata) internal view {
        assertEq(
            ICoreMetadataViewModule(coreMetadataViewModuleAddr).getMetadataURI(ipId),
            expectedMetadata.ipMetadataURI
        );
        assertEq(
            ICoreMetadataViewModule(coreMetadataViewModuleAddr).getMetadataHash(ipId),
            expectedMetadata.ipMetadataHash
        );
        assertEq(
            ICoreMetadataViewModule(coreMetadataViewModuleAddr).getNftMetadataHash(ipId),
            expectedMetadata.nftMetadataHash
        );
    }
}
