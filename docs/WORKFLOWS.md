# PoC Periphery Supported Workflows

> 📚 For full contract interfaces, check out [`contracts/interfaces/workflows`](../contracts/interfaces/workflows/).

### [Registration Workflows](../contracts/interfaces/workflows/IRegistrationWorkflows.sol)

- `createCollection`:
  - Creates a SPGNFT Collection
- `registerIp`:
  - Registers an IP
- `mintAndRegisterIp`:
  - Mints a NFT → Registers it as an IP

### [License Attachment Workflows](../contracts/interfaces/workflows/ILicenseAttachmentWorkflows.sol)

- `registerPILTermsAndAttach`:
  - Registers multiple PIL terms → Attaches them to an IP → Sets the licensing configuration for each of the attached PIL terms
- `registerIpAndAttachPILTerms`:
  - Registers an IP → Registers multiple PIL terms → Attaches them to the IP → Sets the licensing configuration for each of the attached PIL terms
- `mintAndRegisterIpAndAttachPILTerms`:
  - Mints a NFT → Registers it as an IP → Registers multiple PIL terms → Attaches them to the IP → Sets the licensing configuration for each of the attached PIL terms
- `mintAndRegisterIpAndAttachDefaultTerms`:
  - Mints a NFT → Registers it as an IP → Attaches default license terms to the IP
- `registerIpAndAttachDefaultTerms`:
  - Registers an IP → Attaches default license terms to the IP

### [Derivative Workflows](../contracts/interfaces/workflows/IDerivativeWorkflows.sol)

- `registerIpAndMakeDerivative`:
  - Registers an IP → Registers it as a derivative of another IP
- `mintAndRegisterIpAndMakeDerivative`:
  - Mints a NFT → Registers it as an IP → Registers the IP as a derivative of another IP
- `registerIpAndMakeDerivativeWithLicenseTokens`:
  - Registers an IP → Registers the IP as a derivative of another IP using the license tokens
- `mintAndRegisterIpAndMakeDerivativeWithLicenseTokens`:
  - Mints a NFT → Registers it as an IP → Registers the IP as a derivative of another IP using the license tokens

### [Grouping Workflows](../contracts/interfaces/workflows/IGroupingWorkflows.sol)

- `mintAndRegisterIpAndAttachLicenseAndAddToGroup`:
  - Mints a NFT → Registers it as an IP → Attaches the given license terms to the IP → Adds the IP to a group IP
- `registerIpAndAttachLicenseAndAddToGroup`:
  - Registers an IP → Attaches the given license terms to the IP → Sets the licensing configuration for the attached license terms → Adds the IP to a group IP
- `registerGroupAndAttachLicense`:
  - Registers a group IP → Attaches the given license terms to the group IP → Sets the licensing configuration for the attached license terms
- `registerGroupAndAttachLicenseAndAddIps`:
  - Registers a group IP → Attaches the given license terms to the group IP → Sets the licensing configuration for the attached license terms → Adds existing IPs to the group IP
- `collectRoyaltiesAndClaimReward`:
  - Collects revenue tokens to the group's reward pool → Distributes the rewards to each given member IP's royalty vault

### [Royalty Workflows](../contracts/interfaces/workflows/IRoyaltyWorkflows.sol)

- `claimAllRevenue`:
  - Transfers all available royalties from various royalty policies to the royalty vault of the ancestor IP -> Claims all the revenue in each currency token from the ancestor IP's royalty vault to the claimer.

### [Royalty Token Distribution Workflows](../contracts/interfaces/workflows/IRoyaltyTokenDistributionWorkflows.sol)

- `mintAndRegisterIpAndAttachPILTermsAndDistributeRoyaltyTokens`:
  - Mints a NFT → Registers it as an IP → Attaches PIL terms to the IP → Sets the licensing configuration for the attached PIL terms → Distributes specified amounts of royalty tokens to recipients

- `mintAndRegisterIpAndMakeDerivativeAndDistributeRoyaltyTokens`:
  - Mints a NFT → Registers it as an IP → Registers the IP as a derivative of another IP → Triggers the deployment of the IP's royalty vault → Distributes specified amounts of royalty tokens to recipients

- `registerIpAndAttachPILTermsAndDeployRoyaltyVault`:
  - Registers an IP → Attaches PIL terms to the IP → Sets the licensing configuration for the attached PIL terms → Triggers the deployment of the IP's royalty vault

- `registerIpAndMakeDerivativeAndDeployRoyaltyVault`:
  - Registers an IP → Registers the IP as a derivative of another IP → Triggers the deployment of the IP's royalty vault

- `distributeRoyaltyTokens`:
  - Distributes specified amounts of royalty tokens to recipients
