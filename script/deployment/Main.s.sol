// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
/* solhint-disable no-console */

// script
import { DeployHelper } from "../utils/DeployHelper.sol";

contract Main is DeployHelper {
    address internal CREATE3_DEPLOYER = 0x384a891dFDE8180b054f04D66379f16B7a678Ad6;
    uint256 private constant CREATE3_DEFAULT_SEED = 12;

    constructor() DeployHelper(CREATE3_DEPLOYER){}

    /// @dev To use, run the following command (e.g., for Story Iliad testnet):
    /// forge script script/deployment/Main.s.sol:Main --rpc-url=$TESTNET_URL \
    /// -vvvv --broadcast --priority-gas-price=1 --legacy \
    /// --verify --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ///
    /// For detailed examples, see the documentation in `../../docs/DEPLOY_UPGRADE.md`.
    function run() public virtual override {
        _run(CREATE3_DEFAULT_SEED);
    }

    function run(uint256 seed) public {
        _run(seed);
    }

    function _run(uint256 seed) internal {
        // deploy all contracts via DeployHelper
        super.run(
            seed, // create3 seed
            false, // runStorageLayoutCheck
            true, // writeDeployments
            false // isTest
        );
        _writeDeployment(); // write deployment json to deployments/deployment-{chainId}.json
    }
}
