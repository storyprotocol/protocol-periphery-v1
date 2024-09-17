# PoC Periphery Supported Workflows

> 📚 For full contract interfaces, check out [`contracts/interfaces/workflows`](../contracts/interfaces/workflows/).

### [Registration Workflows](../contracts/interfaces/workflows/IRegistrationWorkflows.sol)

- `createCollection`: Creates a SPGNFT Collection
- `registerIp`: Registers an IP
- `mintAndRegisterIp`: Mints a NFT → Registers it as an IP

### [License Attachment Workflows](../contracts/interfaces/workflows/ILicenseAttachmentWorkflows.sol)

- `registerPILTermsAndAttach`: Registers PIL terms → Attaches them to an IP
- `registerIpAndAttachPILTerms`: Registers an IP → Registers PIL terms → Attaches them to the IP
- `mintAndRegisterIpAndAttachPILTerms`: Mints a NFT → Registers it as an IP → Registers PIL terms → Attaches them to the IP.

### [Derivative Workflows](../contracts/interfaces/workflows/IDerivativeWorkflows.sol)

- `registerIpAndMakeDerivative`: Registers an IP → Registers it as a derivative of another IP
- `mintAndRegisterIpAndMakeDerivative`: Mints a NFT → Registers it as an IP → Registers the IP as a derivative of another IP

- `registerIpAndMakeDerivativeWithLicenseTokens`: Registers an IP → Registers it as a derivative of another IP using the license tokens
- `mintAndRegisterIpAndMakeDerivativeWithLicenseTokens`: Mints a NFT → Registers it as an IP → Registers the IP as a derivative of another IP using the license tokens

### [Grouping Workflows](../contracts/interfaces/workflows/IGroupingWorkflows.sol)

- `mintAndRegisterIpAndAttachLicenseAndAddToGroup`: Mints a NFT → Registers it as an IP → Attaches the given license terms to the IP → Adds the IP to a group IP
- `registerIpAndAttachLicenseAndAddToGroup`: Registers an IP → Attaches the given license terms to the IP → Adds the IP to a group IP
- `registerGroupAndAttachLicenseAndAddIps`: Registers a group IP → Attaches the given license terms to the group IP → Adds existing IPs to the group IP
