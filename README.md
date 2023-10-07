# gif-next (Generic Insurance Framework next version)

## Submodules checkout

This repository uses submodules. To checkout or update to the latest submodules, run the following command after updating to any revision (or checking out the repository)

```shell
git submodule update --recursive
```

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

The deploy script will deploy all required contracts and create a test instance with a test product and a test pool. 

```bash
# run deployment on a locally created ganache instance
hh run scripts/deploy_all.ts

# run deployment on another network
hh run --network <networkname> scripts/deploy_all.ts
```

Environment variables:

- `SKIP_VERIFICATION` set to `true` to skip etherscan verification (required for ganacht and anvil)
- `WEB3_INFURA_PROJECT_ID` set to infura project id (required for mumbai and mainnet)
- `WALLET_MNEMONIC` the mnemonic of the wallet to use for deployment (required for mumbai and mainnet)
- `ETHERSCAN_API_KEY` `POLYGONSCAN_API_KEY` the api key for etherscan/polygonscan (required for mumbai and mainnet)


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

# contract sizes
forge build --sizes | grep Instance

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
### Library Linking

https://ethereum.stackexchange.com/questions/153411/does-foundry-support-dynamical-library-linking-in-solidity

```toml
# foundry.toml

[profile.default]
  # expected format(example below): libraries = ["<path>:<lib name>:<address>"]
  libraries = ["src/libraries/MyLibrary.sol:MyLibrary:0x..."]
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


### Adding Brownie (Legacy)

python3 is already installed

```bash
npm install -g ganache
sudo apt update
sudo apt install python3-pip
pip install eth-brownie
brownie pm install OpenZeppelin/openzeppelin-contracts@4.9.3
```

```bash
brownie compile --all
brownie console
```

```python
registry_owner = accounts[0]
instance_owner = accounts[1]
product_owner = accounts[2]

# deploy libs and helper contracts
nft_id_lib = NftIdLib.deploy({'from': registry_owner})
ufixed_math_lib = UFixedMathLib.deploy({'from': registry_owner})
test_fee = TestFee.deploy({'from': registry_owner})

# deploy registry and a token
registry = Registry.deploy({'from': registry_owner})
nft = ChainNft.deploy(registry, {'from': registry_owner})
registry.initialize(nft,  {'from': registry_owner})
token = TestUsdc.deploy({'from': registry_owner})

# deploy services
component_owner_service = ComponentOwnerService.deploy(registry, {'from': registry_owner})
product_service = ProductService.deploy(registry, {'from': registry_owner})

# deploy an instance
instance = Instance.deploy(registry, component_owner_service, product_service, {'from': instance_owner})

# deploy product
pool = TestPool.deploy(registry, instance, token, {'from': product_owner})
policy_fee = test_fee.createFee(1, -1, 0)
product = TestProduct.deploy(registry, instance, token, pool, policy_fee, {'from': product_owner})

# grant roles
pool_owner_role = instance.getRoleForName("PoolOwner")
product_owner_role = instance.getRoleForName("ProductOwner")
instance.grantRole(pool_owner_role, product_owner, {'from': instance_owner})
instance.grantRole(product_owner_role, product_owner, {'from': instance_owner})

# register objects
instance.register()
component_owner_service.register(pool, {'from': product_owner})
component_owner_service.register(product, {'from': product_owner})

instance_id = instance.getNftId()
pool_id = pool.getNftId()
product_id = product.getNftId()
```

## migrate to kv store

sizes before
| Instance                       | 23.178    | 1.398       |
| TestInstanceBase               | 3.305     | 21.271      |
| TestInstanceModuleAccess       | 7.86      | 16.716      |
| TestInstanceModuleBundle       | 7.586     | 16.99       |
| TestInstanceModuleCompensation | 3.305     | 21.271      |
| TestInstanceModuleComponent    | 5.123     | 19.453      |
| TestInstanceModulePolicy       | 6.937     | 17.639      |
| TestInstanceModulePool         | 4.809     | 19.767      |
| TestInstanceModuleRisk         | 3.305     | 21.271      |
| TestInstanceModuleTreasury     | 7.563     | 17.013      |
---
sizes after