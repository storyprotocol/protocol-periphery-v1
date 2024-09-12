# Deploy & Upgrade with Foundry Scripts


>📌 Note: prior to deployment/upgrade you need to install Foundry, more info [here](https://book.getfoundry.sh/getting-started/installation).

**🙋 Example environment variables**:

```bash
MAINNET_URL=https://eth-mainnet.g.alchemy.com/v2/1234123412341234
MAINNET_PRIVATEKEY=0x123456789abcdef
TESTNET_URL=https://testnet.storyrpc.io
TESTNET_PRIVATEKEY=0x123456789abcdef
ETHERSCAN_API_KEY=0x123456789abcdef

VERIFIER_NAME=blockscout
VERIFIER_URL=https://testnet.storyscan.xyz/api

# RegistrationWorkflows proxy contract address
REGWORKFLOWS_PROXY_ADDR=0x123456789abcdef
#... other workflow contract proxy addresses

NEW_REGWORKFLOWS_IMPL_ADDR= #<the new RegistrationWorkflows implementation contract address you got from running the upgrade script>
#... other new workflow contract implementation addresses

SPGNFT_BEACON_ADDR=0x123456789abcdef
NEW_SPGNFT_IMPL_ADDR= #<the new SPGNFT implementation contract address you got from running the upgrade script>
```

## Deployment Example

1. Run the [deployment script](../script/deployment/Main.s.sol) with the following command:

    ```bash
    forge script script/deployment/Main.s.sol:Main --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ```

2. Set NFT beacon contract for workflow contracts using the admin account by calling `setNFTContractBeacon` with the following command:

    ```bash
    cast send $REGWORKFLOWS_PROXY_ADDR "setNftContractBeacon(address)" $SPGNFT_BEACON_ADDR --rpc-url=$TESTNET_URL --private-key=$ADMIN_PRIVATEKEY --legacy --gas-limit=1000000
    # ... repeat for each workflow contract
    ```


## Workflow Contracts Upgrade Example

1. Run the [upgrade script](../script/upgrade/UpgradeRegistrationWorkflows.s.sol) with the following command:

    ```bash
    forge script script/upgrade/UpgradeRegistrationWorkflows.s.sol:UpgradeRegistrationWorkflows --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ```

2. Update the proxy contract to point to the newest implementation by calling `upgradeToAndCall` with the following command:

    ```bash
    cast send $REGWORKFLOWS_PROXY_ADDR "upgradeToAndCall(address,bytes)" $NEW_REGWORKFLOWS_IMPL_ADDR "0x" --rpc-url=$TESTNET_URL --private-key=$ADMIN_PRIVATEKEY --legacy --gas-limit=1000000
    ```

## SPGNFT Upgrade Example

1. Run the [SPGNFT upgrade script](../script/upgrade/UpgradeSPGNFT.s.sol) with the following command:

    ```bash
    forge script script/upgrade/UpgradeSPGNFT.s.sol:UpgradeSPGNFT --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ```

2. Update workflow contracts to use the newest SPGNFT implementation by calling `upgradeCollections` function inside `RegistrationWorkflows` contract with the following command:

    ```bash
    cast send $REGWORKFLOWS_PROXY_ADDR "upgradeCollections(address)" $NEW_SPGNFT_IMPL_ADDR --rpc-url=$TESTNET_URL --private-key=$ADMIN_PRIVATEKEY --legacy --gas-limit=1000000
    ```
