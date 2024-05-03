import { AddressLike, Signer, resolveAddress } from "ethers";
import { ChainNft, ChainNft__factory, IVersionable__factory, Registry, registryAdmin, ReleaseManager, Registry__factory, TokenRegistry } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract, verifyContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { getFieldFromTxRcptLogs, executeTx } from "./transaction";


export type RegistryAddresses = {

    registryAdminAddress : AddressLike;
    registryAdmin: registryAdmin;

    releaseManagerAddress : AddressLike;
    releaseManager: ReleaseManager;

    registryAddress: AddressLike; 
    registry: Registry;
    registryNftId: bigint;

    chainNftAddress: AddressLike;
    chainNft: ChainNft;

    tokenRegistryAddress: AddressLike;
    tokenRegistry: TokenRegistry;
}

export async function deployAndInitializeRegistry(owner: Signer, libraries: LibraryAddresses): Promise<RegistryAddresses> {
    logger.info("======== Starting deployment of registry ========");
    
    const { address: registryAdminAddress, contract: registryAdminBaseContract } = await deployContract(
        "registryAdmin",
        owner,
        [],
        {
            libraries: {
                RoleIdLib: libraries.roleIdLibAddress,
            }
        });
    const registryAdmin = registryAdminBaseContract as registryAdmin;

    const { address: releaseManagerAddress, contract: releaseManagerBaseContract } = await deployContract(
        "ReleaseManager",
        owner,
        [
            registryAdmin,
            3 //initialVersion
        ], 
        {
            libraries: {
                TimestampLib: libraries.timestampLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
            }
        });
    const releaseManager = releaseManagerBaseContract as ReleaseManager;

    const registryAddress = await releaseManager.getRegistry();
    const registry = Registry__factory.connect(registryAddress, owner);
    const registryNftId = await registry["getNftId(address)"](registryAddress);

    const chainNftAddress = await registry.getChainNftAddress();
    const chainNft = ChainNft__factory.connect(chainNftAddress, owner);

    const { address: tokenRegistryAddress, contract: tokenRegistryBaseContract } = await deployContract(
        "TokenRegistry",
        owner,
        [registryAddress],
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });
    const tokenRegistry = tokenRegistryBaseContract as TokenRegistry;

    logger.info("Initializing registry access manager");
    await registryAdmin.initialize(owner, owner, releaseManager, tokenRegistry);

    logger.info(`registryAdmin deployeqd at ${registryAdmin}`);
    logger.info(`ReleaseManager deployed at ${releaseManager}`);
    logger.info(`Registry deployed at ${registryAddress}`);
    logger.info(`ChainNft deployed at ${chainNftAddress}`);
    logger.info(`TokenRegistry deployed at ${tokenRegistryAddress}`);

    const regAdr = {
        registryAdminAddress,
        registryAdmin,
    
        releaseManagerAddress,
        releaseManager,
    
        registryAddress,
        registry,
        registryNftId,
    
        chainNftAddress,
        chainNft,
    
        tokenRegistryAddress,
        tokenRegistry
    } as RegistryAddresses;

    await verifyRegistryComponents(regAdr, owner)

    logger.info("======== Finished deployment of registry ========");

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