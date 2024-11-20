// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Test } from "forge-std/Test.sol";
import { Create3Deployer } from "@create3-deployer/contracts/Create3Deployer.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { AccessPermission } from "@storyprotocol/core/lib/AccessPermission.sol";
import { IAccessController } from "@storyprotocol/core/interfaces/access/IAccessController.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { MetaTx } from "@storyprotocol/core/lib/MetaTx.sol";
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";

// contracts
import { ISPGNFT } from "../../contracts/interfaces/ISPGNFT.sol";
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";
import { IStoryBadgeNFT } from "../../contracts/interfaces/story-nft/IStoryBadgeNFT.sol";
import { IStoryNFT } from "../../contracts/interfaces/story-nft/IStoryNFT.sol";
import { StoryBadgeNFT } from "../../contracts/story-nft/StoryBadgeNFT.sol";

// script
import { DeployHelper } from "../../script/utils/DeployHelper.sol";

// test
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockERC721 } from "../mocks/MockERC721.sol";
import { Users, UserSecretKeys, UsersLib } from "../utils/Users.t.sol";

/// @title Base Test Contract
contract BaseTest is Test, DeployHelper {
    using MessageHashUtils for bytes32;

    /// @dev Users struct to abstract away user management when testing
    Users internal u;

    /// @dev UserSecretKeys struct to abstract away user secret keys when testing
    UserSecretKeys internal sk;

    /// @dev User roles for workflow tests
    address internal caller; // function caller
    address internal minter; // minter of the mock collections
    address internal feeRecipient; // fee recipient of the mock collections
    uint256 internal minterSk;

    /// @dev User roles for story NFT tests
    StoryBadgeNFT internal rootOrgStoryNft;
    address internal orgStoryNftFactorySigner;
    address internal rootOrgStoryNftSigner;
    address internal rootOrgStoryNftOwner;
    uint256 internal orgStoryNftFactorySignerSk;
    uint256 internal rootOrgStoryNftSignerSk;

    /// @dev Create3 deployer address
    address internal CREATE3_DEPLOYER = address(new Create3Deployer());
    uint256 internal CREATE3_DEFAULT_SEED = 1234567890;

    /// @dev Mock assets
    MockERC20 internal mockToken;
    MockERC721 internal mockNft;
    ISPGNFT internal spgNftPublic;
    ISPGNFT internal spgNftPrivate;
    ISPGNFT internal nftContract;

    /// @dev Mock IPMetadata
    WorkflowStructs.IPMetadata internal ipMetadataEmpty;
    WorkflowStructs.IPMetadata internal ipMetadataDefault;

    /// @dev test baseURI
    string internal testBaseURI = "https://test-base-uri.com/";
    string internal testContractURI = "https://test-contract-uri.com/";

    constructor() DeployHelper(CREATE3_DEPLOYER) {}

    function setUp() public virtual {
        // mock IPGraph precompile
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        // initialize users and their secret keys
        _setupUsers();

        // deploy and set up protocol core and periphery contracts
        _setupProtocolContracts();

        // setup mock assets
        _setupMockAssets();

        // setup test IPMetadata
        _setupIPMetadata();

        // deploy and set up story NFT contracts
        _setupStoryNftContracts();
    }

    function _setupUsers() internal {
        (u, sk) = UsersLib.createMockUsers(vm);

        minter = u.alice;
        feeRecipient = u.carl;

        minterSk = sk.alice;
    }

    function _setupProtocolContracts() internal {
        mockDeployer = u.admin; // admin is the deployer
        vm.startPrank(u.admin);

        // deploy core and periphery contracts via DeployHelper
        super.run(
            CREATE3_DEFAULT_SEED,
            false, // runStorageLayoutCheck
            false, // writeDeploys
            true // isTest
        );

        // set the NFT contract beacon for workflow contracts
        derivativeWorkflows.setNftContractBeacon(address(spgNftBeacon));
        groupingWorkflows.setNftContractBeacon(address(spgNftBeacon));
        licenseAttachmentWorkflows.setNftContractBeacon(address(spgNftBeacon));
        registrationWorkflows.setNftContractBeacon(address(spgNftBeacon));
        vm.stopPrank();
    }

    function _setupMockAssets() internal {
        vm.startPrank(minter);
        mockToken = new MockERC20("MockERC20", "MKT");
        mockNft = new MockERC721("TestNFT");

        vm.label(address(mockToken), "MockERC20");
        vm.label(address(mockNft), "MockERC721");

        spgNftPublic = ISPGNFT(
            registrationWorkflows.createCollection(
                ISPGNFT.InitParams({
                    name: "Test SPG NFT Public",
                    symbol: "TSPGNFTPUB",
                    baseURI: testBaseURI,
                    contractURI: testContractURI,
                    maxSupply: 100_000_000,
                    mintFee: 1 * 10 ** mockToken.decimals(), // 1 token
                    mintFeeToken: address(mockToken),
                    mintFeeRecipient: feeRecipient,
                    owner: minter,
                    mintOpen: true,
                    isPublicMinting: true
                })
            )
        );

        spgNftPrivate = ISPGNFT(
            registrationWorkflows.createCollection(
                ISPGNFT.InitParams({
                    name: "Test SPG NFT Private",
                    symbol: "TSPGNFTPRI",
                    baseURI: testBaseURI,
                    contractURI: testContractURI,
                    maxSupply: 100_000_000,
                    mintFee: 1 * 10 ** mockToken.decimals(), // 1 token
                    mintFeeToken: address(mockToken),
                    mintFeeRecipient: feeRecipient,
                    owner: minter,
                    mintOpen: true,
                    isPublicMinting: false
                })
            )
        );
        vm.stopPrank();

        // whitelist mockToken as a royalty token
        vm.prank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(mockToken), true);
    }

    function _setupIPMetadata() internal {
        ipMetadataEmpty = WorkflowStructs.IPMetadata({
            ipMetadataURI: "",
            ipMetadataHash: "",
            nftMetadataURI: "",
            nftMetadataHash: ""
        });

        ipMetadataDefault = WorkflowStructs.IPMetadata({
            ipMetadataURI: "test-ip-uri",
            ipMetadataHash: "test-ip-hash",
            nftMetadataURI: "test-nft-uri",
            nftMetadataHash: "test-nft-hash"
        });
    }

    function _setupStoryNftContracts() internal {
        orgStoryNftFactorySigner = u.alice;
        rootOrgStoryNftSigner = u.alice;
        rootOrgStoryNftOwner = u.admin;
        orgStoryNftFactorySignerSk = sk.alice;
        rootOrgStoryNftSignerSk = sk.alice;

        (address defaultLicenseTemplate, uint256 defaultLicenseTermsId) = licenseRegistry.getDefaultLicenseTerms();
        string memory rootOrgName = "Test Root Org";
        string memory rootOrgTokenURI = "Test Token URI";

        bytes memory rootOrgStoryNftCustomInitParams = abi.encode(
            IStoryBadgeNFT.CustomInitParams({
                tokenURI: rootOrgTokenURI,
                signer: rootOrgStoryNftSigner,
                ipMetadataURI: ipMetadataDefault.ipMetadataURI,
                ipMetadataHash: ipMetadataDefault.ipMetadataHash,
                nftMetadataHash: ipMetadataDefault.nftMetadataHash
            })
        );

        IStoryNFT.StoryNftInitParams memory rootOrgStoryNftInitParams = IStoryNFT.StoryNftInitParams({
            owner: rootOrgStoryNftOwner,
            name: "Test Org Badge",
            symbol: "TOB",
            contractURI: "Test Contract URI",
            baseURI: "",
            customInitData: rootOrgStoryNftCustomInitParams
        });

        vm.startPrank(u.admin);
        _deployAndConfigStoryNftContracts({
            licenseTemplate_: defaultLicenseTemplate,
            licenseTermsId_: defaultLicenseTermsId,
            orgStoryNftFactorySigner: orgStoryNftFactorySigner,
            isTest: true
        });

        (, , , address rootOrgStoryNftAddr) = orgStoryNftFactory.deployOrgStoryNftByAdmin({
            orgStoryNftTemplate: defaultOrgStoryNftTemplate,
            orgNftRecipient: rootOrgStoryNftOwner,
            orgName: rootOrgName,
            orgIpMetadata: ipMetadataDefault,
            storyNftInitParams: rootOrgStoryNftInitParams,
            isRootOrg: true
        });
        rootOrgStoryNft = StoryBadgeNFT(rootOrgStoryNftAddr);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/
    modifier withCollection() {
        nftContract = ISPGNFT(
            registrationWorkflows.createCollection(
                ISPGNFT.InitParams({
                    name: "Test Collection",
                    symbol: "TEST",
                    baseURI: testBaseURI,
                    contractURI: testContractURI,
                    maxSupply: 100,
                    mintFee: 100 * 10 ** mockToken.decimals(),
                    mintFeeToken: address(mockToken),
                    mintFeeRecipient: feeRecipient,
                    owner: minter,
                    mintOpen: true,
                    isPublicMinting: false
                })
            )
        );
        _;
    }

    modifier whenCallerHasMinterRole() {
        caller = minter;
        vm.startPrank(caller);
        _;
    }

    modifier withEnoughTokens(address workflows) {
        require(caller != address(0), "withEnoughTokens: caller not set");
        mockToken.mint(address(caller), 100000 * 10 ** mockToken.decimals());
        mockToken.approve(address(nftContract), 10000 * 10 ** mockToken.decimals());
        mockToken.approve(address(workflows), 10000 * 10 ** mockToken.decimals());
        _;
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

    /// @dev Uses `signerSk` to sign `addr` and return the signature.
    function _signAddress(uint256 signerSk, address addr) internal pure returns (bytes memory signature) {
        bytes32 digest = keccak256(abi.encodePacked(addr)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /// @dev Assert metadata for the IP.
    function assertMetadata(address ipId, WorkflowStructs.IPMetadata memory expectedMetadata) internal view {
        assertEq(coreMetadataViewModule.getMetadataURI(ipId), expectedMetadata.ipMetadataURI);
        assertEq(coreMetadataViewModule.getMetadataHash(ipId), expectedMetadata.ipMetadataHash);
        assertEq(coreMetadataViewModule.getNftMetadataHash(ipId), expectedMetadata.nftMetadataHash);
    }

    /// @dev Assert parent and derivative relationship.
    function assertParentChild(
        address parentIpId,
        address childIpId,
        uint256 expectedParentCount,
        uint256 expectedParentIndex
    ) internal view {
        assertTrue(licenseRegistry.hasDerivativeIps(parentIpId));
        assertTrue(licenseRegistry.isDerivativeIp(childIpId));
        assertTrue(licenseRegistry.isParentIp({ parentIpId: parentIpId, childIpId: childIpId }));
        assertEq(licenseRegistry.getParentIpCount(childIpId), expectedParentCount);
        assertEq(licenseRegistry.getParentIp(childIpId, expectedParentIndex), parentIpId);
    }
}
