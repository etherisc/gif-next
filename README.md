![Build & Tests](https://github.com/etherisc/gif-next/actions/workflows/build.yml/badge.svg)
[![npm (tag)](https://img.shields.io/npm/v/@etherisc/gif-next/next)](https://www.npmjs.com/package/@etherisc/gif-next)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Static Badge](https://img.shields.io/badge/Discord-join-blue)](https://discord.gg/ww2AZJ4WYN)


# GIF-Next (Generic Insurance Framework, version 3)

For technical reason, this repository is called `gif-next`, but it contains the code of the version 3 of the Generic Insurance Framework (GIF). 

## Submodules checkout

The project depends heavily on the use of submodules for dependencies, so it is important to checkout the submodules when cloning the repository. 

For initial checkout call

```shell
git submodule update --init --recursive
```

To update to the latest submodules, run the following command after updating to any revision (or checking out the repository)

```shell
git submodule update --recursive
```

## Recommended IDE & Development Environment

The project is setup with a devcontainer for Visual Studio Code. This is the recommended way for use with the project. 
It will provide a consistent development environment for all developers with all the required dependencies installed. 

Hardhat is used for compiling the smart contracts and all deployment scripts are hardhat based. 
Unit tests are written using the forge testing framework. See below for most important commands to run tests and deployments.

### What to do next

If you are interested in creating your own products, have a look at our [example sandbox repository](https://github.com/etherisc/gif-next-sandbox) that contains a simple example of how to build new products on top of the GIF.
Or see our documentation on the setup of the [fire example components](https://docs.etherisc.com/gif-next/3.x/example-fire).

Or dive into the gif framework code by running the tests and/or deploying the contracts.

### Running all unit tests

```bash
forge test
```

### Staring a full protocol deployment 

```bash
hh run scripts/deploy_gif.ts
```

To include the fire example components instead run the following command

```bash
hh run scripts/deploy_all.ts
```

The command accepts regular hardhat parameters for network selection and other configuration. Also some environment variables are required for deployment.

Code verification is done separately using the following command (which read data from the serialized deployment state of the deploymnent script that ran beforehand)

```bash
hh run scripts/verify_deployment.ts
```

This uses the same environment variables as the deployment script.

#### Important environment variables

- `NETWORK_URL` the rpc endpoint to use
- `WALLET_MNEMONIC` the HD wallet mnemonic to use for deployment. Wallet #0 will be the protocol owner. 
- `GAS_PRICE` the gas price to use for deployment
- `DIP_ADDRESS` the address of the already deployed DIP token. if not set, the script will deploy a new DIP token
- `RESUMEABLE_DEPLOYMENT` if this flag is set to `true`, the deployment will write all transactions to a state file so the deployment can be resumed after a failure (or after a manual stop). data is stored in the `deployment/<chainid>/` directory. 
- `ETHERSCAN_API_KEY` the api key for etherscan
- `POLYGONSCAN_API_KEY` the api key for polygonscan


## Hardhat commands

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
- `DIP_ADDRESS` the address of the already deployed DIP token. if not set, the script will deploy a new DIP token
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


### Console

```
hh console --network <networkname>

me = hre.ethers.Wallet.fromPhrase('...')
provider = hre.ethers.provider
await provider.getBalance(me)
```



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
forge build --sizes

forge test

# run single test case
forge test --mt test_deployAllSetup

# run all tests except long running
forge test --nmt longRunning

# run single test case with substantial logging
# to include logs as well use -vvvvv
# to add internal functions to trace add --
forge test --decode-internal --mt test_decimals -vvvv

# provide gas report for a single test
forge test --mt test_decimals --gas-report

# provide code coverage report
forge coverage
forge coverage --report lcov 
```

### Aliases configured in the devcontainer setup


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
