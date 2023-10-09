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
    BlocknumberLib,
    Key32Lib,
    NftIdLib,
    RiskIdLib,
    LibNftIdSet,
    FeeLib,
    ObjectTypeLib,
    RoleIdLib,
    StateIdLib,
    TimestampLib,
    UFixedMathLib,
    VersionLib,
    VersionPartLib 
)

from const import (
    POOL_OWNER_ROLE,
    PRODUCT_OWNER_ROLE,
)

libs = {}
libs_are_deployed = False

services = {}

def deploy_libs(owner, force_deploy = False):
    global libs_are_deployed
    global libs

    if not force_deploy and libs_are_deployed:
        return libs

    libs['BlocknumberLib'] = deploy_lib(BlocknumberLib, owner)
    libs['LibNftIdSet'] = deploy_lib(LibNftIdSet, owner)
    libs['Key32Lib'] = deploy_lib(Key32Lib, owner)
    libs['NftIdLib'] = deploy_lib(NftIdLib, owner)
    libs['ObjectTypeLib'] = deploy_lib(ObjectTypeLib, owner)
    libs['RoleIdLib'] = deploy_lib(RoleIdLib, owner)
    libs['RiskIdLib'] = deploy_lib(RiskIdLib, owner)
    libs['StateIdLib'] = deploy_lib(StateIdLib, owner)
    libs['TimestampLib'] = deploy_lib(TimestampLib, owner)
    libs['UFixedMathLib'] = deploy_lib(UFixedMathLib, owner)
    libs['VersionLib'] = deploy_lib(VersionLib, owner)
    libs['VersionPartLib'] = deploy_lib(VersionPartLib, owner)
    libs['FeeLib'] = deploy_lib(FeeLib, owner)

    libs_are_deployed = True
    return libs


def deploy_services(registry, owner):
    global services
    
    services = deploy_service(services, 'ComponentOwnerService', ComponentOwnerService, registry, owner)
    services = deploy_service(services, 'ProductService', ProductService, registry, owner)
    services = deploy_service(services, 'PoolService', PoolService, registry, owner)

    return services


def deploy_token(token_class, owner):
    return token_class.deploy({'from': owner})

def deploy_registry(owner):
    deploy_libs(owner)

    reg = Registry.deploy({'from': owner})
    nft = ChainNft.deploy(reg, {'from': owner})
    reg.initialize(nft, owner, {'from': owner})

    return reg

def deploy_lib(lib_class, owner):
    lib_class.deploy({'from': owner})

def deploy_service(services, service_name, service_class, registry, owner):
    service = service_class.deploy(registry, registry.getNftId(), {'from': owner})
    service.register()

    services[service_name] = service
    return services

def deploy_instance(registry, instance_owner):
    instance = Instance.deploy(registry, registry.getNftId(), {'from': instance_owner})
    instance.register({'from': instance_owner})
    return instance

def deploy_pool(registry, instance, instance_owner, token, pool_is_verifying, pool_collateralization_level, pool_owner):
    pool_owner_role = instance.getRoleId(POOL_OWNER_ROLE)
    instance.grantRole(pool_owner_role, pool_owner, {'from': instance_owner})

    staking_fee = instance.getZeroFee()
    performance_fee = instance.getZeroFee()
    pool = TestPool.deploy(
        registry,
        instance.getNftId(),
        token,
        pool_is_verifying, 
        pool_collateralization_level,
        staking_fee,
        performance_fee,
        {'from': pool_owner})
    
    pool.register({'from': pool_owner})
    return pool

def deploy_product(registry, instance, instance_owner, token, pool, product_owner):
    product_owner_role = instance.getRoleId(PRODUCT_OWNER_ROLE)
    instance.grantRole(product_owner_role, product_owner, {'from': instance_owner})

    policy_fee = instance.getZeroFee()
    processing_fee = instance.getZeroFee()
    product = TestProduct.deploy(
        registry,
        instance.getNftId(),
        token,
        pool,
        policy_fee,
        processing_fee,
        {'from': product_owner})
    
    product.register({'from': product_owner})
    return product
