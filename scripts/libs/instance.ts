import { tenderly } from "hardhat";
import { AddressLike, Signer, ethers, resolveAddress } from "ethers";
import { BundleManager, Instance, Instance__factory, InstanceAdmin, InstanceReader, AccessManagerExtendedInitializeable, InstanceStore } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { deploymentState } from "./deployment_state";
import { LibraryAddresses } from "./libraries";
import { CoreAddresses } from "./registry";
import { executeTx, getFieldFromLogs, getFieldFromTxRcptLogs } from "./transaction";
import { ServiceAddresses } from "./services";

export type InstanceAddresses = {
    instanceAccessManagerAddress: AddressLike,
    instanceAdminAddress: AddressLike,
    instanceReaderAddress: AddressLike,
    instanceBundleManagerAddress: AddressLike,
    instanceStoreAddress: AddressLike,
    instanceAddress: AddressLike,
    instanceNftId: bigint,
}

export const MASTER_INSTANCE_OWNER = ethers.getAddress("0x0000000000000000000000000000000000000001");
    
async function tryInitializeInstanceAccessManager(instanceAccessManager: AccessManagerExtendedInitializeable, owner: AddressLike) {
    try {
        await executeTx(() => instanceAccessManager.initialize(owner));
    } catch (error) {
        logger.error(`Error initializing InstanceAccessManager at ${await instanceAccessManager.getAddress()}\n       ${error}`);
    }
}

async function _tryInitializeInstance(instance: Instance, authority: AddressLike,  registryAddress: AddressLike, owner: AddressLike) {
    try {
        await executeTx(() => instance.initialize(authority, registryAddress, owner));
    } catch (error) {
        logger.error(`Error initializing Instance at ${await instance.getAddress()}\n       ${error}`);
    }
}

async function _tryInitializeInstanceStore(instanceStore: InstanceStore, instanceAddress: AddressLike) {
    try {
        await executeTx(() => instanceStore.initialize(instanceAddress));
    } catch (error) {
        logger.error(`Error initializing InstanceStore at ${await instanceStore.getAddress()}\n       ${error}`);
    }
}

async function _tryInitializeInstanceReader(instanceReader: InstanceReader, instanceAddress: AddressLike) {
    try {
        await executeTx(() => instanceReader.initialize(instanceAddress));
    } catch (error) {
        logger.error(`Error initializing InstanceStore at ${await instanceReader.getAddress()}\n       ${error}`);
    }
}

async function _tryInitializeBundleManager(bundleManager: BundleManager, instanceAddress: AddressLike) {
    try {
        await executeTx(() => bundleManager.initialize(instanceAddress));
    } catch (error) {
        logger.error(`Error initializing InstanceStore at ${await bundleManager.getAddress()}\n       ${error}`);
    }
}

async function _trySetInstanceStore(instance: Instance, instanceStoreAddress: AddressLike) {
    try {
        await executeTx(() => instance.setInstanceStore(instanceStoreAddress));
    } catch (error) {
        logger.error(`Error setting InstanceStore at ${instanceStoreAddress} in Instance ${await instance.getAddress()}\n       ${error}`);
    }
}

async function _trySetInstanceReader(instance: Instance, instanceReaderAddress: AddressLike) {
    try {
        await executeTx(() => instance.setInstanceReader(instanceReaderAddress));
    } catch (error) {
        logger.error(`Error setting InstanceStore at ${instanceReaderAddress} in Instance ${await instance.getAddress()}\n       ${error}`);
    }
}

async function _trySetBundleManager(instance: Instance, bundleManagerAddress: AddressLike) {
    try {
        await executeTx(() => instance.setBundleManager(bundleManagerAddress));
    } catch (error) {
        logger.error(`Error setting InstanceStore at ${bundleManagerAddress} in Instance ${await instance.getAddress()}\n       ${error}`);
    }
}

export async function deployAndRegisterMasterInstance(
    owner: Signer, 
    libraries: LibraryAddresses,
    core: CoreAddresses,
    services: ServiceAddresses,
): Promise<InstanceAddresses> {

    logger.info("======== Starting deployment of master instance ========");
    deploymentState.requireDeployed("InstanceServiceProxy");

    logger.info("---------- Master instance access manager ----------");
    const { address: instanceAccessManagerAddress, contract: accessManagerBaseContract } = await deployContract(
        "InstanceAccessManager",
        "AccessManagerExtendedInitializeable",
        owner,
        [],
        {
            libraries: {
                TimestampLib: libraries.timestampLibAddress
            }
        }
    )
    const instanceAccessManager = accessManagerBaseContract as AccessManagerExtendedInitializeable;
    //await executeTx(() => instanceAccessManager.initialize(resolveAddress(owner)));
    await tryInitializeInstanceAccessManager(instanceAccessManager, owner);



    logger.info("---------- Master instance ----------");
    const { address: instanceAddress, contract: masterInstanceBaseContract } = await deployContract(
        "Instance",
        "Instance",
        owner,
        undefined,
        { 
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
            }
        }
    );
    const instance = masterInstanceBaseContract as Instance;
    //await executeTx(() => instance.initialize(instanceAccessManagerAddress, registry.registryAddress, resolveAddress(owner)));
    await _tryInitializeInstance(instance, instanceAccessManagerAddress, core.registryAddress, owner);



    logger.info("---------- Master instance store ----------");
    const { address: instanceStoreAddress, contract: masterInstanceStoreContract } = await deployContract(
        "InstanceStore",
        "InstanceStore",
        owner,
        [],
        { 
            libraries: {
                AmountLib: libraries.amountLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress,
                Key32Lib: libraries.key32LibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                RiskIdLib: libraries.riskIdLibAddress,
                StateIdLib: libraries.stateIdLibAddress,
                ClaimIdLib: libraries.claimIdLibAddress,
                DistributorTypeLib: libraries.distributorTypeLibAddress,
                PayoutIdLib: libraries.payoutIdLibAddress,
                ReferralLib: libraries.referralLibAddress
            }
        }
    );
    const instanceStore = masterInstanceStoreContract as InstanceStore;

    //await executeTx(() => instanceStore.initialize(instanceAddress));
    await _tryInitializeInstanceStore(instanceStore, instanceAddress);

    //await executeTx(() => instance.setInstanceStore(instanceStore));
    await _trySetInstanceStore(instance, instanceStoreAddress);



    logger.info("---------- Master instance reader ----------");
    const { address: instanceReaderAddress, contract: masterReaderBaseContract } = await deployContract(
        "InstanceReader",
        "InstanceReader",
        owner,
        [],
        { 
            libraries: {
                AmountLib: libraries.amountLibAddress,
                ClaimIdLib: libraries.claimIdLibAddress,
                DistributorTypeLib: libraries.distributorTypeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                PayoutIdLib: libraries.payoutIdLibAddress,
                ReferralLib: libraries.referralLibAddress,
                RiskIdLib: libraries.riskIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
            }
        }
    );
    const instanceReader = masterReaderBaseContract as InstanceReader;

    //await executeTx(() => instanceReader.initialize(instanceAddress));
    await _tryInitializeInstanceReader(instanceReader, instanceAddress);

    //await executeTx(() => instance.setInstanceReader(instanceReaderAddress));
    await _trySetInstanceReader(instance, instanceReaderAddress);



    logger.info("---------- Master instance bundle manager ----------");
    const {address: bundleManagerAddress, contract: bundleManagerBaseContrat} = await deployContract(
        "BundleManager",
        "BundleManager",
        owner,
        [],
        { 
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                LibNftIdSet: libraries.libNftIdSetAddress,
            }
        }
    );
    const bundleManager = bundleManagerBaseContrat as BundleManager;
    //await executeTx(() => bundleManager["initialize(address)"](instanceAddress));
    await _tryInitializeBundleManager(bundleManager, instanceAddress);

    //await executeTx(() => instance.setBundleManager(bundleManagerAddress));
    await _trySetBundleManager(instance, bundleManagerAddress)

    logger.info("---------- Master instance admin ----------");
    const { address: instanceAdminAddress, contract: instanceAdminBaseContract } = await deployContract(
        "InstanceAdmin",
        "InstanceAdmin",
        owner,
        [],
        {
            libraries: {
                RoleIdLib: libraries.roleIdLibAddress
            }
        }
    );
    const instanceAdmin = instanceAdminBaseContract as InstanceAdmin;
    // grant admin role to master instance admin
    try{
        await executeTx(() => instanceAccessManager.grantRole(0, instanceAdminAddress, 0));
    } catch (error) {
        logger.error(`Error granting admin role to InstanceAdmin at ${instanceAdminAddress}\n       ${error}`);
    }

    try{
        await executeTx(() => instanceAdmin.initialize(instanceAddress));
    } catch (error) {
        logger.error(`Error initializing InstanceAdmin at ${instanceAdminAddress}\n       ${error}`);
    }

    try {
        await executeTx(() => instance.setInstanceAdmin(instanceAdmin));
    } catch (error) {
        logger.error(`Error setting InstanceAdmin at ${instanceAdminAddress} in Instance ${instanceAddress}\n       ${error}`);
    }

    logger.debug(`Setting master addresses for InstanceService and registering master Instance`);
    let masterInstanceNfdId;
    try {
        const rcpt = await executeTx(() => services.instanceService.setAndRegisterMasterInstance(instanceAddress));
        // this extracts the ObjectInfo struct from the LogRegistration event
        const logRegistrationInfo = getFieldFromTxRcptLogs(rcpt!, core.registry.interface, "LogRegistration", "nftId");
        // nftId is the first field of the ObjectInfo struct
        masterInstanceNfdId = logRegistrationInfo as bigint;
    } catch(error) {
        logger.error(`Error setting and registering master instance at ${instanceAddress}\n       ${error}`);
        logger.error(`Trying to get master instance nftId from registry`);
        masterInstanceNfdId = await core.registry["getNftId(address)"](
            services.instanceService.getMasterInstanceAddress());
    }

    try{
        // transfer NFT to master instance owner
        await executeTx(() => core.chainNft.transferFrom(resolveAddress(owner), MASTER_INSTANCE_OWNER, BigInt(masterInstanceNfdId)));

        // revoke admin role from all members
        await executeTx(() => instanceAccessManager.revokeRole(0, instanceAdminAddress));   
        await executeTx(() => instanceAccessManager.renounceRole(0, owner));
    } catch(error) {
        logger.error(`Error transferring NFT to master instance owner\n       ${error}`);
    }

    logger.info(`master instance registered - masterInstanceNftId: ${masterInstanceNfdId}`);
    logger.info(`master addresses set`);
    
    logger.info("======== Finished deployment of master instance ========");

    return {
        instanceAccessManagerAddress: instanceAccessManagerAddress,
        instanceAdminAddress: instanceAdminAddress,
        instanceReaderAddress: instanceReaderAddress,
        instanceBundleManagerAddress: bundleManagerAddress,
        instanceStoreAddress: instanceStoreAddress,
        instanceAddress: instanceAddress,
        instanceNftId: masterInstanceNfdId,
    } as InstanceAddresses;
}

// !!! TODO in addition: DO NOT DEPLOY WHOLE FRAMEWORK EACH TIME, RESUME DEPLOYMENT BASED ON DEPLOYMENT STATE OR ONCHAIN STATE
// if onchain state use for resumable deployment:
// then each chain must have at same predefined address with/which .... info about
// deployment script knows where to start resumable deployment 
// can receive release object and extract instance service from there
export async function cloneInstance(
    instanceOwner: Signer,     
    services: ServiceAddresses,
) : Promise<InstanceAddresses> {
    logger.info("======== Starting cloning of instance ========");

    const instanceService = services.instanceService.connect(instanceOwner);
    const instanceServiceAddress = services.instanceServiceAddress;
    const instanceServiceVersion = await instanceService.getMajorVersion();
    const instanceServiceOwner = await instanceService.getOwner();
    const masterInstanceAddress = await instanceService.getMasterInstanceAddress(); 

    logger.info(`instance service address: ${instanceServiceAddress}`);
    logger.info(`instance service major version: ${instanceServiceVersion}`);
    logger.info(`instance service owner: ${instanceServiceOwner}`);
    logger.info(`master instance address: ${masterInstanceAddress}`);

    logger.debug(`------- cloning instance ${masterInstanceAddress} --------`);
    const cloneTx = await executeTx(async () => await instanceService.createInstanceClone());
    // get whole InstanceAddresses object in one call..?
    const clonedInstanceAccessManagerAddress = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedInstanceAccessManager");
    const clonedInstanceAdminAddress = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedInstanceAdmin") as AddressLike;
    const clonedInstanceAddress = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedInstance") as string;
    const clonedInstanceStoreAddress = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedInstanceStore") as string;
    const clonedBundleManagerAddress = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedBundleManager");
    const clonedInstanceReaderAddress = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedInstanceReader");
    const clonedInstanceNftId = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedInstanceNftId");

    const clonedInstance = Instance__factory.connect(clonedInstanceAddress, instanceOwner);
    const clonedlInstanceVersion = await clonedInstance.getMajorVersion();
    const clonedInstanceOwner = await clonedInstance.getOwner();
    
    logger.info(`cloned instance address: ${clonedInstanceAddress}`);
    logger.info(`cloned instance major version: ${clonedlInstanceVersion}`);
    logger.info(`cloned instance initial owner: ${clonedInstanceOwner}`);
    logger.info(`cloned instance nftId: ${clonedInstanceNftId}`);

    logger.info("======== Finished cloning of instance ========");
    
    return {
        instanceAccessManagerAddress: clonedInstanceAccessManagerAddress,
        instanceAdminAddress: clonedInstanceAdminAddress,
        instanceAddress: clonedInstanceAddress,
        instanceStoreAddress: clonedInstanceStoreAddress,
        instanceBundleManagerAddress: clonedBundleManagerAddress,
        instanceReaderAddress: clonedInstanceReaderAddress,
        instanceNftId: clonedInstanceNftId,
    } as InstanceAddresses;
}

export async function verifyInstance(instanceAddresses: InstanceAddresses, libraries: LibraryAddresses) {
    const { 
        instanceAccessManagerAddress,
        instanceAdminAddress,
        instanceAddress,
        instanceStoreAddress,
        instanceBundleManagerAddress,
        instanceReaderAddress,
        instanceNftId
    } = instanceAddresses;

    // move all verifications into separate function used here and in master instance verification
    /*logger.info("Verifying cloned instance access manager");
    const libraries = deploymentState.getLibraries("AccessManagerExtendedInitializeable");
    if(libraries === undefined) {
        throw new Error("Libraries not found in deployment state");
    }*/

    logger.info("Verifying cloned instance access manager");
    /*verifyDeployedContract(
        "InstanceAccessMnager",
        "AccessManagerExtendedInitializeable"// contractType - minimal proxy
        instanceAccessManagerAddress, 
        tx: TransactionResponse, 
        constructorArgs?: any[] | undefined, 
        sourceFileContract?: string
    );*/
    /*await tenderly.verify({
        name: "InstanceAccessMnager",
        address: instanceAccessManagerAddress,
        libraries: {
            TimestampLib: libraries.timestampLibAddress,
        }
    });

    logger.info("Verifying cloned instance admin");
    await tenderly.verify({
        name: "InstanceAdmin",
        address: instanceAdminAddress,
        libraries: {
            RoleIdLib: libraries.roleIdLibAddress
    }});

    logger.info("Verifying cloned instance");
    await tenderly.verify({
        name: "Instance",
        address: instanceAddress,
        libraries: {
            NftIdLib: libraries.nftIdLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
        }
    });

    logger.info("Verify cloned instance store");
    await tenderly.verify({
        name: "InstanceStore",
        address: instanceStoreAddress,
        libraries: {
            AmountLib: libraries.amountLibAddress,
            BlocknumberLib: libraries.blockNumberLibAddress,
            Key32Lib: libraries.key32LibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            ObjectTypeLib: libraries.objectTypeLibAddress,
            RiskIdLib: libraries.riskIdLibAddress,
            StateIdLib: libraries.stateIdLibAddress,
            ClaimIdLib: libraries.claimIdLibAddress,
            DistributorTypeLib: libraries.distributorTypeLibAddress,
            PayoutIdLib: libraries.payoutIdLibAddress,
            ReferralLib: libraries.referralLibAddress
        }
    });

    logger.info("Verifying cloned instance reader");
    await tenderly.verify({
        name: "InstanceReader",
        address: instanceReaderAddress,
        libraries: {
            AmountLib: libraries.amountLibAddress,
            ClaimIdLib: libraries.claimId
        }
    });

    logger.info("Verifying cloned bundle manager");
    await tenderly.verify({
        name: "BundleManager",
        address: instanceBundleManagerAddress,
        libraries: {
            NftIdLib: libraries.nftIdLibAddress,
            LibNftIdSet: libraries.libNftIdSetAddress,
        }
    });
    */
}
export async function cloneInstanceFromRegistry(instanceOwner: Signer, core: CoreAddresses, services: ServiceAddresses): Promise<InstanceAddresses> {
    const registry = core.registry.connect();// read only
    const instanceServiceDomain = 70;
    services.instanceServiceAddress = await registry.getServiceAddress(instanceServiceDomain, "3");
    return cloneInstance(instanceOwner, services);
}