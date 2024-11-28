# Story Proof-of-Creativity Periphery

[![Version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fstoryprotocol%2Fprotocol-periphery-v1%2Fmain%2Fpackage.json&query=%24.version&label=latest%20version)](https://github.com/storyprotocol/protocol-periphery-v1/releases)
[![Documentation](https://img.shields.io/badge/docs-v1-006B54)](https://docs.story.foundation/docs/what-is-story)
[![Website](https://img.shields.io/badge/website-story-00A170)](https://story.foundation)
[![Discord](https://img.shields.io/badge/discord-join%20chat-5B5EA6)](https://discord.gg/storyprotocol)
[![Twitter Follow](https://img.shields.io/twitter/follow/storyprotocol?style=social)](https://twitter.com/storyprotocol)


Welcome to the Story PoC Periphery repository. This repository contains the peripheral smart contracts for the Story Proof-of-Creativity (PoC) Protocol. These contracts simplify developers’ work by allowing them to bundle multiple interactions with the PoC protocol - like registering an IP Asset and attaching License Terms to that IP Asset - into a single transaction.

For access to the core PoC contracts, please visit the [protocol-core-v1](https://github.com/storyprotocol/protocol-core-v1) repository.

> 🚧 WARNING, Beta version: This code is in active development and unaudited. Do not use in production.

## Documentation

>📘 **[Learn more about Story](https://docs.storyprotocol.xyz/)**

Story PoC Periphery combines multiple common independent interactions with the Story PoC Protocol into a single transaction.
For example, this `mintAndRegisterIpAndAttachPILTerms` is one of the functions that allows you to mint an NFT, register it as an IP Asset, and attach License Terms to it all in one call.
```solidity
function mintAndRegisterIpAndAttachPILTerms(
  address nftContract,
  address recipient,
  IPMetadata calldata ipMetadata,
  PILTerms calldata terms
) external onlyCallerWithMinterRole(nftContract) returns (address ipId, uint256 tokenId, uint256 licenseTermsId)
```

### Supported Workflows
For a list of currently supported workflows, check out the [Workflows documentation](/docs/WORKFLOWS.md).

### Batching Calls
Batch calling functions is supported both natively and through the `Multicall3` contract. For more information, check out the [Multicall documentation](/docs/MULTICALL.md).

### Deployed Contracts

[![Version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fstoryprotocol%2Fprotocol-periphery-v1%2Fmain%2Fpackage.json&query=%24.version&label=PoC%20Periphery)](https://github.com/storyprotocol/protocol-periphery-v1/releases) contracts are deployed on Story Testnet at the following addresses:

```json
{
  "DerivativeWorkflows": "0xE0e1d222E024bF14B1e0A4b48fC6e6B6F8ebaEB3",
  "GroupingWorkflows": "0xfAa9CCd49DCDfB9a950CBF036cD6082e623a6bcC",
  "LicenseAttachmentWorkflows": "0xC7A40c41Cbe44C6B326447081877d69F98127C59",
  "RegistrationWorkflows": "0x8D8E0d24E7B6420d3209EfA185Fa451c95D8316A",
  "RoyaltyWorkflows": "0x19E435b1C0857375F9423C8ba508203054CE1d9F",
  "SPGNFTBeacon": "0xD753c698aE69194C851d60BF759d537DE7477696",
  "SPGNFTImpl": "0xA12e66a4429c9B7f38893c9b00E80646e0e76446"
}
```

## Quick Start

### Prerequisites

Please install [Foundry / Foundryup](https://github.com/gakonst/foundry)

### Install dependencies

```sh
yarn # this installs packages
forge build # this builds
```

### Verify upgrade storage layout (before scripts or tests)

```sh
forge clean
forge compile --build-info
```

### Helper script to write an upgradeable contract with ERC7201

1. Edit `script/foundry/utils/upgrades/ERC7201Helper.s.sol`
2. Change `string constant CONTRACT_NAME = "<the contract name>";`
3. Run the script to generate boilerplate code for storage handling and the namespace hash:

```sh
forge script script/utils/upgrades/ERC7201Helper.s.sol
```

4. The log output is the boilerplate code, copy and paste in your contract

### Testing

```
forge test -vvvv
```

### Coverage

```
forge coverage
```

### Deploying & Upgrading
See [Deploy & Upgrade documentation](./docs/DEPLOY_UPGRADE.md) for more information.

### Working with a local network

Foundry comes with local network [anvil](https://book.getfoundry.sh/anvil/index.html) baked in, and allows us to deploy to our local network for quick testing locally.

To start a local network run:

```
make anvil
```

This will spin up a local blockchain with a determined private key, so you can use the same private key each time.

### Code Style

We employed solhint to check code style.
To check code style with solhint run:

```
make lint
```

To re-format code with prettier run:

```
make format
```

### Security

We use slither, a popular security framework from [Trail of Bits](https://www.trailofbits.com/). To use slither, you'll first need to [install python](https://www.python.org/downloads/) and [install slither](https://github.com/crytic/slither#how-to-install).

Then, you can run:

```
make slither
```

And get your slither output.


## Contributing

Please see our [contribution guidelines](CONTRIBUTING.md).

## Licensing

MIT License, details see: [LICENSE](LICENSE).
