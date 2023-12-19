import { AddressLike, Signer } from "ethers";
import { ChainNft, ChainNft__factory, ProxyManager, Registry, RegistryInstaller, RegistryService, RegistryService__factory, Registry__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";


export type RegistryAddresses = {
    registryAddress: AddressLike; 
    registry: Registry;

    registryServiceAddress: AddressLike;
    registryService: RegistryService;

    chainNftAddress: AddressLike;
    chainNft: ChainNft;
}

export async function deployAndInitializeRegistry(owner: Signer, libraries: LibraryAddresses): Promise<RegistryAddresses> {

    const { address: proxyManagerAddress, contract: proxyManagerBaseContract } = await deployContract(
        "ProxyManager",
        owner,
        undefined,
        {
            // libraries: {
            //     VersionLib: libraries.versionLibAddress,
            //     BlocknumberLib: libraries.blockNumberLibAddress
            // }
        });
    const proxyManager = proxyManagerBaseContract as ProxyManager;

    const { address: registryServiceImplementationAddress } = await deployContract(
        "RegistryService",
        owner,
        undefined,
        {
            libraries: {
                VersionLib: libraries.versionLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress
            }
        });

    const { address: registryInstallerAddress, contract: registryInstallerBaseContract } = await deployContract(
        "RegistryInstaller",
        owner,
        [proxyManagerAddress, registryServiceImplementationAddress],
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });
    const registryInstaller = registryInstallerBaseContract as RegistryInstaller;

    await proxyManager.transferOwnership(registryInstallerAddress);
    logger.info(`ProxyManager ownership transferred to ${registryInstallerAddress}`);

    await registryInstaller.installRegistryServiceWithRegistry();
    logger.info(`Registry installed`);

    const registryServiceAddress = await registryInstaller.getRegistryService();
    const registryService = RegistryService__factory.connect(registryServiceAddress, owner);

    const registryAddress = await registryService.getRegistry();
    const registry = Registry__factory.connect(registryAddress, owner);

    const chainNftAddress = await registry.getChainNft();
    const chainNft = ChainNft__factory.connect(chainNftAddress, owner);

    logger.info(`RegistryService deployed at ${registryServiceAddress}`);
    logger.info(`Registry deployed at ${registryAddress}`);
    logger.info(`ChainNft deployed at ${chainNftAddress}`);

    return {
        registryAddress,
        registry,

        registryServiceAddress,
        registryService,

        chainNftAddress,
        chainNft
    };

}
