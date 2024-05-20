import { AddressLike, Signer, TransactionResponse, resolveAddress } from "ethers";
import { 
    Dip,
    ChainNft, ChainNft__factory, 
    IVersionable__factory, 
    Registry, Registry__factory,
    RegistryAdmin, 
    ReleaseManager, 
    TokenRegistry, TokenRegistry__factory,
    Staking, StakingManager, Staking__factory,
    StakingStore, StakingReader,
    LibNftIdSet__factory,
    RegistryAccessManager__factory, 
} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract, addDeployedContract, verifyContract } from "./deployment";
import { deploymentState } from "./deployment_state";
import { LibraryAddresses } from "./libraries";
import { getFieldFromTxRcptLogs, executeTx } from "./transaction";
import { tenderly } from "hardhat";


export type RegistryAddresses = {

    dipAddress: AddressLike;
    dip: Dip;

    registryAdminAddress : AddressLike;
    registryAdmin: RegistryAdmin;

    registryAddress: AddressLike; 
    registry: Registry;
    registryNftId: bigint;

    chainNftAddress: AddressLike;
    chainNft: ChainNft;

    releaseManagerAddress : AddressLike;
    releaseManager: ReleaseManager;

    tokenRegistryAddress: AddressLike;
    tokenRegistry: TokenRegistry;

    stakingReaderAddress: AddressLike;
    stakingReader: StakingReader;

    stakingStoreAddress: AddressLike;
    stakingStore: StakingStore;

    stakingManagerAddress: AddressLike;
    stakingManager: StakingManager;

    stakingAddress: AddressLike;
    staking: Staking;
    stakingNftId: bigint;
}

export async function deployAndInitializeRegistry(owner: Signer, libraries: LibraryAddresses): Promise<RegistryAddresses> {
    logger.info("======== Starting deployment of registry ========");

    logger.info("-------- Starting deployment DIP ----------------");

    const { address: dipAddress, contract: dipBaseContract } = await deployContract(
        "Dip",
        "Dip",
        owner, // GIF_ADMIN_ROLE
        [], 
        {
            libraries: {
            }
        });

    const dip = dipBaseContract as Dip;
    const dipMainnetAddress = "0xc719d010b63e5bbf2c0551872cd5316ed26acd83";


    logger.info("-------- Starting deployment Registry Admin ----------------");

    const { 
        address: registryAdminAddress, 
        contract: registryAdminBaseContract,
        deploymentTransaction: registryAdminDeploymentTransaction 
    } = await deployContract(
        "RegistryAdmin",
        "RegistryAdmin",
        owner, // GIF_ADMIN_ROLE
        [], 
        {
            libraries: {
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
            }
        });

    const registryAdmin = registryAdminBaseContract as RegistryAdmin;
    const accessManagerAddress = await registryAdmin.authority();

    await addDeployedContract(
        "RegistryAccessManager",
        "AccessManagerExtendedInitializeable",
        accessManagerAddress,
        owner, //signer
        registryAdminDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                TimestampLib: libraries.timestampLibAddress,
            }
        });

    logger.info("-------- Starting deployment Registry ----------------");

    const { 
        address: registryAddress, 
        contract: registryBaseContract,
        deploymentTransaction: registryDeploymentTransaction 
    } = await deployContract(
        "Registry",
        "Registry",
        owner, // GIF_ADMIN_ROLE
        [registryAdminAddress], 
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
    
    await addDeployedContract(
        "ChainNft",
        "ChainNft",
        chainNftAddress,
        owner, //signer
        registryDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });
    
    logger.info("-------- Starting deployment Release Manager ----------------");

    const { address: releaseManagerAddress, contract: releaseManagerBaseContract } = await deployContract(
        "ReleaseManager",
        "ReleaseManager",
        owner,
        [registryAddress], 
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
                SecondsLib: libraries.secondsLibAddress,
            }
        });

    const releaseManager = releaseManagerBaseContract as ReleaseManager;

    logger.info("-------- Starting deployment Token Registry ----------------");

    const { address: tokenRegistryAddress, contract: tokenRegistryBaseContract } = await deployContract(
        "TokenRegistry",
        "TokenRegistry",
        owner,
        [
            registryAddress,
            dipAddress//dipMainnetAddress
        ],
        {
            libraries: {
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const tokenRegistry = tokenRegistryBaseContract as TokenRegistry;

    logger.info("-------- Starting deployment Staking Reader ----------------");

    const { address: stakingReaderAddress, contract: stakingReaderBaseContract } = await deployContract(
        "StakingReader",
        "StakingReader",
        owner,
        [registryAddress],
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
            }
        });

    const stakingReader = stakingReaderBaseContract as StakingReader;

    logger.info("-------- Starting deployment Staking Store ----------------");

    const { address: stakingStoreAddress, } = await deployContract(
        "StakingStore",
        "StakingStore",
        owner,
        [
            registryAddress,
            stakingReaderAddress
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

    const stakingStore = stakingStoreAddress as StakingStore;

    logger.info("-------- Starting deployment Staking Manager ----------------");

    const { address: stakingManagerAddress, contract: stakingManagerBaseContract, } = await deployContract(
        "StakingManager",
        "StakingManager",
        owner,
        [
            registryAddress,
            tokenRegistryAddress,
            stakingStoreAddress,
            owner
        ],
        { 
            libraries: { 
                StakeManagerLib: libraries.stakeManagerLibAddress, 
                TargetManagerLib: libraries.targetManagerLibAddress, 
                AmountLib: libraries.amountLibAddress, 
                NftIdLib: libraries.nftIdLibAddress, 
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
            }
        });

    const stakingManager = stakingManagerBaseContract as StakingManager;
    logger.info(`StakingManager deployed at ${stakingManagerAddress}`);
    const stakingAddress = await stakingManager.getStaking();
    logger.info(`Staking deployed at ${stakingAddress}`);
    const staking = Staking__factory.connect(stakingAddress, owner);

    const stakingNftId = await registry["getNftId(address)"](stakingAddress);
    logger.info(`StakingReader deployed at ${stakingReaderAddress}`);
    // revert here if resumable deployment is true -> can be already intialized
    await executeTx(async () => await stakingReader.initialize(stakingAddress, stakingStoreAddress));

    await executeTx(async () => await registry.initialize(releaseManagerAddress, tokenRegistryAddress, stakingAddress));

    await executeTx(async () =>await registryAdmin.initialize(registry, owner, owner));

    //await verifyRegistryComponents(registryAddress, owner)

    logger.info(`Dip deployed at ${dipAddress}`);
    logger.info(`RegistryAdmin deployeqd at ${registryAdmin}`);
    logger.info(`Registry deployed at ${registryAddress}`);
    logger.info(`ChainNft deployed at ${chainNftAddress}`);
    logger.info(`ReleaseManager deployed at ${releaseManager}`);
    logger.info(`TokenRegistry deployed at ${tokenRegistryAddress}`);
    logger.info(`StakingReader deployed at ${stakingReaderAddress}`);
    logger.info(`StakingStore deployed at ${stakingStoreAddress}`);
    logger.info(`StakingManager deployed at ${stakingManagerAddress}`);
    logger.info(`Staking deployed at ${stakingAddress}`);

    logger.info("protocol nftId: " + await registry._protocolNftId());
    logger.info("registry nftId: " + await registry._registryNftId());
    logger.info("staking nftId: " + await registry._stakingNftId());

    logger.info("======== Finished deployment of registry ========");

    return {
        dipAddress: dipAddress,
        dip: dip,

        registryAdminAddress: registryAdminAddress,
        registryAdmin: registryAdmin,

        registryAddress: registryAddress,
        registry: registry,
        registryNftId: registryNftId,

        chainNftAddress: chainNftAddress,
        chainNft: chainNft,

        releaseManagerAddress: releaseManagerAddress,
        releaseManager: releaseManager,

        tokenRegistryAddress: tokenRegistryAddress,
        tokenRegistry: tokenRegistry,

        stakingReaderAddress: stakingReaderAddress,
        stakingReader: stakingReader,

        stakingStoreAddress: stakingStoreAddress,
        stakingStore: stakingStore,

        stakingManager: stakingManager,
        stakingManagerAddress: stakingManagerAddress,

        stakingAddress: stakingAddress,
        staking: staking,
        stakingNftId: stakingNftId,
    };
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