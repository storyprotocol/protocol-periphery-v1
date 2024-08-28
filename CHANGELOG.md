# CHANGELOG

## v1.1.0
- Migrate periphery contracts from protocol core repo (#1)
- Revamped SPG with NFT collection and mint token logic. (#5, #6)
- Added support for batch transactions via `multicall` (#38)
- Added functionality for registering IP with metadata and supporting metadata for SPG NFT. (#8, #20, #37)
- Addressed ownership transfer issues in deployment script. (#18, #39)
- Fixed issues with derivative registration, including minting fees for commercial licenses, license token flow, and making register and attach PIL terms idempotent. (#23, #25, #30)
- Added SPG & SPG NFT upgrade scripts (#10)
- Added IP Graph, Solady's ERC6551 integration, and core protocol package bumps. (#30)
- Enhance CI/CD, repo, and misc.(#2, #3, #11, #32)

**Full Changelog**: [v1.1.0](https://github.com/storyprotocol/protocol-periphery-v1/commits/v1.1.0)

## v1.0.0-beta-rc1

This is the first release of the Story Protocol Gateway

- Adds the SPG, a convenient wrapper around the core contracts for registration
- Includes NFT minting management tooling for registering and minting in one-shot

