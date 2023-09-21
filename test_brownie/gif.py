from brownie import (
    interface,
    Wei,
    Contract,
    ChainNft,
    Registry,
    Instance,
    TestProduct,
    TestPool,
    TestUsdc,
    TestFee,
    ObjectTypeLib,
    NftIdLib,
    BlocknumberLib,
    StateIdLib,
    UFixedMathLib,
    VersionLib,
    VersionPartLib 
)

libs = {}
libs_are_deployed = False

def deploy_lib(lib_class, owner):
    lib_class.deploy({'from': owner})

def deploy_libs(owner, force_deploy = False):
    global libs_are_deployed

    if not force_deploy and libs_are_deployed:
        return libs

    libs['NftIdLib'] = deploy_lib(NftIdLib, owner)
    libs['ObjectTypeLib'] = deploy_lib(ObjectTypeLib, owner)
    libs['BlocknumberLib'] = deploy_lib(BlocknumberLib, owner)
    libs['VersionLib'] = deploy_lib(VersionLib, owner)
    libs['VersionPartLib'] = deploy_lib(VersionPartLib, owner)

    libs_are_deployed = True
    return libs

def deploy_token(token_class, owner):
    return token_class.deploy({'from': owner})

def deploy_registry(owner):
    deploy_libs(owner)

    reg = Registry.deploy({'from': owner})
    nft = ChainNft.deploy(reg, {'from': owner})
    reg.initialize(nft, {'from': owner})

    return reg

def deploy_service(service_class, registry, owner):
    service = service_class.deploy(registry, registry.getNftId(), {'from': owner})
    service.register()
    return service
