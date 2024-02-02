import { AddressLike, Signer, ethers, resolveAddress } from "ethers";
import { AccessManagerUpgradeableInitializeable, BundleManager, IRegistryService__factory, IRegistry__factory, Instance, InstanceService__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { executeTx, getFieldFromLogs, getFieldFromTxRcptLogs } from "./transaction";
import { ServiceAddresses } from "./services";

export type InstanceAddresses = {
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
    const { address: accessManagerAddress, contract: accessManagerBaseContract } = await deployContract(
        "AccessManagerUpgradeableInitializeable",
        owner,
        []);

    const accessManager = accessManagerBaseContract as AccessManagerUpgradeableInitializeable;
    await executeTx(() => accessManager.__AccessManagerUpgradeableInitializeable_init(resolveAddress(owner)));

    const { address: instanceAddress, contract: masterInstanceBaseContract } = await deployContract(
        "Instance",
        owner,
        undefined,
        { 
            libraries: {
                Key32Lib: libraries.key32LibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                RiskIdLib: libraries.riskIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                StateIdLib: libraries.stateIdLibAddress,
            }
        }
    );
    const instance = masterInstanceBaseContract as Instance;
    await executeTx(() => instance.initialize(accessManagerAddress, registry.registryAddress, registry.registryNftId, MASTER_INSTANCE_OWNER));

    // FIXME register instance in registry
    logger.debug(`registering instance ${instanceAddress} in registry ...`);
    const registryServiceAsInstanceOwner = IRegistryService__factory.connect(await resolveAddress(registry.registryServiceAddress), owner);
    const rcpt = await executeTx(async () => await registryServiceAsInstanceOwner.registerInstance(instanceAddress));
    // this extracts the ObjectInfo struct from the LogRegistration event
    const logRegistrationInfo = getFieldFromTxRcptLogs(rcpt!, registry.registry.interface, "LogRegistration", "info");
    // nftId is the first field of the ObjectInfo struct
    const masterInstanceNfdId = (logRegistrationInfo as unknown[])[0];
    
    logger.info(`instance registered - masterInstanceNftId: ${masterInstanceNfdId}`);
    // const instanceNftId = 21101;


    const { address: instanceReaderAddress } = await deployContract(
        "InstanceReader",
        owner,
        [registry.registryAddress, masterInstanceNfdId],
        { 
            libraries: {
                DistributorTypeLib: libraries.distributorTypeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ReferralLib: libraries.referralLibAddress,
                RiskIdLib: libraries.riskIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
            }
        }
    );

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
    await executeTx(() => bundleManager["initialize(address,address,uint96)"](accessManagerAddress, registry.registryAddress, BigInt(masterInstanceNfdId as string)));

    await executeTx(() => instance.setBundleManager(bundleManagerAddress));
    // revoke admin role for protocol owner
    await executeTx(() => accessManager.revokeRole(0, resolveAddress(owner)));

    logger.debug(`setting master addresses into instance service`);
    await executeTx(() => services.instanceService.setAccessManagerMaster(accessManagerAddress));
    await executeTx(() => services.instanceService.setInstanceMaster(instanceAddress));
    await executeTx(() => services.instanceService.setInstanceReaderMaster(instanceReaderAddress));
    await executeTx(() => services.instanceService.setBundleManagerMaster(bundleManagerAddress));
    logger.info(`master addresses set`);
    
    return {
        instanceAddress: instanceAddress,
        instanceNftId: masterInstanceNfdId,
    } as InstanceAddresses;
}

export async function cloneInstance(masterInstance: InstanceAddresses, libraries: LibraryAddresses, registry: RegistryAddresses, services: ServiceAddresses, instanceOwner: Signer): Promise<InstanceAddresses> {
    const instanceServiceAsClonedInstanceOwner = InstanceService__factory.connect(await resolveAddress(services.instanceServiceAddress), instanceOwner);
    logger.debug(`cloning instance ${masterInstance.instanceAddress} ...`);
    const cloneTx = await executeTx(async () => await instanceServiceAsClonedInstanceOwner.createInstanceClone());
    const clonedInstanceAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstanceAddress");
    const clonedInstanceNftId = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "clonedInstanceNftId");
    
    logger.info(`instance cloned - clonedInstanceNftId: ${clonedInstanceNftId}`);
    
    return {
        instanceAddress: clonedInstanceAddress,
        instanceNftId: clonedInstanceNftId as string,
    } as InstanceAddresses;
}

export async function cloneInstanceFromRegistry(registryAddress: AddressLike, instanceOwner: Signer): Promise<InstanceAddresses> {
    const registry = IRegistry__factory.connect(await resolveAddress(registryAddress), instanceOwner);
    const instanceServiceAddress = await registry.getServiceAddress("InstanceService", "3");
    const instanceServiceAsClonedInstanceOwner = InstanceService__factory.connect(await resolveAddress(instanceServiceAddress), instanceOwner);
    const masterInstanceAddress = await instanceServiceAsClonedInstanceOwner.getInstanceMaster();
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

