import { tenderly } from "hardhat";
import { AddressLike, Signer, ethers, resolveAddress } from "ethers";
import { BundleManager, IRegistry__factory, Instance, Instance__factory, InstanceAdmin, InstanceService__factory, InstanceReader, AccessManagerExtendedInitializeable, InstanceStore, TimestampLib__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { deploymentState } from "./deployment_state";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { executeTx, getFieldFromLogs, getFieldFromTxRcptLogs } from "./transaction";
import { ServiceAddresses } from "./services";

export type InstanceAddresses = {
    instanceAccessManagerAddress: AddressLike,
    instanceAdminAddress: AddressLike,
    instanceReaderAddress: AddressLike,
    instanceBundleManagerAddress: AddressLike,
    instanceStoreAddress: AddressLike,
    instanceAddress: AddressLike,
    instanceNftId: string,
}

export const MASTER_INSTANCE_OWNER = ethers.getAddress("0x0000000000000000000000000000000000000001");
    
export async function deployAndRegisterMasterInstance(
    owner: Signer, 
    libraries: LibraryAddresses,
    registry: RegistryAddresses,
    services: ServiceAddresses,
): Promise<InstanceAddresses> {
    logger.info("======== Starting deployment of master instance ========");

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
    const accessManager = accessManagerBaseContract as AccessManagerExtendedInitializeable;
    await executeTx(() => accessManager.initialize(resolveAddress(owner)));

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
    await executeTx(() => instance.initialize(instanceAccessManagerAddress, registry.registryAddress, resolveAddress(owner)));

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
    await executeTx(() => instanceStore.initialize(instanceAddress));
    await executeTx(() => instance.setInstanceStore(instanceStore));

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
    await executeTx(() => instanceReader.initialize(instanceAddress));
    await executeTx(() => instance.setInstanceReader(instanceReaderAddress));

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
    await executeTx(() => bundleManager["initialize(address)"](instanceAddress));
    await executeTx(() => instance.setBundleManager(bundleManagerAddress));

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
    await executeTx(() => accessManager.grantRole(0, instanceAdminAddress, 0));
    await executeTx(() => instanceAdmin.initialize(instanceAddress));
    await executeTx(() => instance.setInstanceAdmin(instanceAdmin));

    logger.debug(`setting master addresses into instance service and registering master instance`);
    const rcpt = await executeTx(() => services.instanceService.setAndRegisterMasterInstance(instanceAddress));
    // this extracts the ObjectInfo struct from the LogRegistration event
    const logRegistrationInfo = getFieldFromTxRcptLogs(rcpt!, registry.registry.interface, "LogRegistration", "nftId");
    // nftId is the first field of the ObjectInfo struct
    const masterInstanceNfdId = (logRegistrationInfo as unknown);

    await executeTx(() => registry.chainNft.transferFrom(resolveAddress(owner), MASTER_INSTANCE_OWNER, BigInt(masterInstanceNfdId as string)));

    // revoke admin role for master instance admin
    await executeTx(() => accessManager.revokeRole(0, instanceAdminAddress));   
    // revoke admin role for protocol owner
    await executeTx(() => accessManager.renounceRole(0, owner));

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
// if onchain state:
// then each chain must have at same predefined address with/which .... info about
// deployment script knows where to start resumable deployment 
export async function cloneInstance(instanceServiceAddress: AddressLike, instanceOwner: Signer, releaseVersion : string) : Promise<InstanceAddresses> {
    logger.info("======== Starting cloning of instance ========");

    const instanceService = InstanceService__factory.connect(await resolveAddress(instanceServiceAddress), instanceOwner);
    const instanceServiceVersion = await instanceService.getMajorVersion();
    const masterInstanceAddress = await instanceService.getMasterInstanceAddress(); 

    logger.info(`instance service address: ${instanceServiceAddress}`);
    logger.info(`instance service major version: ${instanceServiceVersion}`);
    logger.info(`master instance address: ${masterInstanceAddress}`);

    logger.debug(`------- cloning instance ${masterInstanceAddress} --------`);
    const cloneTx = await executeTx(async () => await instanceService.createInstanceClone());
    const clonedInstanceAccessManagerAddress = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedOzAccessManager");
    const clonedInstanceAdminAddress = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedInstanceAdmin") as AddressLike;
    const clonedInstanceAddress = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedInstance") as string;
    const clonedBundleManagerAddress = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedBundleManager");
    const clonedInstanceReaderAddress = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedInstanceReader");
    const clonedInstanceNftId = getFieldFromLogs(cloneTx.logs, instanceService.interface, "LogInstanceCloned", "clonedInstanceNftId");

    const clonedInstance = Instance__factory.connect(clonedInstanceAddress, instanceOwner);
    const clonedlInstanceVersion = await clonedInstance.getMajorVersion();
    const clonedInstanceOwner = await clonedInstance.getOwner();
    logger.info(`cloned instance major version: ${clonedlInstanceVersion}`);
    logger.info(`cloned instance owner: ${clonedInstanceOwner}`);
    
    logger.info("Verifying cloned instance access manager");
    const libraries = deploymentState.getLibraries("AccessManagerExtendedInitializeable");
    if(libraries === undefined) {
        throw new Error("Libraries not found in deployment state");
    }

    logger.info("Verifying cloned instance access manager");
    await tenderly.verify({
        name: "AccessManagerExtendedInitializeable",
        address: clonedInstanceAccessManagerAddress,
        libraries: {
            TimestampLib: libraries.timestampLibAddress,
        }
    });
    logger.info("Verifying cloned instance admin");
    /*await deployContract(
        "InstanceAdmin",
        owner,
        [],
        { libraries: { 
            RoleIdLib: libraries.roleIdLibAddress
    }});*/
    await tenderly.verify({
        name: "InstanceAdmin",
        address: clonedInstanceAdminAddress,
        libraries: {
            RoleIdLib: libraries.roleIdLibAddress
    }});
    logger.info("Verifying cloned instance");
    await tenderly.verify({
        name: "Instance",
        address: clonedInstanceAddress,
        libraries: {
            NftIdLib: libraries.nftIdLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
        }
    });
    logger.info("Verifying cloned instance reader");
    await tenderly.verify({
        name: "InstanceReader",
        address: clonedInstanceReaderAddress,
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
    });
    logger.info("Verifying cloned bundle manager");
    await tenderly.verify({
        name: "BundleManager",
        address: clonedBundleManagerAddress,
        libraries: {
            NftIdLib: libraries.nftIdLibAddress,
            LibNftIdSet: libraries.libNftIdSetAddress,
        }
    });

    logger.info(`instance cloned - clonedInstanceNftId: ${clonedInstanceNftId}`);

    logger.info("======== Finished cloning of instance ========");
    
    return {
        instanceAccessManagerAddress: clonedInstanceAccessManagerAddress,
        instanceAdminAddress: clonedInstanceAdminAddress,
        instanceAddress: clonedInstanceAddress,
        instanceBundleManagerAddress: clonedBundleManagerAddress,
        instanceReaderAddress: clonedInstanceReaderAddress,
        instanceNftId: clonedInstanceNftId as string,
    } as InstanceAddresses;*/
}

export async function cloneInstanceFromRegistry(registryAddress: AddressLike, instanceOwner: Signer/*, releaseVersion: string*/): Promise<InstanceAddresses> {
    const registry = IRegistry__factory.connect(await resolveAddress(registryAddress), instanceOwner);
    const instanceServiceDomain = 70;
    const instanceServiceAddress = await registry.getServiceAddress(instanceServiceDomain, "3");
    return cloneInstance(instanceServiceAddress, instanceOwner);
}