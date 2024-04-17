import { AddressLike, Signer, resolveAddress } from "ethers";
import { ChainNft, ChainNft__factory, IVersionable__factory, Registry, RegistryAccessManager, ReleaseManager, Registry__factory, Staking, Staking__factory, StakingManager, TokenRegistry } from "../../typechain-types";
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

    dipAddress: AddressLike;

    stakingAddress: AddressLike;
    staking: Staking;
    stakingNftId: bigint;

    // TODO cleanup
    // registryServiceManagerAddress: AddressLike;
    // registryServiceManager: RegistryServiceManager;

    // registryServiceAddress: AddressLike;
    // registryService: RegistryService;
    // registryServiceNftId: bigint;
}

export async function deployAndInitializeRegistry(owner: Signer, libraries: LibraryAddresses): Promise<RegistryAddresses> {
    logger.info("======== Starting deployment of registry ========");
    
    const { address: registryAccessManagerAddress, contract: registryAccessManagerBaseContract } = await deployContract(
        "RegistryAccessManager",
        owner,
        [],
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

    const registryAddress = await releaseManager.getRegistryAddress();
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
    await registryAccessManager.initialize(owner, owner, releaseManager, tokenRegistry);

    const initialAuthority = await registryAccessManager.authority();
    const dipAddress = "0xc719d010b63e5bbf2c0551872cd5316ed26acd83";

    const { address: stakingManagerAddress, contract: stakingManagerBaseContract, } = await deployContract(
        "StakingManager",
        owner,
        [
            initialAuthority,
            registryAddress,
            dipAddress,
        ],
        { libraries: { 
            AmountLib: libraries.amountLibAddress, 
            NftIdLib: libraries.nftIdLibAddress, 
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
        }});

    const stakingManager = stakingManagerBaseContract as StakingManager;
    const stakingAddress = await stakingManager.getStaking();
    const staking = Staking__factory.connect(stakingAddress, owner);

    await releaseManager.registerStaking(staking, owner);
    const stakingNftId = await registry["getNftId(address)"](stakingAddress);

    // TODO cleanup
    // const { address: registryServiceManagerAddress, contract: registryServiceManagerBaseContract } = await deployContract(
    //     "RegistryServiceManager",
    //     owner,
    //     [
    //         initialAuthority,
    //         registry
    //     ],
    //     {
    //         libraries: {
    //             NftIdLib: libraries.nftIdLibAddress,
    //             TimestampLib: libraries.timestampLibAddress,
    //             VersionLib: libraries.versionLibAddress,
    //             VersionPartLib: libraries.versionPartLibAddress
    //         }
    //     });
    // const registryServiceManager = registryServiceManagerBaseContract as RegistryServiceManager;

    // const registryServiceAddress = await registryServiceManager.getRegistryService();
    // const registryService = RegistryService__factory.connect(registryServiceAddress, owner);

    await releaseManager.createNextRelease();

    // logger.info(`>>>>>> (1)`);
    // const rcptReg = await executeTx(async () => await releaseManager.registerRegistryService(registryService));
    // logger.info(`>>>>>> (2)`);
    // const logReleaseCreationInfo = getFieldFromTxRcptLogs(rcptReg!, registry.interface, "LogRegistration", "nftId");

    // await registryServiceManager.linkOwnershipToServiceNft();
    // const registryServiceNftId = (logReleaseCreationInfo as unknown);

    logger.info(`RegistryAccessManager deployeqd at ${registryAccessManager}`);
    logger.info(`ReleaseManager deployed at ${releaseManager}`);
    logger.info(`Registry deployed at ${registryAddress}`);
    logger.info(`ChainNft deployed at ${chainNftAddress}`);
    logger.info(`TokenRegistry deployed at ${tokenRegistryAddress}`);

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

        dipAddress,
        stakingAddress,
        staking,
        stakingNftId,

        // TODO cleanup
        // registryServiceManagerAddress,
        // registryServiceManager,

        // registryServiceAddress,
        // registryService,
        // registryServiceNftId
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