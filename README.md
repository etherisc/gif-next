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
```

### Documentation

https://book.getfoundry.sh/reference/

