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

The deploy script will deploy all required contracts and create a test instance with a test product and a test pool. 

```bash
# run deployment on a locally created ganache instance
export ENABLE_ETHERSCAN_VERIFICATION=false
export ENABLE_TENDERLY_VERIFICATION=false
hh run scripts/deploy_all.ts
```

```bash
# set appropriate values for env variables (see below)

# run deployment on another network
hh run --network <networkname> scripts/deploy_all.ts
```

Environment variables:

- `RESUMEABLE_DEPLOYMENT`set to `true` to skip deployment/verification of already deployed/verified contracts (based on ./deployment_state_<chainId>.json)
- `ENABLE_ETHERSCAN_VERIFICATION` set to `true` to skip etherscan verification (required for ganacht and anvil)
- `WEB3_INFURA_PROJECT_ID` set to infura project id (required for mumbai and mainnet)
- `WALLET_MNEMONIC` the mnemonic of the wallet to use for deployment (required for mumbai and mainnet)
- `ETHERSCAN_API_KEY` `POLYGONSCAN_API_KEY` the api key for etherscan/polygonscan (required for mumbai and mainnet)


#### Tenderly Testnet Deployment

if not already done:
*  install hardhat-tenderly
* install tenderly cli

```bash
npm install @tenderly/hardhat-tenderly
curl https://raw.githubusercontent.com/Tenderly/tenderly-cli/master/scripts/install-linux.sh | sudo sh
```

login to tenderly
```bash
tenderly login
```
when prompted (1st time usage) enter access key (= access token, see https://dashboard.tenderly.co/account/authorization)

run deployment to tenderly testnet (eg <tenderlyNetwork>=virtualMainnet in the example below)

```bash
export RESUMEABLE_DEPLOYMENT=false
export ENABLE_ETHERSCAN_VERIFICATION=false
export ENABLE_TENDERLY_VERIFICATION=true
hh run --network <tenderlyNetwork> scripts/deploy_all.ts
```

Environment variables:

- `RESUMEABLE_DEPLOYMENT` set to `true` to skip deployment/verification of already deployed/verified contracts (based on ./deployment_state_<chainId>.json), set to `true` to force a redeploy
- `ENABLE_TENDERLY_VERIFICATION` set to `true` to perform verification of deployed contracts 
# https://dashboard.tenderly.co/{TENDERLY_USERNAME}/{TENDERLY_PROJECT}/fork/{FORK_ID}
- `TENDERLY_DEVNET_RPC_URL` is the RPC_URL of a Tenderly Devnet, found on the devnet UI info tab
- `TENDERLY_USERNAME` is username, {TENDERLY_USERNAME} in the URL
- `TENDERLY_PROJECT` is project slug, {TENDERLY_PROJECT} in the URL

### Create a new instance

Requires previous step to be completed. 

```bash
# set appropriate values for env variables (see below)

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

