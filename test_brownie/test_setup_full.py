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
    POOL_SERVICE_NAME,
    BUNDLE,
    POLICY,
    ACTIVE,
    APPLIED,
    UNDERWRITTEN
)

from test_brownie.gif import create_bundle
from test_brownie.util import (
    contract_from_address,
    s2b
)

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
    treasury_info = instance.getTreasuryInfo(product_nft_id).dict()
    assert treasury_info['poolNftId'] == pool_nft_id
    assert treasury_info['token'] == usdc


def test_create_bundle_full(
    usdc: TestUsdc,
    all_libs: map, 
    all_services: map,
    registry: Registry,
    registry_owner: Account,
    instance: Instance,
    pool: TestPool,
    investor: Account,
    product: TestProduct
):
    assert pool.getToken() == usdc
    assert instance.getBundleCount(pool.getNftId()) == 0
    assert usdc.balanceOf(pool) == 0

    bundle_fee = instance.getZeroFee()
    initial_bundle_capacity = 1000 * 10 ** usdc.decimals()
    lifetime = 31 * 24 * 3600
    bundle_filter = ""
    transfer_helper = instance.getTokenHandler(product.getNftId())

    usdc.transfer(investor, initial_bundle_capacity, {'from': registry_owner})
    usdc.approve(transfer_helper, initial_bundle_capacity, {'from': investor})
    tx = pool.createBundle(bundle_fee, initial_bundle_capacity, 31 * 24 * 3600, "", {'from': investor})

    assert instance.getBundleCount(pool.getNftId()) == 1
    assert usdc.balanceOf(pool) == initial_bundle_capacity

    bundle_nft_id = instance.getBundleNftId(pool.getNftId(), 0)
    bundle_info = instance.getBundleInfo(bundle_nft_id).dict()

    assert registry.getOwner(bundle_nft_id) == investor
    assert bundle_info['balanceAmount'] == initial_bundle_capacity
    assert bundle_info['capitalAmount'] == initial_bundle_capacity
    assert bundle_info['lockedAmount'] == 0

    bundle_key = all_libs['NftIdLib'].toKey32(bundle_nft_id, BUNDLE)
    assert instance.getState(bundle_key) == ACTIVE


def test_create_bundle_simple(
    usdc: TestUsdc,
    all_libs: map,
    all_services: map,
    registry: Registry,
    registry_owner: Account,
    instance: Instance,
    pool: TestPool,
    investor: Account,
    product: TestProduct
):
    assert pool.getToken() == usdc
    assert instance.getBundleCount(pool.getNftId()) == 0
    assert usdc.balanceOf(pool) == 0

    bundle_fee = instance.getZeroFee()
    bundle_capacity = 42 * 10 ** usdc.decimals()
    bundle_nft_id = create_bundle(
        instance,
        product,
        pool,
        registry_owner,
        investor,
        bundle_fee,
        bundle_capacity
    )

    assert instance.getBundleCount(pool.getNftId()) == 1
    assert usdc.balanceOf(pool) == bundle_capacity

    bundle_info = instance.getBundleInfo(bundle_nft_id).dict()

    assert registry.getOwner(bundle_nft_id) == investor
    assert bundle_info['balanceAmount'] == bundle_capacity
    assert bundle_info['capitalAmount'] == bundle_capacity
    assert bundle_info['lockedAmount'] == 0

    bundle_key = all_libs['NftIdLib'].toKey32(bundle_nft_id, BUNDLE)
    assert instance.getState(bundle_key) == ACTIVE



def test_create_policy(
    usdc: TestUsdc,
    all_libs: map,
    all_services: map,
    registry: Registry,
    registry_owner: Account,
    instance: Instance,
    pool: TestPool,
    investor: Account,
    product: TestProduct,
    customer: Account
):
    bundle_fee = instance.getZeroFee()
    bundle_capacity = 1000 * 10 ** usdc.decimals()
    bundle_nft_id = create_bundle(
        instance,
        product,
        pool,
        registry_owner,
        investor,
        bundle_fee,
        bundle_capacity
    )
    referral_code = 'SAVE!!!'
    referral_id = all_libs['ReferralIdLib'].toReferralId(referral_code)

    sum_insured = 500 * 10 ** usdc.decimals()
    lifetime = 365 * 24 * 3600
    risk_id = s2b("")
    application_data = s2b("")

    tx = product.applyForPolicy(sum_insured, lifetime, bundle_nft_id, referral_id, {'from': customer})
    policy_nft_id = tx.events['Transfer']['tokenId']

    assert registry.getOwner(policy_nft_id) == customer

    policy_key = all_libs['NftIdLib'].toKey32(policy_nft_id, POLICY)
    assert instance.getState(policy_key) == APPLIED

    premium_expected = product.calculatePremium(
        sum_insured, risk_id, lifetime, application_data, referral_id, bundle_nft_id
    )

    policy_info = instance.getPolicyInfo(policy_nft_id).dict()

    assert policy_info['riskId'] == product.getDefaultRiskId()
    assert policy_info['sumInsuredAmount'] == sum_insured
    assert policy_info['premiumAmount'] == premium_expected
    assert policy_info['premiumPaidAmount'] == 0
    assert policy_info['lifetime'] == lifetime
    assert policy_info['referralId'] == referral_id
