import { AddressLike, BaseContract, Contract, Signer, resolveAddress } from "ethers";
import { ethers as hhEthers } from "hardhat";
import {
    ChainNft, ChainNft__factory,
    Dip,
    Registry,
    RegistryAdmin,
    RegistryAuthorization,
    ReleaseRegistry,
    ServiceAuthorizationV3,
    Staking, StakingManager,
    StakingReader,
    StakingStore,
    TargetHandler,
    Staking__factory,
    TokenRegistry,
    Dip__factory
} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract, deployProxyManagerContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { executeTx, getTxOpts } from "./transaction";
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

    registryAuthorizationAddress : AddressLike;
    registryAuthorization: RegistryAuthorization;

    releaseRegistryAddress : AddressLike;
    releaseRegistry: ReleaseRegistry;

    tokenRegistryAddress: AddressLike;
    tokenRegistry: TokenRegistry;

    stakingReaderAddress: AddressLike;
    stakingReader: StakingReader;

    stakingStoreAddress: AddressLike;
    stakingStore: StakingStore;

    targetHandlerAddress: AddressLike;
    targetHandler: TargetHandler;

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

    
    const COMMIT_HASH = "1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a";

    const existingDipAddress = process.env.DIP_ADDRESS;
    let dipAddress: AddressLike;
    let dipBaseContract: BaseContract;

    if (existingDipAddress) {
        logger.info(`-------- Using existing Dip @ ${existingDipAddress} ----------------`);
        dipAddress = existingDipAddress;
        dipBaseContract = Dip__factory.connect(dipAddress, owner);
    } else {
        logger.info("-------- Starting deployment Dip ----------------");
        const { address: deployedDipAddress, contract: newDipBaseContract } = await deployContract(
            "Dip",
            owner, // GIF_ADMIN_ROLE
            [], 
            {
                libraries: {
                }
            });
        dipAddress = deployedDipAddress;
        dipBaseContract = newDipBaseContract!;
    }

    const dip = dipBaseContract as Dip;
    
    logger.info("-------- Starting deployment RegistryAuthorization ----------------");

    const { address: registryAuthorizationAddress, contract: registryAuthorizationBaseContract } = await deployContract(
        "RegistryAuthorization",
        owner,
        [
            COMMIT_HASH,
        ],
        {
            libraries: {
                AccessAdminLib: libraries.accessAdminLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                SelectorLib: libraries.selectorLibAddress,
                StrLib: libraries.strLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const registryAuthorization = registryAuthorizationBaseContract as RegistryAuthorization;

    logger.info("-------- Starting deployment RegistryAdmin ----------------");

    const { address: registryAdminAddress, contract: registryAdminBaseContract } = await deployContract(
        "RegistryAdmin",
        owner, // GIF_ADMIN_ROLE
        [], 
        {
            libraries: {
                AccessAdminLib: libraries.accessAdminLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress,
                ContractLib: libraries.contractLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                SelectorSetLib: libraries.selectorSetLibAddress,
                StrLib: libraries.strLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const registryAdmin = registryAdminBaseContract as RegistryAdmin;

    logger.info("-------- Starting deployment Registry ----------------");

    const globalRegistry = "0xc719d010b63e5bbf2c0551872cd5316ed26acd83";
    const { address: registryAddress, contract: registryBaseContract } = await deployContract(
        "Registry",
        owner, // GIF_ADMIN_ROLE
        [registryAdminAddress, globalRegistry], 
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const registry = registryBaseContract as Registry;
    const registryNftId = await registry.getNftIdForAddress(registryAddress);

    const chainNftAddress = await registry.getChainNftAddress();
    const chainNft = ChainNft__factory.connect(chainNftAddress, owner);

    logger.info("-------- Starting deployment ReleaseRegistry ----------------");

    const { address: releaseRegistryAddress, contract: releaseRegistryBaseContract } = await deployContract(
        "ReleaseRegistry",
        owner,
        [registryAddress], 
        {
            libraries: {
                AccessAdminLib: libraries.accessAdminLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress,
                ContractLib: libraries.contractLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                SelectorSetLib: libraries.selectorSetLibAddress,
                StateIdLib: libraries.stateIdLibAddress,
                StrLib: libraries.strLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const releaseRegistry = releaseRegistryBaseContract as ReleaseRegistry;

    logger.info("-------- Starting deployment TokenRegistry ----------------");

    const { address: tokenRegistryAddress, contract: tokenRegistryBaseContract } = await deployContract(
        "TokenRegistry",
        owner,
        [
            registryAddress,
            dipAddress//dipMainnetAddress
        ],
        {
            libraries: {
                ChainIdLib: libraries.chainIdLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const tokenRegistry = tokenRegistryBaseContract as TokenRegistry;

    logger.info("-------- Starting deployment StakingReader ----------------");

    const { address: stakingReaderAddress, contract: stakingReaderBaseContract } = await deployContract(
        "StakingReader",
        owner,
        [registryAddress],
        {
            libraries: {
            }
        });

    const stakingReader = stakingReaderBaseContract as StakingReader;

    logger.info("-------- Starting deployment StakingStore ----------------");

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
                ChainIdLib: libraries.chainIdLibAddress, 
                LibNftIdSet: libraries.libNftIdSetAddress,
                NftIdLib: libraries.nftIdLibAddress, 
                ObjectTypeLib: libraries.objectTypeLibAddress, 
                SecondsLib: libraries.secondsLibAddress, 
                StakingLib: libraries.stakingLibAddress, 
                TargetManagerLib: libraries.targetManagerLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
            }
        });

    const stakingStore = stakingStoreBaseContract as StakingStore;

    logger.info("-------- Starting deployment TargetHandler ----------------");

    const { address: targetHandlerAddress, contract: targetHandlerBaseContract, } = await deployContract(
        "TargetHandler",
        owner,
        [
            registryAddress,
            stakingStoreAddress
        ],
        {
            libraries: {
                AmountLib: libraries.amountLibAddress, 
                BlocknumberLib: libraries.blockNumberLibAddress, 
                // ChainIdLib: libraries.chainIdLibAddress, 
                // Key32Lib: libraries.key32LibAddress, 
                // NftIdLib: libraries.nftIdLibAddress, 
                // LibNftIdSet: libraries.libNftIdSetAddress,
                // SecondsLib: libraries.secondsLibAddress, 
                // StakingLib: libraries.stakingLibAddress, 
                // StateIdLib: libraries.stateIdLibAddress, 
                // TargetManagerLib: libraries.targetManagerLibAddress,
                // TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
            }
        });

    const targetHandler = targetHandlerBaseContract as TargetHandler;

    await executeTx(async () =>
        await stakingStore.initialize(targetHandlerAddress, getTxOpts()),
        "stakingstore.initialize",
        [stakingStore.interface]
    );

    logger.info("-------- Starting deployment StakingManager ----------------");

    const { address: stakingManagerAddress, contract: stakingManagerBaseContract, proxyAddress: stakingAddress } = await deployProxyManagerContract(
        "StakingManager",
        "Staking",
        owner,
        [
            registryAddress,
            targetHandlerAddress,
            stakingStoreAddress,
            tokenRegistryAddress,
            await resolveAddress(owner),
            hhEthers.ZeroHash,
        ],
        { 
            libraries: { 
                AmountLib: libraries.amountLibAddress, 
                BlocknumberLib: libraries.blockNumberLibAddress,
                ChainIdLib: libraries.chainIdLibAddress, 
                ContractLib: libraries.contractLibAddress,
                NftIdLib: libraries.nftIdLibAddress, 
                SecondsLib: libraries.secondsLibAddress, 
                StakingLib: libraries.stakingLibAddress, 
                TimestampLib: libraries.timestampLibAddress,
                TokenHandlerDeployerLib: libraries.tokenHandlerDeployerLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    const stakingManager = stakingManagerBaseContract as StakingManager;
    const staking = Staking__factory.connect(stakingAddress, owner);
    const stakingNftId = await registry.getNftIdForAddress(stakingAddress);

    await executeTx(
        async () => await stakingReader.initialize(stakingAddress, stakingStoreAddress, getTxOpts()),
        "stakingReader.initialize",
        [stakingReader.interface]
    );

    await executeTx(
        async () => await registry.initialize(releaseRegistryAddress, tokenRegistryAddress, stakingAddress, getTxOpts()),
        "registry.initialize",
        [registry.interface]
    );

    await executeTx(
        async () => await registryAdmin.completeSetup(
            registry, 
            registryAuthorization, 
            3,
            owner, 
            owner, 
            getTxOpts()),
        "registryAdmin.completeSetup",
        [registryAdmin.interface]
    );

    await verifyRegistryComponents(
        registryAddress, 
        chainNftAddress,
        await resolveAddress(owner));
    
    await prepareVerificationData(
        "TokenHandler", 
        await staking.getTokenHandler(), 
        [
            registryAddress, // reg
            stakingAddress, // compo
            dipAddress, // token
            await registryAdmin.authority(), // authority
        ], 
        undefined);

    logger.info(`Dip deployed at ${dipAddress}`);
    logger.info(`RegistryAuthorization deployed at ${registryAuthorizationAddress}`);
    logger.info(`RegistryAdmin deployeqd at ${registryAdmin}`);
    logger.info(`Registry deployed at ${registryAddress}`);
    logger.info(`ChainNft deployed at ${chainNftAddress}`);
    logger.info(`ReleaseRegistry deployed at ${releaseRegistry}`);
    logger.info(`TokenRegistry deployed at ${tokenRegistryAddress}`);
    logger.info(`StakingReader deployed at ${stakingReaderAddress}`);
    logger.info(`StakingStore deployed at ${stakingStoreAddress}`);
    logger.info(`TargetHandler deployed at ${targetHandlerAddress}`);
    logger.info(`StakingManager deployed at ${stakingManagerAddress}`);
    logger.info(`Staking deployed at ${stakingAddress}`);


    logger.info("-------- Starting deployment ServiceAuthorizationV3 ----------------");

    const { address: serviceAuthorizationV3Address, contract: serviceAuthorizationV3BaseContract, } = await deployContract(
        "ServiceAuthorizationV3",
        owner,
        [ "a41a84af9a430ef22e00d9c4a8012ce24830e7bf" ],
        { 
            libraries: { 
                AccessAdminLib: libraries.accessAdminLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
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

        registryAuthorizationAddress: registryAuthorizationAddress,
        registryAuthorization: registryAuthorization,

        releaseRegistryAddress: releaseRegistryAddress,
        releaseRegistry: releaseRegistry,

        tokenRegistryAddress: tokenRegistryAddress,
        tokenRegistry: tokenRegistry,

        stakingReaderAddress: stakingReaderAddress,
        stakingReader: stakingReader,

        stakingStoreAddress: stakingStoreAddress,
        stakingStore: stakingStore,

        targetHandlerAddress: targetHandlerAddress,
        targetHandler: targetHandler,

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
