import pytest
import brownie

from brownie.network.account import Account

from brownie import (
    history,
    interface,
    web3,
    ChainNft,
    Registry,
    ComponentOwnerService,
    ProductService,
    PoolService,
    TestUsdc,
    Instance,
    TestProduct,
    TestPool
)

from test_brownie.const import (
    ZERO_ADDRESS,
    ADDRESS,
    NFT_ID,
    REGISTRY,
    SERVICE,
    INSTANCE,
    POOL,
    PRODUCT,
    VERSION,
    COMPONENT_OWNER_SERVICE_NAME,
    PRODUCT_SERVICE_NAME,
    POOL_SERVICE_NAME
)

from test_brownie.util import contract_from_address

# enforce function isolation for tests below
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

def test_pool(
    usdc: TestUsdc,
    all_services: map,
    registry: Registry,
    registry_owner: Account,
    instance: Instance,
    instance_owner: Instance,
    pool: TestPool,
    pool_owner: Account
) -> None:

    # check pool
    pool_nft_id = pool.getNftId()

    # check instance registration
    assert registry.isRegistered[NFT_ID](pool_nft_id)
    assert registry.isRegistered[ADDRESS](pool)
    assert registry.getNftId(pool) == pool_nft_id
    
    # check ownership
    assert pool.getOwner() == pool_owner
    assert registry.getOwner(pool_nft_id) == pool_owner

    # check registry object info for instance
    info = registry.getObjectInfo(pool_nft_id).dict()
    assert info['nftId'] == pool_nft_id
    assert info['parentNftId'] == instance.getNftId()
    assert info['objectType'] == POOL
    assert info['objectAddress'] == pool
    assert info['initialOwner'] == pool_owner
    assert info['data'] == '0x'

def test_product(
    usdc: TestUsdc,
    all_services: map,
    registry: Registry,
    registry_owner: Account,
    instance: Instance,
    instance_owner: Instance,
    pool: TestPool,
    product: TestProduct,
    product_owner: Account
) -> None:

    # check product
    pool_nft_id = pool.getNftId()
    product_nft_id = product.getNftId()

    # check instance registration
    assert registry.isRegistered[NFT_ID](product_nft_id)
    assert registry.isRegistered[ADDRESS](product)
    assert registry.getNftId(product) == product_nft_id
    
    # check ownership
    assert product.getOwner() == product_owner
    assert registry.getOwner(product_nft_id) == product_owner

    # check registry object info for instance
    info = registry.getObjectInfo(product_nft_id).dict()
    assert info['nftId'] == product_nft_id
    assert info['parentNftId'] == instance.getNftId()
    assert info['objectType'] == PRODUCT
    assert info['objectAddress'] == product
    assert info['initialOwner'] == product_owner
    assert info['data'] == '0x'

    # check link to pool and other parts of product setup
    setup = instance.getProductSetup(product_nft_id).dict()
    assert setup['productNftId'] == product_nft_id
    assert setup['poolNftId'] == pool_nft_id
    assert setup['token'] == usdc
    assert setup['wallet'] == product
