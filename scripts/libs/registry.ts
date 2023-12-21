import { AddressLike, Signer } from "ethers";
import { ChainNft, ChainNft__factory, Registry, RegistryService, RegistryServiceManager, RegistryService__factory, Registry__factory } from "../../typechain-types";
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

    const { contract: registryServiceManagerBaseContract } = await deployContract(
        "RegistryServiceManager",
        owner,
        undefined,
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

    return {
        registryAddress,
        registry,

        registryServiceAddress,
        registryService,

        chainNftAddress,
        chainNft
    };

}
