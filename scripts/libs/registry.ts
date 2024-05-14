import { AddressLike, Signer, resolveAddress } from "ethers";
import { 
    Dip,
    ChainNft, ChainNft__factory, 
    IVersionable__factory, 
    Registry, Registry__factory,
    RegistryAccessManager, 
    ReleaseManager, 
    TokenRegistry, TokenRegistry__factory,
    Staking, StakingManager, Staking__factory,
    LibNftIdSet__factory,
    RegistryAccessManager__factory, 
} from "../../typechain-types";
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
    dip: Dip;

    stakingAddress: AddressLike;
    staking: Staking;
    stakingNftId: bigint;
}

export async function deployAndInitializeRegistry(owner: Signer, libraries: LibraryAddresses): Promise<RegistryAddresses> {
    logger.info("======== Starting deployment of registry ========");

    logger.info("-------- Starting deployment DIP ----------------");

    const { address: dipAddress, contract: dipBaseContract } = await deployContract(
        "Dip",
        owner, // GIF_ADMIN_ROLE
        [], 
        {
            libraries: {
            }
        });

    const dip = dipBaseContract as Dip;
    const dipMainnetAddress = "0xc719d010b63e5bbf2c0551872cd5316ed26acd83";

    logger.info("-------- Starting deployment Registry ----------------");

    const { address: registryAddress, contract: registryBaseContract } = await deployContract(
        "Registry",
        owner, // GIF_ADMIN_ROLE
        [], 
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
            }
        });

    const registry = registryBaseContract as Registry;
    const registryNftId = await registry["getNftId(address)"](registryAddress);

    const chainNftAddress = await registry.getChainNftAddress();
    const chainNft = ChainNft__factory.connect(chainNftAddress, owner);

    logger.info("-------- Starting deployment Release Manager ----------------");

    const { address: releaseManagerAddress, contract: releaseManagerBaseContract } = await deployContract(
        "ReleaseManager",
        owner,
        [
            owner,
            owner,
            registryAddress,
        ], 
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const releaseManager = releaseManagerBaseContract as ReleaseManager;

    const registryAccessManagerAddress = await releaseManager.getRegistryAccessManager();
    const registryAccessManager = RegistryAccessManager__factory.connect(registryAccessManagerAddress, owner);

    logger.info("-------- Starting deployment Token Registry ----------------");

    const authority = await registryAccessManager.authority();
    const { address: tokenRegistryAddress, contract: tokenRegistryBaseContract } = await deployContract(
        "TokenRegistry",
        owner,
        [
            authority,
            registryAddress,
            dipAddress,
        ],
        {
            libraries: {
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const tokenRegistry = tokenRegistryBaseContract as TokenRegistry;

    await registryAccessManager.setTokenRegistry(tokenRegistryAddress);
    await registry.initialize(releaseManagerAddress, tokenRegistryAddress);

    logger.info("-------- Starting deployment Staking Store ----------------");

    const { address: stakingStoreAddress, } = await deployContract(
        "StakingStore",
        owner,
        [
            authority,
            registryAddress,
        ],
        {
            libraries: {
                AmountLib: libraries.amountLibAddress, 
                BlocknumberLib: libraries.blockNumberLibAddress, 
                Key32Lib: libraries.key32LibAddress, 
                NftIdLib: libraries.nftIdLibAddress, 
                LibNftIdSet: libraries.libNftIdSetAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress, 
                StateIdLib: libraries.stateIdLibAddress, 
                TimestampLib: libraries.timestampLibAddress,
            }
        });

    logger.info("-------- Starting deployment Staking Manager ----------------");

    const { address: stakingManagerAddress, contract: stakingManagerBaseContract, } = await deployContract(
        "StakingManager",
        owner,
        [
            registryAddress,
            stakingStoreAddress,
            owner,
        ],
        { libraries: { 
            StakeManagerLib: libraries.stakeManagerLibAddress, 
            TargetManagerLib: libraries.targetManagerLibAddress, 
            AmountLib: libraries.amountLibAddress, 
            NftIdLib: libraries.nftIdLibAddress, 
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
        }});

    const stakingManager = stakingManagerBaseContract as StakingManager;
    const stakingAddress = await stakingManager.getStaking();
    const staking = Staking__factory.connect(stakingAddress, owner);
    const stakingNftId = await registry["getNftId(address)"](stakingAddress);

    logger.info(`RegistryAccessManager deployeqd at ${registryAccessManager}`);
    logger.info(`Dip deployed at ${dipAddress}`);
    logger.info(`ChainNft deployed at ${chainNftAddress}`);
    logger.info(`Registry deployed at ${registryAddress}`);
    logger.info(`ReleaseManager deployed at ${releaseManager}`);
    logger.info(`TokenRegistry deployed at ${tokenRegistryAddress}`);
    logger.info(`StakingManager deployed at ${stakingManagerAddress}`);
    logger.info(`Staking deployed at ${stakingAddress}`);

    logger.info("======== Starting release creation ========");

    await releaseManager.createNextRelease();

    const rcptReg = await executeTx(async () => await releaseManager.registerRegistryService(registryService));
    const logReleaseCreationInfo = getFieldFromTxRcptLogs(rcptReg!, registry.interface, "LogRegistration", "nftId");

    const regAdr = {
        registryAccessManagerAddress,
        registryAccessManager,

        dipAddress,
        dip,

        releaseManagerAddress,
        releaseManager,

        registryAddress,
        registry,
        registryNftId,

        chainNftAddress,
        chainNft,

        tokenRegistryAddress,
        tokenRegistry,

        stakingManager,
        stakingManagerAddress,

        stakingAddress,
        staking,
        stakingNftId,
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