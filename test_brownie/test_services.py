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
)

from test_brownie.const import (
    ZERO_ADDRESS,
    ADDRESS,
    NFT_ID,
    REGISTRY,
    SERVICE,
    VERSION,
    COMPONENT_OWNER_SERVICE_NAME,
    DISTRIBUTION_SERVICE_NAME,
    POOL_SERVICE_NAME,
    PRODUCT_SERVICE_NAME,
)

from test_brownie.util import contract_from_address

# enforce function isolation for tests below
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

def _test_service(
    service_name: str,
    index: int,
    services: map,
    registry: Registry,
    registry_owner: Account,
    version_lib: TestVersion
) -> None:

    # check service name
    service = services[service_name]
    assert service.NAME() == service_name

    # check service version
    version = version_lib.getVersionParts(service.getVersion())
    assert version == VERSION
    assert service.getMajorVersion() == VERSION[0]

    # check parent nft (registra) and owner
    registry_nft_id = registry.getNftId()
    assert service.getParentNftId() == registry_nft_id
    assert service.getOwner() == registry_owner

    # check that service nft is actually registered
    service_nft_id = service.getNftId()
    assert registry.isRegistered[NFT_ID](service_nft_id)
    assert registry.isRegistered[ADDRESS](service)
    assert int(str(service_nft_id)[0]) == int(str(registry_nft_id)[0]) + index

    # check that registry actually returns the servie given its name and major version
    assert registry.getServiceAddress(
        service.NAME(), 
        service.getMajorVersion()) == service

    # check service info content in registry
    service_info = registry.getObjectInfo(service_nft_id).dict()
    assert service_info['nftId'] == service_nft_id
    assert service_info['parentNftId'] == registry_nft_id
    assert service_info['objectType'] == SERVICE
    assert service_info['objectAddress'] == service
    assert service_info['data'] == '0x'


def test_component_owner_service(
    all_services: map,
    registry: Registry,
    registry_owner: Account,
    version_lib: TestVersion
):
    _test_service(
        COMPONENT_OWNER_SERVICE_NAME,
        1,
        all_services,
        registry,
        registry_owner,
        version_lib
    )


def test_distribution_service(
    all_services: map,
    registry: Registry,
    registry_owner: Account,
    version_lib: TestVersion
):
    _test_service(
        DISTRIBUTION_SERVICE_NAME,
        2, 
        all_services,
        registry,
        registry_owner,
        version_lib
    )


def test_pool_service(
    all_services: map,
    registry: Registry,
    registry_owner: Account,
    version_lib: TestVersion
):
    _test_service(
        POOL_SERVICE_NAME,
        3, 
        all_services,
        registry,
        registry_owner,
        version_lib
    )


def test_product_service(
    all_services: map,
    registry: Registry,
    registry_owner: Account,
    version_lib: TestVersion
):
    _test_service(
        PRODUCT_SERVICE_NAME,
        4, 
        all_services,
        registry,
        registry_owner,
        version_lib
    )
