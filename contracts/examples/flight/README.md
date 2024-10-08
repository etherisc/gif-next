 # Deployment

 ```
 hh run scripts/deploy_flightdelay_components.ts --network polygonAmoy
 ```


# Setup

From `hh console --network <name>`

```js
[protocolOwner,masterInstanceOwner,flightOwner] = await ethers.getSigners();

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
      TimestampLib: process.env.TIMESTAMPLIB_ADDRESS,
      VersionLib: process.env.VERSIONLIB_ADDRESS,
    },
})
FlightProduct = FlightProduct.connect(flightOwner)
flightProduct = await FlightProduct.attach(process.env.FLIGHT_PRODUCT_ADDRESS)

await flightProduct.setDefaultBundle('...')

// grant statistics data provider role to 
await instance.grantRole(1000001, '...')
// grant status provider role to 
await instance.grantRole(1000002, '...')

await flightProduct.setTestMode(true)


```