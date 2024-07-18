import { AddressLike, Signer, resolveAddress } from "ethers";
import {
    ChainNft, ChainNft__factory,
    Dip,
    Registry,
    RegistryAdmin,
    ReleaseRegistry,
    ServiceAuthorizationV3,
    Staking, StakingManager,
    StakingReader,
    StakingStore,
    Staking__factory,
    TokenRegistry
} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { executeTx, getTxOpts } from "./transaction";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import { ethers as hhEthers } from "hardhat";
import { prepareVerificationData } from "./verification";


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

    releaseRegistryAddress : AddressLike;
    releaseRegistry: ReleaseRegistry;

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
    // const dipMainnetAddress = "0xc719d010b63e5bbf2c0551872cd5316ed26acd83";


    logger.info("-------- Starting deployment Registry Admin ----------------");

    const { address: registryAdminAddress, contract: registryAdminBaseContract } = await deployContract(
        "RegistryAdmin",
        owner, // GIF_ADMIN_ROLE
        [], 
        {
            libraries: {
                ObjectTypeLib: libraries.objectTypeLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                SelectorLib: libraries.selectorLibAddress,
                SelectorSetLib: libraries.selectorSetLibAddress,
                StrLib: libraries.strLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const registryAdmin = registryAdminBaseContract as RegistryAdmin;

    logger.info("-------- Starting deployment Registry ----------------");

    const globalRegistryAddress = `0x09635F643e140090A9A8Dcd712eD6285858ceBef`;
    const { address: registryAddress, contract: registryBaseContract } = await deployContract(
        "Registry",
        owner, // GIF_ADMIN_ROLE
        [registryAdminAddress, globalRegistryAddress], 
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const registry = registryBaseContract as Registry;
    const registryNftId = await registry["getNftId(address)"](registryAddress);

    const chainNftAddress = await registry.getChainNftAddress();
    const chainNft = ChainNft__factory.connect(chainNftAddress, owner);

    logger.info("-------- Starting deployment Release Manager ----------------");

    const { address: releaseRegistryAddress, contract: releaseRegistryBaseContract } = await deployContract(
        "ReleaseRegistry",
        owner,
        [registryAddress], 
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
                StateIdLib: libraries.stateIdLibAddress
            }
        });

    const releaseRegistry = releaseRegistryBaseContract as ReleaseRegistry;

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
        [registryAddress],
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
            }
        });

    const stakingReader = stakingReaderBaseContract as StakingReader;

    logger.info("-------- Starting deployment Staking Store ----------------");

    const { address: stakingStoreAddress, contract: stakingStoreBaseContract, } = await deployContract(
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

    const stakingStore = stakingStoreBaseContract as StakingStore;

    logger.info("-------- Starting deployment Staking Manager ----------------");

    const { address: stakingManagerAddress, contract: stakingManagerBaseContract, } = await deployContract(
        "StakingManager",
        owner,
        [
            registryAddress,
            tokenRegistryAddress,
            stakingStoreAddress,
            await resolveAddress(owner)
        ],
        { 
            libraries: { 
                AmountLib: libraries.amountLibAddress, 
                NftIdLib: libraries.nftIdLibAddress, 
                StakeManagerLib: libraries.stakeManagerLibAddress, 
                TargetManagerLib: libraries.targetManagerLibAddress, 
                TimestampLib: libraries.timestampLibAddress,
                TokenHandlerDeployerLib: libraries.tokenHandlerDeployerLibAddress,
                VersionLib: libraries.versionLibAddress,
            }
        });

    const stakingManager = stakingManagerBaseContract as StakingManager;

    const stakingAddress = await stakingManager.getStaking();
    const staking = Staking__factory.connect(stakingAddress, owner);
    const stakingNftId = await registry["getNftId(address)"](stakingAddress);

    // verify service implementation 
    prepareVerificationData(
        "Staking", 
        await getImplementationAddress(hhEthers.provider, await stakingManager.getProxy()), 
        [], 
        undefined);

    await executeTx(
        async () => await stakingReader.initialize(stakingAddress, stakingStoreAddress, getTxOpts()),
        "stakingReader.initialize"
    );

    await executeTx(
        async () => await registry.initialize(releaseRegistryAddress, tokenRegistryAddress, stakingAddress, getTxOpts()),
        "registry.initialize"
    );

    await executeTx(
        async () => await registryAdmin.completeSetup(registry, owner, owner, getTxOpts()),
        "registryAdmin.completeSetup"
    );

    await verifyRegistryComponents(
        registryAddress, 
        chainNftAddress,
        await resolveAddress(owner));

    logger.info(`Dip deployed at ${dipAddress}`);
    logger.info(`RegistryAdmin deployeqd at ${registryAdmin}`);
    logger.info(`Registry deployed at ${registryAddress}`);
    logger.info(`ChainNft deployed at ${chainNftAddress}`);
    logger.info(`ReleaseRegistry deployed at ${releaseRegistry}`);
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
                TimestampLib: libraries.timestampLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        },
        "contracts/registry/ServiceAuthorizationV3.sol:ServiceAuthorizationV3");

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

        releaseRegistryAddress: releaseRegistryAddress,
        releaseRegistry: releaseRegistry,

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

async function verifyRegistryComponents(
    registryAddress: AddressLike, 
    chainNftAddress: AddressLike, 
    owner: AddressLike) 
{
    if (process.env.SKIP_VERIFICATION?.toLowerCase() === "true") {
        return;
    }

    logger.info("Verifying additional registry components");

    logger.debug("Verifying registry");
    await prepareVerificationData("Registry", registryAddress, [owner, 3], undefined);
    
    logger.debug("Verifying chainNft");
    await prepareVerificationData("ChainNft", chainNftAddress, [registryAddress], undefined);
    
    logger.info("Additional registry components verified");
}
