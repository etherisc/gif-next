import { AddressLike, Signer, ethers, resolveAddress } from "ethers";
import { BundleManager, IRegistry__factory, Instance, InstanceAccessManager, InstanceService__factory, InstanceReader, AccessManagerUpgradeableInitializeable, InstanceStore } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { executeTx, getFieldFromLogs, getFieldFromTxRcptLogs } from "./transaction";
import { ServiceAddresses } from "./services";

export type InstanceAddresses = {
    ozAccessManagerAddress: AddressLike,
    instanceAccessManagerAddress: AddressLike,
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

    const { address: ozAccessManagerAddress, contract: ozAccessManagerBaseContract } = await deployContract(
        "AccessManagerUpgradeableInitializeable",
        owner,
        [],
        {
            libraries: {

            }
        }
    )
    const ozAccessManager = ozAccessManagerBaseContract as AccessManagerUpgradeableInitializeable;
    await executeTx(() => ozAccessManager.initialize(resolveAddress(owner)));

    const { address: instanceAddress, contract: masterInstanceBaseContract } = await deployContract(
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
    await executeTx(() => instance.initialize(ozAccessManagerAddress, registry.registryAddress, resolveAddress(owner)));

    const { address: instanceStoreAddress, contract: masterInstanceStoreContract } = await deployContract(
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

    const { address: instanceAccessManagerAddress, contract: instanceAccessManagerBaseContract } = await deployContract(
        "InstanceAccessManager",
        owner,
        [],
        {
            libraries: {
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
            }
        }
    );
    const instanceAccessManager = instanceAccessManagerBaseContract as InstanceAccessManager;
    // grant admin role to master instance access manager
    await executeTx(() => ozAccessManager.grantRole(0, instanceAccessManagerAddress, 0));
    await executeTx(() => instanceAccessManager.initialize(instanceAddress));
    await executeTx(() => instance.setInstanceAccessManager(instanceAccessManager));

    logger.debug(`setting master addresses into instance service and registering master instance`);
    const rcpt = await executeTx(() => services.instanceService.setAndRegisterMasterInstance(instanceAddress));
    // this extracts the ObjectInfo struct from the LogRegistration event
    const logRegistrationInfo = getFieldFromTxRcptLogs(rcpt!, registry.registry.interface, "LogRegistration", "nftId");
    // nftId is the first field of the ObjectInfo struct
    const masterInstanceNfdId = (logRegistrationInfo as unknown);

    await executeTx(() => registry.chainNft.transferFrom(resolveAddress(owner), MASTER_INSTANCE_OWNER, BigInt(masterInstanceNfdId as string)));

    // revoke admin role for master instance access manager
    await executeTx(() => instanceAccessManager.revokeRole(0, instanceAccessManagerAddress));   
    // revoke admin role for protocol owner
    await executeTx(() => ozAccessManager.renounceRole(0, owner));

    logger.info(`master instance registered - masterInstanceNftId: ${masterInstanceNfdId}`);
    logger.info(`master addresses set`);
    
    logger.info("======== Finished deployment of master instance ========");

    return {
        ozAccessManagerAddress: ozAccessManagerAddress,
        instanceAccessManagerAddress: instanceAccessManagerAddress,
        instanceReaderAddress: instanceReaderAddress,
        instanceBundleManagerAddress: bundleManagerAddress,
        instanceStoreAddress: instanceStoreAddress,
        instanceAddress: instanceAddress,
        instanceNftId: masterInstanceNfdId,
    } as InstanceAddresses;
}

export async function cloneInstance(masterInstance: InstanceAddresses, libraries: LibraryAddresses, registry: RegistryAddresses, services: ServiceAddresses, instanceOwner: Signer): Promise<InstanceAddresses> {
    logger.info("======== Starting cloning of instance ========");

    const instanceServiceAsClonedInstanceOwner = InstanceService__factory.connect(await resolveAddress(services.instanceServiceAddress), instanceOwner);
    logger.debug(`cloning instance ${masterInstance.instanceAddress} ...`);
    const cloneTx = await executeTx(async () => await instanceServiceAsClonedInstanceOwner.createInstanceClone());
    const clonedOzAccessManagerAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedOzAccessManager");
    const clonedInstanceAccessManagerAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstanceAccessManager");
    const clonedInstanceAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstance");
    const clonedBundleManagerAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedBundleManager");
    const clonedInstanceReaderAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstanceReader");
    const clonedInstanceNftId = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstanceNftId");
    
    logger.info(`instance cloned - clonedInstanceNftId: ${clonedInstanceNftId}`);

    logger.info("======== Finished cloning of instance ========");
    
    return {
        ozAccessManagerAddress: clonedOzAccessManagerAddress,
        instanceAccessManagerAddress: clonedInstanceAccessManagerAddress,
        instanceAddress: clonedInstanceAddress,
        instanceBundleManagerAddress: clonedBundleManagerAddress,
        instanceReaderAddress: clonedInstanceReaderAddress,
        instanceNftId: clonedInstanceNftId as string,
    } as InstanceAddresses;
}

export async function cloneInstanceFromRegistry(registryAddress: AddressLike, instanceOwner: Signer): Promise<InstanceAddresses> {
    const registry = IRegistry__factory.connect(await resolveAddress(registryAddress), instanceOwner);
    const instanceServiceAddress = await registry.getServiceAddress("InstanceService", "3");
    const instanceServiceAsClonedInstanceOwner = InstanceService__factory.connect(await resolveAddress(instanceServiceAddress), instanceOwner);
    const masterInstanceAddress = await instanceServiceAsClonedInstanceOwner.getMasterInstance();
    logger.debug(`cloning instance ${masterInstanceAddress} ...`);
    const cloneTx = await executeTx(async () => await instanceServiceAsClonedInstanceOwner.createInstanceClone());
    const clonedInstanceAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstanceAddress");
    const clonedInstanceNftId = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstanceNftId");
    
    logger.info(`instance cloned - clonedInstanceNftId: ${clonedInstanceNftId}`);
    
    return {
        instanceAddress: clonedInstanceAddress,
        instanceNftId: clonedInstanceNftId as string,
    } as InstanceAddresses;
}