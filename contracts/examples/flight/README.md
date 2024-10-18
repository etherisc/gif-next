# Deployment

## Initial Repository Setup

Clone gif-next into a separate local repository for deployment/verification.
If such a repository already exists, make sure to update it to the desired branch/commit.

See the main `README.md` for instructions to only deploy GIF or a full deploy including both GIF and the fire and flight example products.

## Initial Deployment of the FlightDelay Product

Ensure that the necessary wallets are properly funded.
Variable `WALLET_MNEMONIC` in `.env` is used to create the necessary signers.
the protocol owner is defined as signer[0], and the flight owner (product owner) as signer[2].
These two wallets need enough POL/ETH/... to execute the deployment transactions. 

Check that the environment variables in the `.env` match with the intended chain and your expecations.

```bash
hh run scripts/deploy_flightdelay_components.ts --network <networkname>
```

Copy the flight specific addresses of the deployment script output to the .env file.
Add/update the flight specific environment variables 
`FLIGHT_TOKEN_ADDRESS`, `INSTANCE_ADDRESS`, `FLIGHTLIB_ADDRESS`, `FLIGHT_PRODUCT_ADDRESS` and `FLIGHT_POOL_ADDRESS` accordingly.

Verify the deployment using the command below.

```bash
hh run scripts/verify_deployment.ts --network <networkname>
```

## Re-Deployment of the FlightDelay Product

Check that the environment variables in the `.env` match with the intended chain and your expecations.

Ensure that the necessary wallets are properly funded.
Variable `WALLET_MNEMONIC` in `.env` is used to create the necessary signers.
the protocol owner is defined as signer[0], and the flight owner (product owner) as signer[2].
These two wallets need enough POL/ETH/... to execute the deployment transactions. 

Comment out all variables that refer to components that need to be re-deployed.
For example, keep the previous values for `FLIGHT_TOKEN_ADDRESS` and `INSTANCE_ADDRESS` for a partial deployment that reuses the existing instance and flight token.

In directory `deployments/<chainId>`: except for `libraries_<chainId>.json` delete all other `*.json` files.

 ```bash
 hh run scripts/deploy_flightdelay_components.ts --network <networkname>
 ```

Copy the flight specific addresses of the deployment script output to the .env file.
Update the flight specific environment variables 
`FLIGHT_TOKEN_ADDRESS`, `INSTANCE_ADDRESS`, `FLIGHTLIB_ADDRESS`, `FLIGHT_PRODUCT_ADDRESS` and `FLIGHT_POOL_ADDRESS` accordingly.

Verify the deployment using the command below.

```bash
hh run scripts/verify_deployment.ts --network <networkname>
```

# Setup

From `hh console --network <name>`

```js
[protocolOwner,masterInstanceOwner,flightOwner] = await ethers.getSigners();

// check balance
ethers.formatEther(await ethers.provider.getBalance(flightOwner))

flightUSD = await hre.ethers.getContractAt("FlightUSD", process.env.FLIGHT_TOKEN_ADDRESS, flightOwner);
chainNft = await hre.ethers.getContractAt("ChainNft", process.env.CHAIN_NFT_ADDRESS, protocolOwner);

// get instance contracts
instance = await hre.ethers.getContractAt("IInstance", process.env.INSTANCE_ADDRESS, flightOwner);
instanceReaderAddress = await instance.getInstanceReader()
instanceReader = await hre.ethers.getContractAt("InstanceReader", instanceReaderAddress, flightOwner);

// transfer amounts
await flightUSD.transfer('0xA3C552FA4756dd343394785283923bE2f27f8814', ethers.parseUnits('1000000',6))
await flightUSD.balanceOf('0xA3C552FA4756dd343394785283923bE2f27f8814')

await flightUSD.transfer('0xcf4aCb04c30606DBd1cD9D175Bd8AC3385Bc727e', ethers.parseUnits('1000000',6))

await protocolOwner.sendTransaction({
      to: '0x23Eb11dDeb71cbe53B8cb4D5225fe189B1052b85',
      value: ethers.parseEther("10.0"), 
    });
await protocolOwner.sendTransaction({
      to: '0xA3C552FA4756dd343394785283923bE2f27f8814',
      value: ethers.parseEther("10.0"), 
    });


// configure flight pool
FlightPool = await ethers.getContractFactory("FlightPool", {
    libraries: {
      AmountLib: process.env.AMOUNTLIB_ADDRESS,
      ContractLib: process.env.CONTRACTLIB_ADDRESS,
      FeeLib: process.env.FEELIB_ADDRESS,
      NftIdLib: process.env.NFTIDLIB_ADDRESS,
      ObjectTypeLib: process.env.OBJECTTYPELIB_ADDRESS,
      SecondsLib: process.env.SECONDSLIB_ADDRESS,
      UFixedLib: process.env.UFIXEDLIB_ADDRESS,
      VersionLib: process.env.VERSIONLIB_ADDRESS,
    },
})
FlightPool = FlightPool.connect(flightOwner)
flightPool = await FlightPool.attach(process.env.FLIGHT_POOL_ADDRESS)

tokenHandler = await flightPool.getTokenHandler()
await flightUSD.approve(tokenHandler, 10000 * 10 ** 6)
await flightPool.createBundle(10000*10**6)

// configure flight product
FlightProduct = await ethers.getContractFactory("FlightProduct", {
    libraries: {
      AmountLib: process.env.AMOUNTLIB_ADDRESS,
      ContractLib: process.env.CONTRACTLIB_ADDRESS,
      FeeLib: process.env.FEELIB_ADDRESS,
      FlightLib: process.env.FLIGHTLIB_ADDRESS,
      NftIdLib: process.env.NFTIDLIB_ADDRESS,
      ObjectTypeLib: process.env.OBJECTTYPELIB_ADDRESS,
      ReferralLib: process.env.REFERRALLIB_ADDRESS,
      SecondsLib: process.env.SECONDSLIB_ADDRESS,
      StrLib: process.env.STRLIB_ADDRESS,
      TimestampLib: process.env.TIMESTAMPLIB_ADDRESS,
      VersionLib: process.env.VERSIONLIB_ADDRESS,
    },
})
FlightProduct = FlightProduct.connect(flightOwner)
flightProduct = await FlightProduct.attach(process.env.FLIGHT_PRODUCT_ADDRESS)

// obtain bundle nft id from bundle creation tx logs
await flightProduct.setDefaultBundle('...')

// grant statistics data provider role to 
applicationSigner = '...'
await instance.grantRole(1000001, applicationSigner)

// grant status provider role to 
oracleSigner = '...'
await instance.grantRole(1000002, oracleSigner)

await flightProduct.setTestMode(true)


```