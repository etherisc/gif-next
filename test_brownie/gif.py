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
    NftIdLib,
    LibNftIdSet,
    ObjectTypeLib,
    StateIdLib,
    TimestampLib,
    UFixedMathLib,
    VersionLib,
    VersionPartLib 
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
    libs['NftIdLib'] = deploy_lib(NftIdLib, owner)
    libs['LibNftIdSet'] = deploy_lib(LibNftIdSet, owner)
    libs['ObjectTypeLib'] = deploy_lib(ObjectTypeLib, owner)
    libs['TimestampLib'] = deploy_lib(TimestampLib, owner)
    libs['UFixedMathLib'] = deploy_lib(UFixedMathLib, owner)
    libs['VersionLib'] = deploy_lib(VersionLib, owner)
    libs['VersionPartLib'] = deploy_lib(VersionPartLib, owner)

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
    reg.initialize(nft, {'from': owner})

    return reg

def deploy_lib(lib_class, owner):
    lib_class.deploy({'from': owner})

def deploy_service(services, service_name, service_class, registry, owner):
    if service_name in services:
        return services

    service = service_class.deploy(registry, registry.getNftId(), {'from': owner})
    service.register()

    services[service_name] = service
    return services

def deploy_instance(registry, owner):
    instance = Instance.deploy(registry, registry.getNftId(), {'from': owner})
    instance.register()
    return instance