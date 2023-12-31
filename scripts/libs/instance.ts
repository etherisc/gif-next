import { AddressLike, Signer, resolveAddress } from "ethers";
import { Instance__factory, Registerable } from "../../typechain-types";
import { RoleIdLib__factory } from "../../typechain-types/factories/contracts/types/RoleId.sol";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses, register } from "./registry";
import { executeTx } from "./transaction";

export type InstanceAddresses = {
    instanceAddress: AddressLike,
    instanceNftId: string,
}

export async function deployAndRegisterInstance(
    owner: Signer, 
    libraries: LibraryAddresses,
    registry: RegistryAddresses,
): Promise<InstanceAddresses> {
    const { address: instanceAddress, contract: instanceBaseContract } = await deployContract(
        "Instance",
        owner,
        [registry.registryAddress, registry.registryNftId],
        { libraries: {
            BlocknumberLib: libraries.blockNumberLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            LibNftIdSet: libraries.libNftIdSetAddress,
            TimestampLib: libraries.timestampLibAddress,
            UFixedMathLib: libraries.uFixedMathLibAddress,
            VersionLib: libraries.versionLibAddress,
            FeeLib: libraries.feeLibAddress,
            Key32Lib: libraries.key32LibAddress,
            ObjectTypeLib: libraries.objectTypeLibAddress,
            StateIdLib: libraries.stateIdLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            RiskIdLib: libraries.riskIdLibAddress,
        }});

    const instanceNftId = await register(instanceBaseContract as Registerable, instanceAddress, "Instance", registry, owner);
    logger.info(`instance registered - instanceNftId: ${instanceNftId}`);
    return {
        instanceAddress,
        instanceNftId,
    };
}


export enum Role { POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE, PRODUCT_OWNER_ROLE }

export async function grantRole(instanceOwner: Signer, libraries: LibraryAddresses, instance: InstanceAddresses, role: Role, beneficiary: AddressLike): Promise<void> {
    const beneficiaryAddress = await resolveAddress(beneficiary);
    logger.debug(`granting role ${Role[role]} to ${beneficiaryAddress}`);

    const instanceAsInstanceOwner = Instance__factory.connect(instance.instanceAddress.toString(), instanceOwner);
    const roleIdLib = RoleIdLib__factory.connect(libraries.roleIdLibAddress.toString(), instanceOwner);
    
    let roleValue: string;
    if (role === Role.POOL_OWNER_ROLE) {
        roleValue = await roleIdLib.toRoleId("PoolOwnerRole");
    } else if (role === Role.DISTRIBUTION_OWNER_ROLE) {
        roleValue = await roleIdLib.toRoleId("DistributionOwnerRole");
    } else if (role === Role.PRODUCT_OWNER_ROLE) {
        roleValue = await roleIdLib.toRoleId("ProductOwnerRole");
    } else {
        throw new Error("unknown role");
    }

    const hasRole = await instanceAsInstanceOwner.hasRole(roleValue, beneficiaryAddress);
    
    if (hasRole) {
        logger.debug(`Role ${roleValue} already granted to ${beneficiaryAddress}`);
        return;
    }

    await executeTx(async () => await instanceAsInstanceOwner.grantRole(roleValue, beneficiaryAddress));
    logger.info(`Granted role ${roleValue} to ${beneficiaryAddress}`);
}