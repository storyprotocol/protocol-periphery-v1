# Supported Workflows

- `createCollection`: Creates a NFT Collection

### Final Step: Register an IP Asset

- `registerIp`: Registers an IP
- `mintAndRegisterIp`: Mints a NFT → Registers it as an IP

### Final Step: Attach Programmable IP License (PIL) terms to an IP Asset

- `registerPILTermsAndAttach`: Registers PIL terms → Attaches them to an IP
- `registerIpAndAttachPILTerms`: Registers an IP → Registers PIL terms → Attaches them to the IP
- `mintAndRegisterIpAndAttachPILTerms`: Mints a NFT → Registers it as an IP → Registers PIL terms → Attaches them to the IP.

### Final Step: Register Derivative IP Asset

- `registerIpAndMakeDerivative`: Registers an IP → Registers it as a derivative of another IP
- `mintAndRegisterIpAndMakeDerivative`: Mints a NFT → Registers it as an IP → Registers the IP as a derivative of another IP

- `registerIpAndMakeDerivativeWithLicenseTokens`: Registers an IP → Registers it as a derivative of another IP using the license tokens
- `mintAndRegisterIpAndMakeDerivativeWithLicenseTokens`: Mints a NFT → Registers it as an IP → Registers the IP as a derivative of another IP using the license tokens

### Final Step: Add IP(s) to a group IP Asset

- `mintAndRegisterIpAndAttachPILTermsAndAddToGroup`: Mints a NFT → Registers it as an IP → Attaches the given PIL terms to the IP → Adds the IP to a group IP
- `registerIpAndAttachPILTermsAndAddToGroup`: Registers an IP → Attaches the given PIL terms to the IP → Adds the IP to a group IP
- `registerGroupAndAttachPILTermsAndAddIps`: Registers a group IP → Registers PIL terms → Attaches the PIL terms to group IP → Adds existing IPs to the group IP


> 📚 For full contract interfaces, check out `contracts/interfaces`.
