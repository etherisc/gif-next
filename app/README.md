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

from gif.product import from_product, pool_for_product
from web3utils.contract import Contract
from web3utils.wallet import Wallet
from web3utils.chain import Chain

load_dotenv("./.env")

# get w3 provider/node
w3_uri = os.getenv("NETWORK_URL")
w3 = Web3(Web3.HTTPProvider(w3_uri))
chain = Chain(w3)

# check network connection
assert chain.id() == 80002, f"Not Polygon Amoy. Chain ID {chain.id()}, expected 80002"
assert chain.id() == 8453, f"Not Base Mainnet. Chain ID {chain.id()}, expected 8453"

# get crop contract
(product, usdc, instance, admin, reader, registry) = from_product(w3, "CropProduct", os.getenv("PRODUCT_CONTRACT_ADDRESS"))
pool = pool_for_product(registry, reader, product, "CropPool")

# get flight contract
(product, usdc, instance, admin, reader, registry) = from_product(w3, "FlightProduct", os.getenv("FLIGHT_PRODUCT_ADDRESS"))
pool = pool_for_product(registry, reader, product, "FlightPool")
pool_nft = pool.getNftId()
bundle_nft = reader.getActiveBundleNftId(pool_nft, 0)

# amounts
usdc.balanceOf(pool.getWallet())/10**usdc.decimals()
reader.getBalanceAmount(bundle_nft)/10**usdc.decimals()
reader.getLockedAmount(bundle_nft)/10**usdc.decimals()
reader.getFeeAmount(bundle_nft)/10**usdc.decimals()

# check if bundle is expired
(_, expired_at, _, _, _, _) = reader.getBundleInfo(bundle_nft)
expired_at < chain.timestamp()

# check instance owner is bundle owner
instance_owner = Wallet.from_mnemonic(<mnemonic>, index=2, w3=w3)
registry.ownerOf(bundle_nft) == instance_owner.address

# stake additional usdc 1000 to bundle (remember to also transfer usdc to pool.getWallet())
assert registry.ownerOf(bundle_nft) == instance_owner.address, "instance owner not bundle owner"
pool.stake(bundle_nft, 1000 * 10 ** usdc.decimals(), {'from': instance_owner})
```