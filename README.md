# gif-next (Generic Insurance Framework next version)

## Hardhat 

### NPM Commands

```shell
npm run build

npm run test
npm run ptest
npm run test-with-gas
npm run coverage
```

### Deployment 

```
hh run --network <networkname> scripts/deploy.ts
```

Networks:
- hardhat (dynamically created network - https://hardhat.org/hardhat-network/docs/overview)
- anvil (anvsil chain running in container next when using devcontainer)
- mumbai (polygon testnet, requires WEB3_INFURA_PROJECT_ID)
- mainnet (polygon mainnet, requires WEB3_INFURA_PROJECT_ID)


### Console

```
hh console --network <networkname>

me = hre.ethers.Wallet.fromPhrase('...')
provider = hre.ethers.provider
await provider.getBalance(me)
```


### Documentation

https://hardhat.org/hardhat-runner/docs/guides/compile-contracts

## Forge 

### Commands

```shell
forge build

forge test

# run single test case
forge test --mt test_decimals

# run single test case with substantial logginglogging
# to include logs as well use -vvvvv
forge test -vvvv --mt test_decimals

# provide gas report for a single test
forge test --mt test_decimals --gas-report

forge coverage
```

Chisel session
```typescript
import "./contracts/components/Component.sol";
import "./contracts/components/IPool.sol";
import "./contracts/components/IProduct.sol";
import "./contracts/components/Pool.sol";
import "./contracts/components/Product.sol";
import "./contracts/instance/access/Access.sol";
import "./contracts/instance/access/IAccess.sol";
import "./contracts/instance/component/ComponentModule.sol";
import "./contracts/instance/component/IComponent.sol";
import "./contracts/instance/IInstance.sol";
import "./contracts/instance/policy/IPolicy.sol";
import "./contracts/instance/policy/PolicyModule.sol";
import "./contracts/instance/product/IProductService.sol";
import "./contracts/instance/product/ProductService.sol";
import "./contracts/registry/IRegistry.sol";

import {Instance} from "./contracts/instance/Instance.sol";
import {Registry} from "./contracts/registry/Registry.sol";
import {DeployAll} from "./scripts/DeployAll.s.sol";
import {TestPool} from "./test_forge/mock/TestPool.sol";
import {TestProduct} from "./test_forge/mock/TestProduct.sol";

string memory instanceOwnerName = "instanceOwner";
address instanceOwner = vm.addr(uint256(keccak256(abi.encodePacked(instanceOwnerName))));

string memory productOwnerName = "productOwner";
address productOwner = vm.addr(uint256(keccak256(abi.encodePacked(productOwnerName))));

string memory poolOwnerName = "poolOwner";
address poolOwner = vm.addr(uint256(keccak256(abi.encodePacked(poolOwnerName))));

string memory customerName = "customer";
address customer = vm.addr(uint256(keccak256(abi.encodePacked(customerName))));

DeployAll deployer = new DeployAll();
(
    Registry registry, 
    Instance instance, 
    TestProduct product,
    TestPool pool
) = deployer.run(
    instanceOwner,
    productOwner,
    poolOwner);

ProductService ps = ProductService(address(registry));

uint256 bundleNftId = 99;
uint256 sumInsuredAmount = 1000*10**6;
uint256 premiumAmount = 110*10**6;
uint256 lifetime =365*24*3600;
uint256 policyNftId = ps.createApplicationForBundle(customer, bundleNftId, sumInsuredAmount, premiumAmount, lifetime);

```


### Documentation

https://book.getfoundry.sh/reference/

## Style Guide

Solidity code is to be written according to the [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html).

Documentation of the code should be written inline using [NatSpec](https://docs.soliditylang.org/en/latest/natspec-format.html).

### Naming conventions

Additionally, we use the following naming conventions:

- Function arguments and return types: If using custom data types, make the name include the type by appending the Type to the argument name, e.g. `function getInfo(NftId bundleNftId)` instead of `function getInfo(NftId bundleId)`. Background: Custom data types are lost when using the ABI or Typescript binding classes (e.g. instead of `NftID` a `uint96` is used), so the type needs to be included in the name to make it clear what the argument is without having to look at the documentation or checking the solidity source code. 
- When naming a field or an attribute `id` and the context is not clear, call it `nftId` instead so its clear what type if id it is as there will be multiple ids for different kind of objects. Example: if you the function has a bundle nft id and a policy nft id as arguments, call them `bundleNftId` and `policyNftId` instead of `id` and `policyId`. In case of doubt, be a bit more verbose for the sake of clarity. 
- When naming things, remember that the code will likely be used in Javascript/Typescript as well, so avoid names that are reserved in Javascript/Typescript. A list of reserved words in Javascript can be found [here](https://www.w3schools.com/js/js_reserved.asp) and a list of reserved words in Typescript can be found [here](https://www.tektutorialshub.com/typescript/identifiers-keywords-in-typescript/). 

### Automatic code formatting

We use prettier and the solidity plugin to format the code automatically. 
The plugin is configured to use the style guide mentioned above.
To execute format checks run `npm run styleCheck`.
To execute formatting run `npm run styleFix`.

### Linting 

We use solhint to lint the code.
To execute linting run `npm run lint`.
