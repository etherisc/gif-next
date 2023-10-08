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
    TestVersion,
    Instance
)

from test_brownie.const import (
    ZERO_ADDRESS,
    ADDRESS,
    NFT_ID,
    REGISTRY,
    SERVICE,
    INSTANCE,
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

def test_instance(
    instance: Instance,
    instance_owner: Account,
    registry: Registry,
    registry_owner: Account,
    version_lib: TestVersion
) -> None:

    instance_nft_id = instance.getNftId()

    assert False

    # check instance registration
    assert registry.isRegistered[NFT_ID](instance_nft_id)
    assert registry.isRegistered[ADDRESS](instance)
    assert registry.getNftId(instance) == instance_nft_id
    
    # check ownership
    assert instance.getOwner() == instance_owner
    assert registry.getOwner(instance_nft_id) == instance_owner

    # check registry object info for instance
    info = registry.getObjectInfo(instance_nft_id).dict()
    assert info['nftId'] == instance_nft_id
    assert info['parentNftId'] == registry.getNftId()
    assert info['objectType'] == INSTANCE
    assert info['objectAddress'] == instance
    assert info['initialOwner'] == instance_owner
    assert info['data'] == '0x'
