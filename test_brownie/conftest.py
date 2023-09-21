import pytest

from brownie import (
    interface,
    Wei,
    Contract,
    ChainNft,
    Registry,
    ComponentOwnerService,
    ProductService,
    PoolService,
    Instance,
    TestProduct,
    TestPool,
    TestUsdc,
    TestFee,
    ObjectTypeLib,
    NftIdLib,
    StateIdLib,
    UFixedMathLib,
    VersionLib,
    VersionPartLib    
)

from brownie.network import accounts
from brownie.network.account import Account

from test_brownie.gif import (
    deploy_libs,
    deploy_token,
    deploy_registry,
    deploy_service,
) 

from test_brownie.const import (
    ACCOUNTS,
    REGISTRY_OWNER,
    INSTANCE_OWNER,
    PRODUCT_OWNER,
    POOL_OWNER,
    CUSTOMER,
    CUSTOMER_2,
    OUTSIDER
)

from test_brownie.util import contract_from_address

INITIAL_ACCOUNT_FUNDING = '1 ether'

#=== generic helpers =========================================================#

# fixtures with `yield` execute the code that is placed before the `yield` as setup code
# and code after `yield` is teardown code. 
# See https://docs.pytest.org/en/7.1.x/how-to/fixtures.html#yield-fixtures-recommended
@pytest.fixture(autouse=True)
def run_around_tests():
    try:
        yield
        # after each test has finished, execute one trx and wait for it to finish. 
        # this is to ensure that the last transaction of the test is finished correctly. 
    finally:
        accounts[8].transfer(accounts[9], 1)
        # dummy_account = get_account(ACCOUNTS_MNEMONIC, 999)
        # execute_simple_incrementer_trx(dummy_account)

def deploy_service(service_class, registry, owner):
    service = service_class.deploy(registry, registry.getNftId(), {'from': owner})
    service.register()
    return service

#=== actor account fixtures  =================================================#

@pytest.fixture(scope="module")
def registry_owner(accounts) -> Account:
    return accounts[ACCOUNTS[REGISTRY_OWNER]]

@pytest.fixture(scope="module")
def instance_owner(accounts) -> Account:
    return accounts[ACCOUNTS[INSTANCE_OWNER]]

@pytest.fixture(scope="module")
def product_owner(accounts) -> Account:
    return accounts[ACCOUNTS[PRODUCT_OWNER]]

@pytest.fixture(scope="module")
def pool_owner(accounts) -> Account:
    return accounts[ACCOUNTS[POOL_OWNER]]

@pytest.fixture(scope="module")
def customer(accounts) -> Account:
    return accounts[ACCOUNTS[CUSTOMER]]

@pytest.fixture(scope="module")
def customer2(accounts) -> Account:
    return accounts[ACCOUNTS[CUSTOMER_2]]

@pytest.fixture(scope="module")
def outsider(accounts) -> Account:
    return accounts[ACCOUNTS[OUTSIDER]]


#=== erc-20 fixtures =========================================================#

@pytest.fixture(scope="module")
def usdc(registry_owner) -> TestUsdc:
    return deploy_token(TestUsdc, registry_owner)

#=== access to gif library contracts =========================================#

@pytest.fixture(scope="module")
def nft_id_lib(registry_owner) -> NftIdLib:
    return NftIdLib.deploy({'from': registry_owner})

@pytest.fixture(scope="module")
def object_type_lib(registry_owner) -> ObjectTypeLib:
    return ObjectTypeLib.deploy({'from': registry_owner})


@pytest.fixture(scope="module")
def all_libs(registry_owner) -> ObjectTypeLib:
    return deploy_libs(registry_owner, force_deploy = True)

#=== access to gif contract classes ==========================================#

@pytest.fixture(scope="module")
def chain_nft_standalon(all_libs, registry_owner) -> ChainNft:
    deploy_libs(registry_owner)
    return ChainNft.deploy(registry_owner, {'from': registry_owner})

@pytest.fixture(scope="module")
def registry(all_libs, registry_owner) -> Registry:
    return deploy_registry(registry_owner)

@pytest.fixture(scope="module")
def chain_nft(registry) -> ChainNft:
    return contract_from_address(ChainNft, registry.getChainNft())

@pytest.fixture(scope="module")
def component_owner_service(registry, registry_owner) -> ComponentOwnerService:
    return deploy_service(ComponentOwnerService, registry, registry_owner)

@pytest.fixture(scope="module")
def product_service(registry, registry_owner) -> ProductService:
    return deploy_service(ComponentOwnerService, registry, registry_owner)

@pytest.fixture(scope="module")
def pool_service(registry, registry_owner) -> PoolService:
    return deploy_service(ComponentOwnerService, registry, registry_owner)
