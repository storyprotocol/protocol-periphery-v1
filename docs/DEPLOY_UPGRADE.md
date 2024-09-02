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

SPG_PROXY_ADDR=0x123456789abcdef
SPGNFT_BEACON_ADDR=0x123456789abcdef

NEW_SPG_IMPL_ADDR= #<the new SPG implementation contract address you got from running the upgrade script>
NEW_SPGNFT_IMPL_ADDR= #<the new SPGNFT implementation contract address you got from running the upgrade script>
```

## Deployment

1. Run the [deployment script](script/Main.s.sol) with the following command:

    ```bash
    forge script script/Main.s.sol:Main --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ```

2. Set NFT beacon contract for workflow contracts using the admin account by calling `setNFTContractBeacon` with the following command:

    ```bash
    cast send $SPG_PROXY_ADDR "setNftContractBeacon(address)" $SPGNFT_BEACON_ADDR --rpc-url=$TESTNET_URL --private-key=$ADMIN_PRIVATEKEY --legacy --gas-limit=1000000
    ```


## Workflow Contract Upgrade

1. Run the [upgrade script](https://github.com/storyprotocol/protocol-periphery-v1/blob/main/script/UpgradeSPG.s.sol) with the following command:

    ```bash
    forge script script/UpgradeSPG.s.sol:UpgradeSPG --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ```

2. Update the proxy contract to point to the newest implementation by calling `upgradeToAndCall` with the following command:

    ```bash
    cast send $SPG_PROXY_ADDR "upgradeToAndCall(address,bytes)" $NEW_SPG_IMPL_ADDR "0x" --rpc-url=$TESTNET_URL --private-key=$ADMIN_PRIVATEKEY --legacy --gas-limit=1000000
    ```

## SPGNFT Upgrade

1. Run the [SPGNFT upgrade script](https://github.com/storyprotocol/protocol-periphery-v1/blob/main/script/UpgradeSPGNFT.s.sol) with the following command:

    ```bash
    forge script script/UpgradeSPGNFT.s.sol:UpgradeSPGNFT --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy --verify  --verifier=$VERIFIER_NAME --verifier-url=$VERIFIER_URL
    ```

2. Update the SPG proxy contract to point to the newest SPGNFT implementation by calling `upgradeCollections` function with the following command:

    ```bash
    cast send $SPG_PROXY_ADDR "upgradeCollections(address)" $NEW_SPGNFT_IMPL_ADDR --rpc-url=$TESTNET_URL --private-key=$ADMIN_PRIVATEKEY --legacy --gas-limit=1000000
    ```
