# Batch Periphery Function Calls
## Background
Prior to this point, registering multiple IPs or performing other operations such as minting, attaching licensing terms, and registering derivatives requires separate transactions for each operation. This can be inefficient and costly. To streamline the process, you can batch multiple transactions into a single one. Two solutions are now available for this:

1. **Batch workflow function calls:** Use [workflow contract's built-in `multicall` function](#1-batch-workflow-function-calls-via-built-in-multicall-function).
2. **Batch function calls beyond SPG:** Use the [Multicall3 Contract](#2-batch-function-calls-via-multicall3-contract).


## 1. Batch Workflow Function Calls via Built-in `multicall` Function

Workflow contracts include a `multicall` function that allows you to combine multiple read or write operations into a single transaction.

### Function Definition

The `multicall` function accepts an array of encoded call data and returns an array of encoded results corresponding to each function call:

```solidity
/// @dev Executes a batch of function calls on this contract.
function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results);
```

### Example Usage

Suppose you want to mint multiple NFTs, register them as IPs, and link them as derivatives to some parent IPs.

To accomplish this, you can use workflow contracts' `multicall` function to batch the calls to the `mintAndRegisterIpAndMakeDerivative` function.

Here’s how you might do it:

```solidity
// StoryProtocolGateway contract
contract SPG {
    ...
    function mintAndRegisterIpAndMakeDerivative(
        address nftContract,
        MakeDerivative calldata derivData,
        IPMetadata calldata ipMetadata,
        address recipient
    ) external returns (address ipId, uint256 tokenId) {
        ...
    }
    ...
}
```

To batch call `mintAndRegisterIpAndMakeDerivative` using the `multicall` function:

```typescript
// batch mint, register, and make derivatives for multiple IPs
await SPG.multicall([
    SPG.contract.methods.mintAndRegisterIpAndMakeDerivative(
      nftContract1,
      derivData1,
      recipient1,
      ipMetadata1,
    ).encodeABI(),

    SPG.contract.methods.mintAndRegisterIpAndMakeDerivative(
      nftContract2,
      derivData2,
      recipient2,
      ipMetadata2,
    ).encodeABI(),

    SPG.contract.methods.mintAndRegisterIpAndMakeDerivative(
      nftContract3,
      derivData3,
      recipient3,
      ipMetadata3,
    ).encodeABI(),
    ...
    // Add more calls as needed
]);
```

## 2. Batch Function Calls via Multicall3 Contract

> ⚠️ **Note:** The Multicall3 contract is not fully compatible with workflow functions that involve SPGNFT minting due to access control and context changes during Multicall execution. For such operations, use [workflow contracts' built-in `multicall` function](#1-batch-workflow-function-calls-via-built-in-multicall-function).

The Multicall3 contract allows you to execute multiple calls within a single transaction and aggregate the results.
The `viem` library provides native support for Multicall3.

### Story Iliad Testnet Multicall3 Deployment Info
(Same address across all EVM chains)
```json
{
    "contractName": "Multicall3",
    "chainId": 1513,
    "contractAddress": "0xcA11bde05977b3631167028862bE2a173976CA11",
    "url": "https://explorer.testnet.storyprotocol.net/address/0xcA11bde05977b3631167028862bE2a173976CA11?tab=contract"
}
```

### Main Functions

To batch multiple function calls, you can use the following functions:

1. **`aggregate3`**: Batches calls using the `Call3` struct.
2. **`aggregate3Value`**: Similar to `aggregate3`, but also allows attaching a value to each call.

```solidity
/// @notice Aggregate calls, ensuring each returns success if required.
/// @param calls An array of Call3 structs.
/// @return returnData An array of Result structs.
function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory returnData);

/// @notice Aggregate calls with an attached msg value.
/// @param calls An array of Call3Value structs.
/// @return returnData An array of Result structs.
function aggregate3Value(Call3Value[] calldata calls) external payable returns (Result[] memory returnData);
```

#### Struct Definitions

- **Call3**: Used in `aggregate3`.
- **Call3Value**: Used in `aggregate3Value`.

```solidity
struct Call3 {
    address target;      // Target contract to call.
    bool allowFailure;   // If false, the multicall will revert if this call fails.
    bytes callData;      // Data to call on the target contract.
}

struct Call3Value {
    address target;
    bool allowFailure;
    uint256 value;       // Value (in wei) to send with the call.
    bytes callData;      // Data to call on the target contract.
}
```

#### Return Type

- **Result**: Struct returned by both `aggregate3` and `aggregate3Value`.

```solidity
struct Result {
    bool success;        // Whether the function call succeeded.
    bytes returnData;    // Data returned from the function call.
}
```

For detailed examples in Solidity, TypeScript, and Python, see the [Multicall3 repository](https://github.com/mds1/multicall/tree/main/examples).

### Limitations

For a list of limitations when using Multicall3, refer to the [Multicall3 README](https://github.com/mds1/multicall/blob/main/README.md#batch-contract-writes).

### Additional Resources

- [Multicall3 Documentation](https://github.com/mds1/multicall/blob/main/README.md)
- [Multicall Documentation from Viem](https://viem.sh/docs/contract/multicall#multicall)

### Full Multicall3 Interface

```solidity
interface IMulticall3 {
    struct Call {
        address target;
        bytes callData;
    }

    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function aggregate(Call[] calldata calls) external payable returns (uint256 blockNumber, bytes[] memory returnData);

    function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory returnData);

    function aggregate3Value(Call3Value[] calldata calls) external payable returns (Result[] memory returnData);

    function blockAndAggregate(Call[] calldata calls) external payable returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData);

    function getBasefee() external view returns (uint256 basefee);

    function getBlockHash(uint256 blockNumber) external view returns (bytes32 blockHash);

    function getBlockNumber() external view returns (uint256 blockNumber);

    function getChainId() external view returns (uint256 chainid);

    function getCurrentBlockCoinbase() external view returns (address coinbase);

    function getCurrentBlockDifficulty() external view returns (uint256 difficulty);

    function getCurrentBlockGasLimit() external view returns (uint256 gaslimit);

    function getCurrentBlockTimestamp() external view returns (uint256 timestamp);

    function getEthBalance(address addr) external view returns (uint256 balance);

    function getLastBlockHash() external view returns (bytes32 blockHash);

    function tryAggregate(bool requireSuccess, Call[] calldata calls) external payable returns (Result[] memory returnData);

    function tryBlockAndAggregate(bool requireSuccess, Call[] calldata calls) external payable returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData);
}
```
