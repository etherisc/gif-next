import { AddressLike, Signer, ethers, resolveAddress } from "ethers";
import { BundleManager, IRegistry__factory, Instance, InstanceAdmin, InstanceService__factory, InstanceReader, AccessManagerExtendedInitializeable, InstanceStore, TimestampLib__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { executeTx, getFieldFromLogs, getFieldFromTxRcptLogs } from "./transaction";
import { ServiceAddresses } from "./services";

export type InstanceAddresses = {
    accessManagerAddress: AddressLike,
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

    const { address: accessManagerAddress, contract: accessManagerBaseContract } = await deployContract(
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
        owner,
        undefined,
        { 
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress, 
                RoleIdLib: libraries.roleIdLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        }
    );
    const instance = masterInstanceBaseContract as Instance;
    await executeTx(() => instance.initialize(accessManagerAddress, registry.registryAddress, resolveAddress(owner)));

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
                ReferralLib: libraries.referralLibAddress,
                RequestIdLib: libraries.requestIdLibAddress,
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
                ObjectTypeLib: libraries.objectTypeLibAddress,
                PayoutIdLib: libraries.payoutIdLibAddress,
                ReferralLib: libraries.referralLibAddress,
                RequestIdLib: libraries.requestIdLibAddress,
                RiskIdLib: libraries.riskIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
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

    const { address: instanceAdminAddress, contract: instanceAdminBaseContract } = await deployContract(
        "InstanceAdmin",
        owner,
        [],
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
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
        accessManagerAddress: accessManagerAddress,
        instanceAdminAddress: instanceAdminAddress,
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
    const clonedInstanceAdminAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstanceAdmin");
    const clonedInstanceAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstance");
    const clonedBundleManagerAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedBundleManager");
    const clonedInstanceReaderAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstanceReader");
    const clonedInstanceNftId = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstanceNftId");
    
    logger.info(`instance cloned - clonedInstanceNftId: ${clonedInstanceNftId}`);

    logger.info("======== Finished cloning of instance ========");
    
    return {
        accessManagerAddress: clonedOzAccessManagerAddress,
        instanceAdminAddress: clonedInstanceAdminAddress,
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