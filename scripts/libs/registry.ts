import { AddressLike, Signer, resolveAddress } from "ethers";
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
    ServiceAuthorizationV3,
    LibNftIdSet__factory,
    RegistryAccessManager__factory, 
} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract, verifyContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { getFieldFromTxRcptLogs, executeTx } from "./transaction";


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

    serviceAuthorizationV3Address: AddressLike;
    serviceAuthorizationV3: ServiceAuthorizationV3;

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


    logger.info("-------- Starting deployment Registry Admin ----------------");

    const { address: registryAdminAddress, contract: registryAdminBaseContract } = await deployContract(
        "RegistryAdmin",
        owner, // GIF_ADMIN_ROLE
        [owner], 
        {
            libraries: {
                ObjectTypeLib: libraries.objectTypeLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                SelectorLib: libraries.selectorLibAddress,
                SelectorSetLib: libraries.selectorSetLibAddress,
                StrLib: libraries.strLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const registryAdmin = registryAdminBaseContract as RegistryAdmin;

    logger.info("-------- Starting deployment Registry ----------------");

    const { address: registryAddress, contract: registryBaseContract } = await deployContract(
        "Registry",
        owner, // GIF_ADMIN_ROLE
        [registryAdminAddress, owner], 
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
        [registryAddress], 
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
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
        owner,
        [registryAddress, owner],
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
            }
        });

    const stakingReader = stakingReaderBaseContract as StakingReader;

    logger.info("-------- Starting deployment Staking Store ----------------");

    const { address: stakingStoreAddress, } = await deployContract(
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
                TargetManagerLib: libraries.targetManagerLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
            }
        });

    const stakingStore = stakingStoreAddress as StakingStore;

    logger.info("-------- Starting deployment Staking Manager ----------------");

    const { address: stakingManagerAddress, contract: stakingManagerBaseContract, } = await deployContract(
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
    const stakingAddress = await stakingManager.getStaking();
    const staking = Staking__factory.connect(stakingAddress, owner);
    const stakingNftId = await registry["getNftId(address)"](stakingAddress);

    await stakingReader.initialize(stakingAddress, stakingStoreAddress);

    await registry.initialize(releaseManagerAddress, tokenRegistryAddress, stakingAddress);

    await registryAdmin.completeSetup(registry, owner, owner);

    await verifyRegistryComponents(registryAddress, owner)

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


    logger.info("-------- Starting deployment Service Authorization v3 ----------------");

    const { address: serviceAuthorizationV3Address, contract: serviceAuthorizationV3BaseContract, } = await deployContract(
        "ServiceAuthorizationV3",
        owner,
        [ "SomeV3CommitHash" ],
        { 
            libraries: { 
                SelectorLib: libraries.selectorLibAddress,
                StrLib: libraries.strLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const serviceAuthorizationV3 = serviceAuthorizationV3BaseContract as ServiceAuthorizationV3;

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

        serviceAuthorizationV3Address: serviceAuthorizationV3Address,
        serviceAuthorizationV3: serviceAuthorizationV3,
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