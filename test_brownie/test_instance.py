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

    # todo
    assert False