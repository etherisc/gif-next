import { AddressLike, Signer, resolveAddress } from "ethers";
import { ChainNft, ChainNft__factory, IVersionable__factory, Registry, RegistryService, RegistryServiceManager, RegistryAccessManager, ReleaseManager, RegistryService__factory, Registry__factory, TokenRegistry } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract, verifyContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { getFieldFromTxRcptLogs, executeTx } from "./transaction";


export type RegistryAddresses = {

    registryAccessManagerAddress : AddressLike;
    registryAccessManager: RegistryAccessManager;

    releaseManagerAddress : AddressLike;
    releaseManager: ReleaseManager;

    registryAddress: AddressLike; 
    registry: Registry;
    registryNftId: bigint;

    chainNftAddress: AddressLike;
    chainNft: ChainNft;

    tokenRegistryAddress: AddressLike;
    tokenRegistry: TokenRegistry;

    registryServiceManagerAddress: AddressLike;
    registryServiceManager: RegistryServiceManager;

    registryServiceAddress: AddressLike;
    registryService: RegistryService;
    registryServiceNftId: bigint;
}

export async function deployAndInitializeRegistry(owner: Signer, libraries: LibraryAddresses): Promise<RegistryAddresses> {
    logger.info("======== Starting deployment of registry ========");
    
    const { address: registryAccessManagerAddress, contract: registryAccessManagerBaseContract } = await deployContract(
        "RegistryAccessManager",
        owner, // GIF_ADMIN_ROLE
        [owner], // GIF_MANAGER_ROLE
        {
            libraries: {
                RoleIdLib: libraries.roleIdLibAddress,
            }
        });
    const registryAccessManager = registryAccessManagerBaseContract as RegistryAccessManager;

    const { address: releaseManagerAddress, contract: releaseManagerBaseContract } = await deployContract(
        "ReleaseManager",
        owner,
        [
            registryAccessManager,
            3//initialVersion
        ], 
        {
            libraries: {
                TimestampLib: libraries.timestampLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                VersionPartLib: libraries.versionPartLibAddress
            }
        });
    const releaseManager = releaseManagerBaseContract as ReleaseManager;

    const registryAddress = await releaseManager.getRegistry();
    const registry = Registry__factory.connect(registryAddress, owner);
    const registryNftId = await registry["getNftId(address)"](registryAddress);

    const chainNftAddress = await registry.getChainNft();
    const chainNft = ChainNft__factory.connect(chainNftAddress, owner);

    const { address: tokenRegistryAddress, contract: tokenRegistryBaseContract } = await deployContract(
        "TokenRegistry",
        owner,
        undefined,
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });
    const tokenRegistry = tokenRegistryBaseContract as TokenRegistry;

    await registryAccessManager.initialize(releaseManager, tokenRegistry);

    const initialAuthority = await registryAccessManager.authority();

    const { address: registryServiceManagerAddress, contract: registryServiceManagerBaseContract } = await deployContract(
        "RegistryServiceManager",
        owner,
        [
            initialAuthority,
            registry
        ],
        {
            libraries: {
                BlocknumberLib: libraries.blockNumberLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress
            }
        });
    const registryServiceManager = registryServiceManagerBaseContract as RegistryServiceManager;

    const registryServiceAddress = await registryServiceManager.getRegistryService();
    const registryService = RegistryService__factory.connect(registryServiceAddress, owner);

    await releaseManager.createNextRelease();

    const rcptReg = await executeTx(async () => await releaseManager.registerRegistryService(registryService));
    const logReleaseCreationInfo = getFieldFromTxRcptLogs(rcptReg!, registry.interface, "LogRegistration", "nftId");

    const registryServiceNftId = (logReleaseCreationInfo as unknown);

    //await registryServiceManager.linkToNftOwnable(registryAddress);
    //await tokenRegistry.linkToNftOwnable(registryAddress);

    logger.info(`RegistryAccessManager deployed at ${registryAccessManager}`);
    logger.info(`ReleaseManager deployed at ${releaseManager}`);
    logger.info(`Registry deployed at ${registryAddress}`);
    logger.info(`ChainNft deployed at ${chainNftAddress}`);
    logger.info(`TokenRegistry deployed at ${tokenRegistryAddress}`);
    logger.info(`RegistryServiceManager deployed at ${registryServiceManager}`);
    logger.info(`RegistryService deployed at ${registryServiceAddress}`);

    const regAdr = {
        registryAccessManagerAddress,
        registryAccessManager,
    
        releaseManagerAddress,
        releaseManager,
    
        registryAddress,
        registry,
        registryNftId,
    
        chainNftAddress,
        chainNft,
    
        tokenRegistryAddress,
        tokenRegistry,
    
        registryServiceManagerAddress,
        registryServiceManager,
    
        registryServiceAddress,
        registryService,
        registryServiceNftId
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