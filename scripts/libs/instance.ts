import { AddressLike, Signer, resolveAddress } from "ethers";
import { IRegistryService__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { executeTx, getFieldFromLogs } from "./transaction";

export type InstanceAddresses = {
    masterInstanceAddress: AddressLike,
    masterInstanceNftId: string,
}

export async function deployAndRegisterMasterInstance(
    owner: Signer, 
    libraries: LibraryAddresses,
    registry: RegistryAddresses,
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
    const logRegistrationInfo = getFieldFromLogs(rcpt!, registry.registry.interface, "LogRegistration", "info");
    // nftId is the first field of the ObjectInfo struct
    const masterInstanceNfdId = (logRegistrationInfo as unknown[])[0];
    
    logger.info(`instance registered - masterInstanceNftId: ${masterInstanceNfdId}`);
    // const instanceNftId = 21101;


    // FIXME: fix InstanceReader deployment (correct nftId for instance)
    // const { address: instanceReaderAddress, contract: instanceReaderBaseContract } = await deployContract(
    //     "InstanceReader",
    //     owner,
    //     [registry.registryAddress, instanceNftId],
    //     { 
    //         libraries: {
    //             DistributorTypeLib: libraries.distributorTypeLibAddress,
    //             NftIdLib: libraries.nftIdLibAddress,
    //             ReferralLib: libraries.referralLibAddress,
    //             RiskIdLib: libraries.riskIdLibAddress,
    //             TimestampLib: libraries.timestampLibAddress,
    //             UFixedMathLib: libraries.uFixedMathLibAddress,
    //         }
    //     }
    // );
    
    return {
        masterInstanceAddress: instanceAddress,
        masterInstanceNftId: masterInstanceNfdId,
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