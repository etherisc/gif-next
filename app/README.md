# Interact with Contracts

## Start Python Shell

Open Python Shell

```bash
cd app
uv run python
```

Setup interactive Python environment

```python
import os
from dotenv import load_dotenv

from web3 import Web3
from web3utils.contract import Contract
from web3utils.wallet import Wallet
from web3utils.chain import Chain

load_dotenv("../.env")

# get w3 provider/node
w3_uri = os.getenv("NETWORK_URL")
w3 = Web3(Web3.HTTPProvider(w3_uri))
chain = Chain(w3)

# get flight contracts
product = Contract(w3, "FlightProduct", os.getenv("FLIGHT_PRODUCT_ADDRESS"))
usdc = Contract(w3, "FlightUSD", product.getToken())
instance = Contract(w3, "Instance", product.getInstance())
registry = Contract(w3, "Registry", instance.getRegistry())
reader = Contract(w3, "InstanceReader", instance.getInstanceReader())

pool_nft = reader.getProductInfo(product.getNftId())[5]
bundle_nft = reader.getActiveBundleNftId(pool_nft, 0)
pool = Contract(w3, "FlightPool", registry.getObjectAddress(pool_nft))

# flight pool amounts
usdc.balanceOf(pool.getWallet())/10**usdc.decimals()
reader.getBalanceAmount(pool_nft)/10**usdc.decimals()
reader.getLockedAmount(pool_nft)/10**usdc.decimals()
reader.getFeeAmount(pool_nft)/10**usdc.decimals()

# bundle amounts
reader.getBalanceAmount(bundle_nft)/10**usdc.decimals()
reader.getLockedAmount(bundle_nft)/10**usdc.decimals()
reader.getFeeAmount(bundle_nft)/10**usdc.decimals()

# check if bundle is expired
(_, expired_at, _, _, _, _) = reader.getBundleInfo(bundle_nft)
expired_at < chain.timestamp()

# check instance owner is bundle owner
instance_owner = Wallet.from_mnemonic(<mnemonic>, index=2, w3=w3)
registry.ownerOf(bundle_nft) == instance_owner.address
```