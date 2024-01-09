import { AddressLike, Signer, resolveAddress } from "ethers";
import { ChainNft, ChainNft__factory, IVersionable__factory, Registry, RegistryService, RegistryServiceManager, RegistryService__factory, Registry__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract, verifyContract } from "./deployment";
import { LibraryAddresses } from "./libraries";


export type RegistryAddresses = {
    registryServiceManagerAddress: AddressLike;
    registryServiceManager: RegistryServiceManager;

    registryAddress: AddressLike; 
    registry: Registry;

    registryServiceAddress: AddressLike;
    registryService: RegistryService;

    chainNftAddress: AddressLike;
    chainNft: ChainNft;
}

export async function deployAndInitializeRegistry(owner: Signer, libraries: LibraryAddresses): Promise<RegistryAddresses> {
    const { address: accessManagerAddress } = await deployContract(
        "AccessManager",
        owner,
        [owner],
        {
        });

        const { address: registryServiceManagerAddress, contract: registryServiceManagerBaseContract } = await deployContract(
            "RegistryServiceManager",
            owner,
            [accessManagerAddress],
            {
                libraries: {
                    NftIdLib: libraries.nftIdLibAddress,
                    ObjectTypeLib: libraries.objectTypeLibAddress,
                    VersionLib: libraries.versionLibAddress,
                    VersionPartLib: libraries.versionPartLibAddress,
                    ContractDeployerLib: libraries.contractDeployerLibAddress,
                    BlocknumberLib: libraries.blockNumberLibAddress,
                }
            });
        const registryServiceManager = registryServiceManagerBaseContract as RegistryServiceManager;

    const registryServiceAddress = await registryServiceManager.getRegistryService();
    const registryService = RegistryService__factory.connect(registryServiceAddress, owner);

    const registryAddress = await registryService.getRegistry();
    const registry = Registry__factory.connect(registryAddress, owner);

    const chainNftAddress = await registry.getChainNft();
    const chainNft = ChainNft__factory.connect(chainNftAddress, owner);

    logger.info(`RegistryService deployed at ${registryServiceAddress}`);
    logger.info(`Registry deployed at ${registryAddress}`);
    logger.info(`ChainNft deployed at ${chainNftAddress}`);

    const regAdr = {
        registryServiceManagerAddress,
        registryServiceManager,
        
        registryAddress,
        registry,

        registryServiceAddress,
        registryService,

        chainNftAddress,
        chainNft
    } as RegistryAddresses;

    await verifyRegistryComponents(regAdr, owner)

    return regAdr;
}

async function verifyRegistryComponents(registryAddress: RegistryAddresses, owner: Signer) {
    if (process.env.SKIP_VERIFICATION?.toLowerCase() === "true") {
        return;
    }

    logger.info("Verifying additional registry components");

    logger.debug("Verifying registry");
    await verifyContract(registryAddress.registryAddress, [await owner.getAddress(), 3], undefined);
    
    logger.debug("Verifying chainNft");
    await verifyContract(registryAddress.chainNftAddress, [registryAddress.registryAddress], undefined);
    
    logger.debug("Verifying registryService");
    const [registryServiceImplenenationAddress] = await getImplementationAddress(registryAddress.registryServiceAddress, owner);
    // const registryCreationCode = abiRegistry.bytecode;

    // const proxyManager = ProxyManager__factory.connect(await resolveAddress(registryAddress.registryServiceAddress), owner);
    // const initData = await proxyManager.getDeployData(
    //     registryServiceImplenenationAddress, await owner.getAddress(), registryCreationCode);
    await verifyContract(
        registryServiceImplenenationAddress, 
        [], 
        undefined);
    
    logger.info("Additional registry components verified");
}

async function getImplementationAddress(proxyAddress: AddressLike, owner: Signer): Promise<[string, string]> {
    const versionable = IVersionable__factory.connect(await resolveAddress(proxyAddress), owner);
    const version = await versionable["getVersion()"]();
    const versonInfo = await versionable.getVersionInfo(version);
    const implementationAddress = versonInfo.implementation;
    const activatedBy = versonInfo.activatedBy;
    logger.debug(implementationAddress);
    logger.debug(activatedBy);
    return [implementationAddress, activatedBy];
}