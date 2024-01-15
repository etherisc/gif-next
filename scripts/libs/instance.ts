import { AddressLike, Signer, resolveAddress } from "ethers";
import { IRegistryService__factory, InstanceService__factory } from "../../typechain-types";
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

export async function deployAndRegisterMasterInstance(
    owner: Signer, 
    libraries: LibraryAddresses,
    registry: RegistryAddresses,
    services: ServiceAddresses,
): Promise<InstanceAddresses> {
    const { address: accessManagerAddress } = await deployContract(
        "AccessManagerSimple",
        owner,
        [await resolveAddress(owner)]);

    const { address: instanceAddress } = await deployContract(
        "Instance",
        owner,
        [accessManagerAddress, registry.registryAddress, registry.registryNftId],
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

    logger.debug(`setting master addresses into instance service`);
    await executeTx(() => services.instanceService.setAccessManagerMaster(accessManagerAddress));
    await executeTx(() => services.instanceService.setInstanceMaster(instanceAddress));
    await executeTx(() => services.instanceService.setInstanceReaderMaster(instanceReaderAddress));
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


// export enum Role { POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE, PRODUCT_OWNER_ROLE }

// export async function grantRole(instanceOwner: Signer, libraries: LibraryAddresses, instance: InstanceAddresses, role: Role, beneficiary: AddressLike): Promise<void> {
//     const beneficiaryAddress = await resolveAddress(beneficiary);
//     logger.debug(`granting role ${Role[role]} to ${beneficiaryAddress}`);

//     const instanceAsInstanceOwner = Instance__factory.connect(instance.instanceAddress.toString(), instanceOwner);
//     const roleIdLib = RoleIdLib__factory.connect(libraries.roleIdLibAddress.toString(), instanceOwner);
    
//     let roleValue: string;
//     if (role === Role.POOL_OWNER_ROLE) {
//         roleValue = await roleIdLib.toRoleId("PoolOwnerRole");
//     } else if (role === Role.DISTRIBUTION_OWNER_ROLE) {
//         roleValue = await roleIdLib.toRoleId("DistributionOwnerRole");
//     } else if (role === Role.PRODUCT_OWNER_ROLE) {
//         roleValue = await roleIdLib.toRoleId("ProductOwnerRole");
//     } else {
//         throw new Error("unknown role");
//     }

//     const hasRole = await instanceAsInstanceOwner.hasRole(roleValue, beneficiaryAddress);
    
//     if (hasRole) {
//         logger.debug(`Role ${roleValue} already granted to ${beneficiaryAddress}`);
//         return;
//     }

//     await executeTx(async () => await instanceAsInstanceOwner.grantRole(roleValue, beneficiaryAddress));
//     logger.info(`Granted role ${roleValue} to ${beneficiaryAddress}`);
// }