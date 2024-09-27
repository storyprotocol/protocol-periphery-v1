## PoC Periphery Integration Tests

Integration tests for the periphery v1 contracts. These tests are designed to be run against an actual deployment of the periphery v1 contracts and will send real transactions to the blockchain.

#### To run the tests:

- Have the following environment variables set in your `.env` file:
  - `RPC_URL`
  - `TEST_SENDER_ADDRESS`
  - `TEST_SENDER_SECRETKEY`

- Then run the following command:

```bash
forge script test/integration/workflows/[IntegrationTestFileName].t.sol:[IntegrationTestContractName] --rpc-url=$RPC_URL -vvvv --broadcast --priority-gas-price=1 --legacy
```
