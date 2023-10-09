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
    NftIdLib,
    ObjectTypeLib,
    StateIdLib,
    TimestampLib,
    FeeLib,
    UFixedMathLib,
    VersionLib,
    VersionPartLib,
    TestVersion
)

from brownie.network import accounts
from brownie.network.account import Account

from test_brownie.gif import (
    deploy_libs,
    deploy_token,
    deploy_registry,
    deploy_services,
    deploy_instance,
    deploy_pool,
    deploy_product,
) 

from test_brownie.const import (
    ACCOUNTS,
    REGISTRY_OWNER,
    INSTANCE_OWNER,
    PRODUCT_OWNER,
    POOL_OWNER,
    INVESTOR,
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
def investor(accounts) -> Account:
    return accounts[ACCOUNTS[INVESTOR]]

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
def all_libs(registry_owner) -> ObjectTypeLib:
    return deploy_libs(registry_owner, force_deploy = True)

@pytest.fixture(scope="module")
def version_lib(all_libs, registry_owner) -> TestVersion:
    return TestVersion.deploy({'from': registry_owner})

@pytest.fixture(scope="module")
def all_services(registry, registry_owner) -> ObjectTypeLib:
    return deploy_services(registry, registry_owner)

#=== access to deployed gif contract classes ==========================================#

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
def component_owner_service(all_services) -> ComponentOwnerService:
    return all_services['ComponentOwnerService']

@pytest.fixture(scope="module")
def product_service(all_services) -> ProductService:
    return all_services['ProductService']

@pytest.fixture(scope="module")
def pool_service(all_services) -> PoolService:
    return all_services['PoolService']

@pytest.fixture(scope="module")
def instance(all_services, registry, instance_owner) -> Instance:
    return deploy_instance(registry, instance_owner)

@pytest.fixture(scope="module")
def pool(registry, instance, instance_owner, usdc, pool_owner) -> TestPool:
    pool_is_verifying = True
    pool_collateralization_level = instance.getUFixed(1)

    return deploy_pool(registry, instance, instance_owner, usdc, pool_is_verifying, pool_collateralization_level, pool_owner)

@pytest.fixture(scope="module")
def product(registry, instance, instance_owner, usdc, pool, product_owner) -> TestProduct:
    return deploy_product(registry, instance, instance_owner, usdc, pool, product_owner)

