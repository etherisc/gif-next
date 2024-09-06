# GIF-Next (Generic Insurance Framework, next version)


## Add OpenZeppelin V5 Dependencies

```shell
forge install openzeppelin-contracts-500=OpenZeppelin/openzeppelin-contracts@v5.0.0
cd cd lib/openzeppelin-contracts-500
git checkout tags/v5.0.0
cd ../..
```

See `remappings.txt` to see how to work with different OpenZeppelin versions in parallel

```
cat remappings.txt 
@openzeppelin5/contracts/=lib/openzeppelin-contracts-500/contracts/
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/
```


## Submodules checkout

This repository uses submodules. To checkout or update to the latest submodules, run the following command after updating to any revision (or checking out the repository)

```shell
git submodule update --recursive
```

## Example components

A (very early) example of a product and a pool can be found in the [gif-next-sandbox repository](https://github.com/etherisc/gif-next-sandbox). 

## Hardhat 

### NPM Commands

```shell
npm run build

npm run test
npm run ptest
npm run test-with-gas
npm run coverage
```

### Docgen

Produce `solidty-docgen` documentation using the command below.

```shell
hh docgen
```

The resulting markdown files are written to `docs`


### Full protocol deployment 

Install the dependencies before running the script below for the first time.

```bash
npm install
```

The deploy script will deploy all required contracts for gif and create a test instance. 

```bash
# run deployment on a locally created ganache instance
hh run scripts/deploy_gif.ts
```

```bash
# set appropriate values vor env variables (see below)

# run deployment on another network
hh run --network <networkname> scripts/deploy_gif.ts
```

The deployment will persist deployment information into the files `deployments/<chainid>/deployment_state.json`, `deployments/<chainid>/libraries.json` and `deployments/<chainid>/verification_log.json`. 
This data can then be used for verification of the deployed contracts on etherscan/polygonscan.

For the verification of the contracts on etherscan/polygonscan the above files (created by previous deployment) are required and then the following command can be used:

```bash
hh run --network <networkname> scripts/verify_deployment.ts 
```

Environment variables:

- `WRITE_ADDRESSES_TO_FILE` set to `true` to write the addresses of the deployed contracts to a file (default: `false`)
- `RESUMEABLE_DEPLOYMENT` set to `true` to have all (deployment) transactions written to a state file so the script can be resumed after a failure (or after a manual stop) (default: `false`)
- `GAS_PRICE` set to the gas price to use for deployment (default: `undefined`)
- `WALLET_MNEMONIC` the mnemonic of the wallet to use for deployment (required for mumbai and mainnet)

- `WEB3_INFURA_PROJECT_ID` set to infura project id (required for mumbai and mainnet)
- `ETHERSCAN_API_KEY` `POLYGONSCAN_API_KEY` the api key for etherscan/polygonscan (required for mumbai and mainnet)

### Deploy full protocol with fire example components

```bash
hh run scripts/deploy_all.ts
```

Like before, use the `--network` option to deploy on a different network.

### Deploy only the fire example components

```bash
hh run scripts/deploy_fire_components.ts
```

Ensure that the deployment runs on a chain where a compatible version of the GIF is already deployed. Then ensure the correct environment variables are set. An up to date list of required environment variables can be found in the `deploy_fire_components.ts` script in the main method (just check the lines that contain a `process.env` statement). To be safe, set the environment variable `WRITE_ADDRESSES_TO_FILE` to `true` when deploying the gif and then copy all values from the generated `deployment.env` file to the `.env` file in the root directory of the repository before running the fire example deployment. 

Like before, use the `--network` option to deploy on a different network.

### Create a new instance

Requires previous step to be completed. 

```bash
# set appropriate values vor env variables (see below)

hh run --network <networkname> scripts/new_instance.ts
```

Currently an HD wallet is expected to be used for the deployment. The mnemonic of the wallet needs to be provided via the `WALLET_MNEMONIC` environment variable. 
The instance owner will be the 11th address of the wallet.

Environment variables:

- `WEB3_INFURA_PROJECT_ID` set to infura project id (required for mumbai and mainnet)
- `WALLET_MNEMONIC` the mnemonic of the wallet to use for deployment (required for mumbai and mainnet)
- `REGISTRY_ADDRESS` the address of the registry that is already deployed and configured and has a valid master instance

### Console

```
hh console --network <networkname>

me = hre.ethers.Wallet.fromPhrase('...')
provider = hre.ethers.provider
await provider.getBalance(me)
```


### Documentation

https://hardhat.org/hardhat-runner/docs/guides/compile-contracts

### Scripts to find syntax bugs in code

#### find methods missing the `restricted` modifier

```bash
hh run scripts/find_unrestricted_methods.ts
```

Checks all public/external methods in services and components for methods that are missing the `restricted` modifier but should have one.

The script `find_unrestricted_methods.ts` is based on the ANTLR grammar `Solidity.g4` (from https://github.com/solidity-parser/antlr) and uses the antlr4ng runtime (https://github.com/mike-lischke/antlr4ng).
To compile grammar to ts classes run `antlr4ng -Dlanguage=TypeScript -o antlr/generated/ -visitor -listener  antlr/Solidity.g4` (requires openjdk to be installed `sudo apt install openjdk-17-jre-headless`).

#### find methods missing the `virtual` keyword

```bash
hh run scripts/find_missing_virtual_methods.ts.ts
```

Checks all public/external methods in services and components for methods that are not marked as `virtual` but should be.

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

# provide code coverage report
forge coverage
forge coverage --report lcov 
```

### Aliases 


| Alias | Command |
| --- | --- |
| fb | forge build |
| fbw | forge build --watch |
| fbc | forge build contracts/ |
| fbcw | forge build --watch contracts/ |
| ft | forge test |
| ftf | forge test --nmt "_longRunning" |
| ftt | forge test -vvvv --mt |
| fttg | forge test -vvvv --gas-report --mt |
| fttw | forge test -vvvv --watch --mt |
| ftc | forge test -vvvv --mc |
| ftcw | forge test -vvvv --watch --mc |
| fcf | forge coverage --nmt "_longRunning" |
| fcfr | forge coverage --nmt "_longRunning" --report lcov |

**Important**: All profiles are run using the foundry `ci` profile which disables the optimizer (for speed).

### Chisel session

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

Please see https://docs.etherisc.com/gif-next/3.x/ for style guide and general coding rules. 

### Automatic code formatting

We use prettier and the solidity plugin to format the code automatically. 
The plugin is configured to use the style guide mentioned above.
To execute format checks run `npm run styleCheck`.
To execute formatting run `npm run styleFix`.

### Linting 

We use solhint to lint the code.
To execute linting run `npm run lint`.


### Adding Brownie (Legacy - don't do that :wink: )

python3 is already installed

```bash
npm install -g ganache
sudo apt update
sudo apt install python3-pip
pip install eth-brownie
brownie pm install OpenZeppelin/openzeppelin-contracts@4.9.3
brownie pm install OpenZeppelin/openzeppelin-contracts@5.0.0
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

## Objects

### Registry

Mandatory properties

* One registry per chain
* Global registry: the registry on mainnet
* One entry per protocol object
* Once registered object properties are immutable
* Globally unique NFT minted per protocol object (chain id is embedded in NFT id)
* Object ownership defined by NFT ownernship
* Typed objects (instance, product, policy, ...)
* Each object has parent object (only one exception: protocol object does not have parent object)
* Parent object type is defined by type of child object

Object properties (for smart contracts)
* Objects that represent a smart contract record its contract address
* With one exception (see next point) smart contract addresses refer to the address on the same chain as the registry
* The global registry also holds entries for all the registries on different chains than mainnet, in these cases the addresses refer to the chains of these chain specific registries (this is the only case where registered addresses do not refer to the same chain)

Optional properties

* Objects can have names
* Object names are unique per chain
* Objects may define an intercepting property, in which case a predefined smart contract is involved in NFT transfers of the objects NFT (transfer may trigger actions, transfer may be blocked etc)
* 

Ownership property

* Object ownership defined by ownership of NFT representing the object
* Protocol
  * Fixed/predefined owner (address without private key)
* Registry
  * Allows registration of token and services (per major release)
  * May transfer ownership
* Token
  * Fixed/predefined owner (address without private key)
  * TODO add whitelisting for token per major release
* Service
  * Allows upgrades of services as long as major version is same
  * Until further notice the same entity as the registry owner
  * May transfer ownership
* Instance
  * Granting/revoking of roles (both default + custom)
  * Management of custom roles and targets
  * May lock instance and/or components
  * May transfer ownership
* Component (Product, Pool, Distribution, Oracle)
  * Register component
  * Set component wallet (which receives fees, holds funds)
  * May lock component
  * May transfer ownership
  * Additional use case specific features
* Policy
  * Represents policy holder
  * Receive payouts (GIF default behaviour)
  * May transfer ownership
* Bundle
  * Represents funds owner
  * May withdraw funds not locked by active policies
  * May transfer ownership
* Distributor
  * Receives commissions from sales (GIF default behaviour)
  * May transfer ownership

Intercepting property
  * Service owner is indirectly owner of service manager contract

* Instance
  * intercepts transfer of instance owner (new owner needs access manager admin rights for custom roles and targets)
  * intercepts transfer of components, to do what? check that new owner has necessary roles?
* Product
  * intercepts transfer of policies (use case specific: eg. limit/disallow transfers)
* Pool:
  * intercepts transfer of bundles (use case specific: eg. limit/disallow transfers)
* Distribution
  * intercepts transfer of distributors (bookkeeping: only one distributor per address allowed)
* Oracle
  * likely meaningless


### Instance

### Product

### Pool

### Distribution

### Oracle

## Registry and Services

### Principles

- 1 service per object type and major version
- registry service guards write access to registry
- all other objects registered via registry service
- root object for the complete tree is the protocol object
- under the root object a single registry object is registered (= global registry/ethereum mainnet)


### Service Responsibilities

Registry Service

- deployed and registered during bootstrapping of registry
- used to register tokens and other services by registry owner
- an object may only be registered by the service designated by the type of the object
- to register an object the parent object needs already be registered
- the type of the object to be registered needs to match a valid child type/parent type combination

Instance Service

- deploys master instance during its own bootstrapping (if allowed by contract size)
- registered via registry service by registry owner
- registeres master instance during its own registration by regsitry owner
- deploys and registeres new instances (= instance factory) by instance owner (instance owner is a permissionless role, anybody may creates a new instance)
- provides upgrade functionality to instance owners

Product Service

- registered via registry service by registry owner
- registers products for registered instances via registry service by product owner (product owner role is permissend by the product's instance)
- registers applications/policies for registered products via registry service

Distribution Service

- registered via registry service by registry owner
- registers distribution components for registered products via registry service by distribution owner (distribution owner role is permissend by the product's instance)
- registers distributors for registered distribution components via registry service

## Contract Organisation

now 

contracts
  components
  instance
  registry
  shared
  types


contracts
  component
    pool
      Pool.sol
      PoolService.sol
    oracle
    distribution
    product
      Product.sol
      ProductService.sol
    Component.sol
    ComponentService.sol
  instance
    Instance.sol
    InstanceAdmin.sol
    InstanceReader.sol
    InstanceService.sol
    InstanceServiceManager.sol
  registry
    ChainNft.sol
    Registry.sol
    RegistryAdmin.sol
    RegistryService.sol
    RegistryServiceManager.sol
  shared
    Registerable.sol
    RegisterableUpgradable.sol
  type
    NftId.sol
    ObjectType.sol

## Storage layout

### Analysis tool

Command line call

```bash
hh run scripts/analyze_storage_layout.ts
```

Analyses contract `MockStorageLayout.sol` and writes the storage layout to `storage_layout.json` and `storage_layout.csv`.
New structs must be added to `MockStorageLayout` to be included in analysis. 

Storage layout details:
- Items fill up the current slot if possible
- If not enough space is left in the current slot, the item is placed in the next slot
- Stucts and arrays always start a new slot
- Items following a struct or array always start a new slot

More at https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html

### Custom types sizes

| Type | Size |
| --- | --- |
| Amount | 12 bytes |
| Blocknumber | 4 bytes |
| ClaimId | 2 bytes |
| DistributorType | 8 bytes |
| NftId | 12 bytes |
| ObjectType | 1 byte |
| ReferralId | 8 bytes |
| RoleId | 1 byte |
| RiskId | 8 bytes |
| Seconds | 5 bytes |
| Selector | 4 bytes |
| StateId | 1 byte |
| Str | 32 bytes |
| Timestamp | 5 bytes |
| Version | 3 byte |
| VersionPart | 1 byte |
| UFixed | 20 bytes |
| address | 20 bytes |
| uint256 | 32 bytes |
| uint128 | 16 bytes |
| uint160 | 20 bytes |
| uint64 | 8 bytes |
| uint32 | 4 bytes |
| uint16  | 2 bytes  |
| string  | 32 bytes |
| bytes   | 32 bytes |
| bytes8  | 8 byte  |
| bool    | 1 byte  |
