# CHANGELOG
## v1.2.2
* Introduced `RoyaltyWorkflows` for IP Revenue Claiming

**Full Changelog**: [v1.2.1...v1.2.2](https://github.com/storyprotocol/protocol-periphery-v1/compare/v1.2.1...v1.2.2)

## v1.2.1

* Added support for public minting in SPG and SPGNFT
* Added support for setting and retrieving base URI for SPGNFT
* Made license attachment idempotent in SPG
* Integrated `predictMintingLicenseFee` from the licensing module for minting fee calculations
* Bumped protocol-core dependencies to v1.2.1 and other minor updates

**Full Changelog**: [v1.2.0...v1.2.1](https://github.com/storyprotocol/protocol-periphery-v1/compare/v1.2.0...v1.2.1)

## v1.2.0

- Introduced workflow contracts and Group IPA features, including deployment scripts for `GroupingWorkflows`,`DeployHelper`, and custom license templates support
- Added public minting fee recipient control and resolved inconsistent licensing issues
- Updated documentation and added a gas analysis report
- Bumped protocol-core dependencies to v1.2.0

**Full Changelog**: [v1.1.0...v1.2.0](<https://github.com/storyprotocol/protocol-periphery-v1/compare/v1.1.0...v1.2.0>)

## v1.1.0

- Migrate periphery contracts from protocol core repo
- Revamped SPG with NFT collection and mint token logic
- Added support for batch transactions via `multicall`
- Added functionality for registering IP with metadata and supporting metadata for SPG NFT
- Addressed ownership transfer issues in deployment script
- Fixed issues with derivative registration, including minting fees for commercial licenses, license token flow, and making register and attach PIL terms idempotent
- Added SPG & SPG NFT upgrade scripts
- Added IP Graph, Solady's ERC6551 integration, and core protocol package bumps
- Enhance CI/CD, repo, and misc.

**Full Changelog**: [v1.1.0](https://github.com/storyprotocol/protocol-periphery-v1/commits/v1.1.0)

## v1.0.0-beta-rc1

This is the first release of the Story Protocol Gateway

- Adds the SPG, a convenient wrapper around the core contracts for registration
- Includes NFT minting management tooling for registering and minting in one-shot

