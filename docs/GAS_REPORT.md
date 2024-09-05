# Gas Report

## contracts/SPGNFT.sol: SPGNFT Contract

- **Deployment Cost:** 2,894,596
- **Deployment Size:** 13,662

| Function Name         | min   | avg    | median | max    | # calls |
|-----------------------|-------|--------|--------|--------|---------|
| balanceOf             | 661   | 661    | 661    | 661    | 3       |
| hasRole               | 685   | 1,362  | 685    | 2,685  | 59      |
| initialize            | 24,382| 246,111| 257,781| 257,781| 40      |
| mint                  | 17,523| 78,377 | 90,048 | 124,248| 11      |
| mintByPeriphery       | 75,260| 90,808 | 75,260 | 122,060| 46      |
| mintFee               | 372   | 793    | 372    | 2,372  | 19      |
| mintFeeRecipient      | 419   | 419    | 419    | 419    | 12      |
| mintFeeToken          | 396   | 396    | 396    | 396    | 14      |
| mintOpen              | 350   | 350    | 350    | 350    | 12      |
| name                  | 1,319 | 2,100  | 1,319  | 3,319  | 64      |
| ownerOf               | 575   | 658    | 575    | 2,575  | 215     |
| publicMinting         | 415   | 415    | 415    | 415    | 12      |
| safeTransferFrom      | 6,847 | 13,879 | 6,847  | 31,247 | 46      |
| setMintFee            | 2,709 | 6,411  | 7,646  | 7,646  | 4       |
| setMintFeeRecipient   | 5,556 | 5,556  | 5,556  | 5,556  | 1       |
| setMintFeeToken       | 7,734 | 7,734  | 7,734  | 7,734  | 2       |
| supportsInterface     | 664   | 696    | 709    | 709    | 306     |
| symbol                | 1,336 | 1,489  | 1,336  | 3,336  | 13      |
| tokenURI              | 1,582 | 1,926  | 1,825  | 3,582  | 132     |
| totalSupply           | 377   | 502    | 377    | 2,377  | 16      |
| withdrawToken         | 36,204| 36,204 | 36,204 | 36,204 | 1       |

---

## contracts/StoryProtocolGateway.sol: StoryProtocolGateway Contract

- **Deployment Cost:** 4,867,776
- **Deployment Size:** 23,722

| Function Name                          | min      | avg      | median   | max      | # calls |
|----------------------------------------|----------|----------|----------|----------|---------|
| createCollection                       | 386,899  | 393,709  | 395,899  | 395,899  | 37      |
| initialize                             | 48,100   | 48,100   | 48,100   | 48,100   | 28      |
| mintAndRegisterIp                      | 14,193   | 415,363  | 424,264  | 563,364  | 14      |
| mintAndRegisterIpAndAttachPILTerms     | 584,438  | 729,643  | 673,293  | 957,102  | 19      |
| mintAndRegisterIpAndMakeDerivative     | 814,704  | 990,235  | 814,704  | 2,523,346| 12      |
| mintAndRegisterIpAndMakeDerivativeWithLicenseTokens | 1,084,222 | 1,084,222 | 1,084,222 | 1,084,222 | 1 |
| multicall                              | 3,909,385| 5,724,968| 5,302,954| 8,384,581| 4       |
| onERC721Received                       | 1,013    | 1,013    | 1,013    | 1,013    | 2       |
| registerIp                             | 459,304  | 459,304  | 459,304  | 459,304  | 1       |

---

## @story-protocol/protocol-core/contracts/registries/IPAssetRegistry.sol: IPAssetRegistry Contract

- **Deployment Cost:** 3,417,918
- **Deployment Size:** 16,312

| Function Name          | min      | avg      | median   | max      | # calls |
|------------------------|----------|----------|----------|----------|---------|
| addGroupMember         | 95,931   | 271,493  | 95,931   | 622,617  | 3       |
| containsIp             | 816      | 816      | 816      | 816      | 12      |
| initialize             | 51,299   | 51,299   | 51,299   | 51,299   | 28      |
| isRegistered           | 9,481    | 9,481    | 9,481    | 9,481    | 33      |
| register               | 173,779  | 187,580  | 178,679  | 209,512  | 52      |

---

## @story-protocol/protocol-core/contracts/modules/licensing/LicensingModule.sol: LicensingModule Contract

- **Deployment Cost:** 3,997,567
- **Deployment Size:** 19,498

| Function Name               | min     | avg     | median  | max     | # calls |
|-----------------------------|---------|---------|---------|---------|---------|
| attachLicenseTerms          | 143,353 | 159,697 | 154,853 | 203,856 | 26      |
| initialize                  | 73,816  | 73,816  | 73,816  | 73,816  | 28      |
| mintLicenseTokens           | 417,585 | 417,585 | 417,585 | 417,585 | 2       |
| name                        | 627     | 627     | 627     | 627     | 28      |
| registerDerivative          | 382,994 | 614,955 | 382,994 | 1,890,474| 14      |
| supportsInterface           | 399     | 410     | 416     | 416     | 84      |

---

## @story-protocol/protocol-core/contracts/modules/royalty/RoyaltyModule.sol: RoyaltyModule Contract

- **Deployment Cost:** 4,428,899
- **Deployment Size:** 21,149

| Function Name               | min     | avg     | median  | max     | # calls |
|-----------------------------|---------|---------|---------|---------|---------|
| initialize                  | 140,277 | 140,277 | 140,277 | 140,277 | 28      |
| isWhitelistedRoyaltyPolicy   | 2,621   | 2,621   | 2,621   | 2,621   | 2       |
| onLicenseMinting            | 460,604 | 460,604 | 460,604 | 460,604 | 2       |
| onLinkToParents             | 865,528 | 865,528 | 865,528 | 865,528 | 2       |
| payLicenseMintingFee        | 104,928 | 104,928 | 104,928 | 104,928 | 2       |
| supportsInterface           | 495     | 513     | 523     | 523     | 84      |

---

## @story-protocol/protocol-core/contracts/modules/dispute/DisputeModule.sol: DisputeModule Contract

- **Deployment Cost:** 3,712,854
- **Deployment Size:** 17,721

| Function Name               | min     | avg     | median  | max     | # calls |
|-----------------------------|---------|---------|---------|---------|---------|
| initialize                  | 74,008  | 74,008  | 74,008  | 74,008  | 28      |
| isIpTagged                  | 601     | 2,146   | 2,601   | 2,601   | 66      |
| name                        | 649     | 649     | 649     | 649     | 28      |
| supportsInterface           | 399     | 410     | 416     | 416     | 84      |

---

## @story-protocol/protocol-core/contracts/registries/LicenseRegistry.sol: LicenseRegistry Contract

- **Deployment Cost:** 3,918,405
- **Deployment Size:** 18,607

| Function Name                  | min     | avg     | median  | max     | # calls |
|--------------------------------|---------|---------|---------|---------|---------|
| attachLicenseTermsToIp         | 96,848  | 101,098 | 101,348 | 116,348 | 26      |
| getAttachedLicenseTerms        | 1,499   | 1,765   | 1,499   | 5,499   | 30      |
| initialize                     | 48,145  | 48,145  | 48,145  | 48,145  | 28      |
| registerDerivativeIp           | 307,485 | 325,759 | 307,485 | 350,485 | 16      |

---

## @story-protocol/protocol-core/contracts/LicenseToken.sol: LicenseToken Contract

- **Deployment Cost:** 4,280,293
- **Deployment Size:** 20,091

| Function Name               | min     | avg     | median  | max     | # calls |
|-----------------------------|---------|---------|---------|---------|---------|
| approve                     | 27,133  | 27,133  | 27,133  | 27,133  | 1       |
| mintLicenseTokens           | 216,500 | 216,500 | 216,500 | 216,500 | 2       |
| ownerOf                     | 2,664   | 2,664   | 2,664   | 2,664   | 2       |
| safeTransferFrom            | 68,703  | 70,202  | 70,202  | 71,702  | 2       |

---

## @story-protocol/protocol-core/contracts/modules/licensing/PILicenseTemplate.sol: PILicenseTemplate Contract

- **Deployment Cost:** 5,772,046
- **Deployment Size:** 27,312

| Function Name               | min     | avg     | median  | max     | # calls |
|-----------------------------|---------|---------|---------|---------|---------|
| exists                      | 503     | 1,717   | 2,503   | 2,503   | 56      |
| getLicenseTerms             | 26,662  | 26,662  | 26,662  | 26,662  | 3       |
| initialize                  | 183,255 | 183,255 | 183,255 | 183,255 | 28      |
| registerLicenseTerms        | 8,365   | 83,059  | 134,323 | 207,929 | 24      |

---

## @story-protocol/protocol-core/contracts/modules/royalty/policies/IpRoyaltyVault.sol: IpRoyaltyVault Contract

- **Deployment Cost:** 0
- **Deployment Size:** 0

| Function Name               | min     | avg     | median  | max     | # calls |
|-----------------------------|---------|---------|---------|---------|---------|
| addIpRoyaltyVaultTokens     | 71,993  | 71,993  | 71,993  | 71,993  | 2       |
| initialize                  | 168,834 | 168,834 | 168,834 | 168,834 | 4       |
| transfer                    | 8,517   | 18,467  | 18,467  | 28,417  | 4       |

---

## @story-protocol/protocol-core/contracts/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol: RoyaltyPolicyLAP Contract

- **Deployment Cost:** 3,319,416
- **Deployment Size:** 15,835

| Function Name               | min     | avg     | median  | max     | # calls |
|-----------------------------|---------|---------|---------|---------|---------|
| initialize                  | 73,794  | 73,794  | 73,794  | 73,794  | 28      |
| onLicenseMinting            | 50,480  | 50,480  | 50,480  | 50,480  | 2       |
| onLinkToParents             | 188,663 | 188,663 | 188,663 | 188,663 | 2       |

---

## @story-protocol/protocol-core/contracts/registries/ModuleRegistry.sol: ModuleRegistry Contract

- **Deployment Cost:** 2,259,151
- **Deployment Size:** 10,439

| Function Name               | min     | avg     | median  | max     | # calls |
|-----------------------------|---------|---------|---------|---------|---------|
| getModule                   | 3,171   | 3,171   | 3,171   | 3,171   | 28      |
| initialize                  | 70,603  | 70,603  | 70,603  | 70,603  | 28      |
| isRegistered                | 753     | 1,052   | 753     | 2,753   | 207     |
| registerModule              | 74,245  | 78,240  | 80,118  | 80,424  | 168     |

---

## test/mocks/MockERC20.sol: MockERC20 Contract

- **Deployment Cost:** 673,893
- **Deployment Size:** 3,158

| Function Name               | min     | avg     | median  | max     | # calls |
|-----------------------------|---------|---------|---------|---------|---------|
| approve                     | 46,334  | 46,343  | 46,346  | 46,346  | 29      |
| balanceOf                   | 561     | 894     | 561     | 2,561   | 18      |
| decimals                    | 244     | 244     | 244     | 244     | 104     |
| mint                        | 68,372  | 68,380  | 68,384  | 68,384  | 18      |

---

## test/mocks/MockERC721.sol: MockERC721 Contract

- **Deployment Cost:** 1,358,423
- **Deployment Size:** 6,615

| Function Name               | min     | avg     | median  | max     | # calls |
|-----------------------------|---------|---------|---------|---------|---------|
| mint                        | 93,504  | 93,504  | 93,504  | 93,504  | 1       |
| name                        | 3,282   | 3,282   | 3,282   | 3,282   | 1       |
| ownerOf                     | 552     | 885     | 552     | 2,552   | 6       |
| supportsInterface           | 422     | 447     | 456     | 456     | 6       |
| tokenURI                    | 945     | 945     | 945     | 945     | 2       |

---
