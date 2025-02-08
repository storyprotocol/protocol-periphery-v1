# CHANGELOG

## v1.3.1

This release builds on v1.3.0 with **enhanced security, improved code efficiency, and expanded test coverage**, while ensuring **workflow contract backward compatibility** and improving **permission handling**.

- Ensured **workflow contracts maintain backward compatibility** ([#165](https://github.com/storyprotocol/protocol-periphery-v1/pull/165), [#166](https://github.com/storyprotocol/protocol-periphery-v1/pull/166))
- **Replaced permanent permission with transient permission** ([#176](https://github.com/storyprotocol/protocol-periphery-v1/pull/176))
- **Other security fixes** ([#175](https://github.com/storyprotocol/protocol-periphery-v1/pull/175)):
  - Ensured `msg.sender` matches `signer` in workflow contracts
  - Used `safeERC20` in `SPGNFT`
  - Added initializers for **future-proofing**
  - Made `nonReentrant` modifier **precede all other modifiers** in `TokenizerModule`
  - Allowed setting `TotalLicenseTokenLimit` to `0` (no limit) in licensing hook
  - Replaced `_mint` with `_safeMint` in `SPGNFT`
- **Refactored** `OrgStoryNFTFactory` contract to **reduce code redundancy** ([#156](https://github.com/storyprotocol/protocol-periphery-v1/pull/156))
- **Added new integration tests** and fixed existing ones ([#162](https://github.com/storyprotocol/protocol-periphery-v1/pull/162), [#177](https://github.com/storyprotocol/protocol-periphery-v1/pull/177))
- **Fixed typos and improved documentation/comments** ([#163](https://github.com/storyprotocol/protocol-periphery-v1/pull/163), [#164](https://github.com/storyprotocol/protocol-periphery-v1/pull/164), [#167](https://github.com/storyprotocol/protocol-periphery-v1/pull/167), [#168](https://github.com/storyprotocol/protocol-periphery-v1/pull/168), [#169](https://github.com/storyprotocol/protocol-periphery-v1/pull/169), [#173](https://github.com/storyprotocol/protocol-periphery-v1/pull/173))


**Full Changelog**: [v1.3.0...v1.3.1](https://github.com/storyprotocol/protocol-periphery-v1/compare/v1.3.0...v1.3.1)

## v1.3.0

- **Story NFT & Badge Enhancements**
  Introduced the initial Story NFT, enabled URI updates post-deployment, made `StoryBadgeNFT` upgradeable, added ERC-7572 metadata, refactored `OrgNFT` logic, and fixed a reentrancy vulnerability.

- **NFT Caching Features**
  Added caching functionality to `StoryBadgeNFT`, including auto-cache support, removal from cache, and corresponding state getters.

- **Licensing & Permission Handling**
  Added permission handling for license attachment, licensing hooks (limit tokens / lock operations), multi-license support, custom templates, license config during IP registration, `maxRevenueShare` alignment, and empty-license checks.

- **Royalty & Grouping**
  Added royalty claiming for group IPs, introduced `RoyaltyTokenDistributionWorkflows`, removed snapshots for simplification, deployed royalty vaults for member IPs, and aligned royalty logic with core updates.

- **Tokenizer Module**
  Introduced a Tokenizer module and an `OwnableERC20` contract implementation.

- **Derivative & Protocol Compatibility**
  Restored v1.2 compatibility for multiple workflows, enabled batch permissions for derivative registration, replaced permission setting with `executeWithSig`, and reverted direct function calls when needed.

- **Fixes & Chores**
  Updated tests and deployments, fixed integration tests, addressed licensing-token counting, refined deploy scripts (including CREATE3 usage), cleaned up storage variables, added missing documentation, and fixed typos.

**Full Changelog**: [v1.2.3...v1.3.0](https://github.com/storyprotocol/protocol-periphery-v1/compare/v1.2.3...v1.3.0)

## v1.2.4

* Introduced Story NFT with various enhancements:
  * Enabled URI changes post deployment
  * Added upgrade scripts
  * Resolved reentrancy vulnerability
* Implemented ERC-7572 contract-level metadata support
* Added permission handling in `registerPILTermsAndAttach`
* Added royalty claiming for group IPs

**Full Changelog**: [v1.2.3...v1.2.4](https://github.com/storyprotocol/protocol-periphery-v1/compare/v1.2.3...v1.2.4)

## v1.2.3

* Refactored SPG into "workflow" contracts and introduced `RoyaltyWorkflows` for IP Revenue Claiming
* Fixed and enhanced tests and upgrade scripts: changed mock IPGraph precompile address, added integration tests, improved test logs, and added missing `run` function calls.
* Optimized royalty and licensing: removed `currencyTokens` parameter, extracted batch claim functions, and removed `hasIpAttachedLicenseTerms` check
* Added `registerGroupAndAttachLicense` function for grouping
* repo enhancement and bumped solidity version to 0.8.26

**Full Changelog**: [v1.2.2...v1.2.3](https://github.com/storyprotocol/protocol-periphery-v1/compare/v1.2.2...v1.2.3)

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

