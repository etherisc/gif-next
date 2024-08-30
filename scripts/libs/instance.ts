import { AddressLike, Signer, ethers, resolveAddress } from "ethers";
import {
    BundleSet,
    IInstance__factory,
    Instance,
    InstanceAdmin,
    InstanceReader,
    InstanceService__factory,
    InstanceStore,
    RiskSet
} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { ServiceAddresses } from "./services";
import { executeTx, getFieldFromLogs, getFieldFromTxRcptLogs, getTxOpts } from "./transaction";
import { prepareVerificationData } from "./verification";

export type InstanceAddresses = {
    instanceAuthorizationV3Address: AddressLike,
    instanceAdminAddress: AddressLike,
    instanceReaderAddress: AddressLike,
    instanceBundleSetAddress: AddressLike,
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

    const { address: masterInstanceAuthorizationV3Address } = await deployContract(
        "InstanceAuthorizationV3",
        owner,
        [],
        {
            libraries: {
                AccessAdminLib: libraries.accessAdminLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                SelectorLib: libraries.selectorLibAddress,
                StrLib: libraries.strLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        }
    );

    const { address: masterAccessManagerAddress, contract: masterAccessManagerBaseContract } = await deployContract(
        "AccessManagerCloneable",
        owner,
        undefined,
        { 
            libraries: {
                ContractLib: libraries.contractLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        }
    );

    const { address: masterInstanceAdminAddress, contract: masterInstanceAdminContract } = await deployContract(
        "InstanceAdmin",
        owner,
        [
            masterAccessManagerAddress
        ],
        {
            libraries: {
                AccessAdminLib: libraries.accessAdminLibAddress,
                ContractLib: libraries.contractLibAddress,
                NftIdLib: libraries.nftIdLibAddress, 
                RoleIdLib: libraries.roleIdLibAddress,
                SelectorLib: libraries.selectorLibAddress,
                SelectorSetLib: libraries.selectorSetLibAddress,
                StrLib: libraries.strLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionPartLib: libraries.versionPartLibAddress
            }
        }
    );
    const masterInstanceAdmin = masterInstanceAdminContract as InstanceAdmin;

    const { address: masterInstanceStoreAddress, contract: masterInstanceStoreContract } = await deployContract(
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
    const masterInstanceStore = masterInstanceStoreContract as InstanceStore;

    const {address: masterInstanceBundleSetAddress, contract: masterBundleSetContrat} = await deployContract(
        "BundleSet",
        owner,
        [],
        { 
            libraries: {
                Key32Lib: libraries.key32LibAddress,
                LibNftIdSet: libraries.libNftIdSetAddress,
                LibKey32Set: libraries.libKey32SetAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ObjectSetHelperLib: libraries.objectSetHelperLibAddress,
            }
        }
    );
    const masterInstanceBundleSet = masterBundleSetContrat as BundleSet;

    const {address: masterInstanceRiskSetAddress, contract: masterRiskSetContrat} = await deployContract(
        "RiskSet",
        owner,
        [],
        { 
            libraries: {
                Key32Lib: libraries.key32LibAddress,
                LibNftIdSet: libraries.libNftIdSetAddress,
                LibKey32Set: libraries.libKey32SetAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ObjectSetHelperLib: libraries.objectSetHelperLibAddress,
                RiskIdLib: libraries.riskIdLibAddress,
            }
        }
    );
    const masterInstanceRiskSet = masterRiskSetContrat as RiskSet;

    const { address: masterInstanceReaderAddress, contract: masterInstanceReaderContract } = await deployContract(
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
                PolicyServiceLib: libraries.policyServiceLibAddress,
                ReferralLib: libraries.referralLibAddress,
                RequestIdLib: libraries.requestIdLibAddress,
                RiskIdLib: libraries.riskIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
            }
        }
    );
    const masterInstanceReader = masterInstanceReaderContract as InstanceReader;

    const { address: masterInstanceAddress, contract: masterInstanceBaseContract } = await deployContract(
        "Instance",
        owner,
        undefined,
        { 
            libraries: {
                ContractLib: libraries.contractLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
            }
        }
    );
    const masterInstance = masterInstanceBaseContract as Instance;

    await executeTx(
        () => masterInstance.initialize(
            masterInstanceAdmin,
            masterInstanceStore,
            masterInstanceBundleSet,
            masterInstanceRiskSet,
            masterInstanceReader,
            registry.registryAddress,
            3, 
            resolveAddress(owner),
            false,
            getTxOpts()),
        "masterInstance initialize",
        [IInstance__factory.createInterface()]);

    const rcpt = await executeTx(
        () => services.instanceService.setAndRegisterMasterInstance(
            masterInstanceAddress, 
            getTxOpts()),
            "masterInstance setAndRegisterMasterInstance",
            [InstanceService__factory.createInterface()]
        );

    // this extracts the ObjectInfo struct from the LogRegistration event
    const logRegistrationInfo = getFieldFromTxRcptLogs(rcpt!, registry.registry.interface, "LogRegistration", "nftId");
    // nftId is the first field of the ObjectInfo struct
    const masterInstanceNfdId = (logRegistrationInfo as unknown);

    // wire instance admin to registry, instance and instance authorization
    await executeTx(
        () => masterInstanceAdmin.completeSetup(
            registry.registryAddress,
            masterInstanceAddress, 
            masterInstanceAuthorizationV3Address,
            3,
            getTxOpts()),
            "masterInstanceAdmin completeSetup",
            [masterInstanceAdmin.interface]
        );

    await executeTx(
        () => registry.chainNft.transferFrom(
            resolveAddress(owner), 
            MASTER_INSTANCE_OWNER,
            BigInt(masterInstanceNfdId as string), 
            getTxOpts()),
        "masterInstance transfer ownership nft",
        [registry.chainNft.interface]
    );

    logger.info(`master instance registered - masterInstanceNftId: ${masterInstanceNfdId}`);
    logger.info(`master addresses set`);
    
    logger.info("======== Finished deployment of master instance ========");

    return {
        instanceAuthorizationV3Address: masterInstanceAuthorizationV3Address,
        instanceAdminAddress: masterInstanceAdminAddress,
        instanceReaderAddress: masterInstanceReaderAddress,
        instanceBundleSetAddress: masterInstanceBundleSetAddress,
        instanceRiskSetAddress: masterInstanceRiskSetAddress,
        instanceStoreAddress: masterInstanceStoreAddress,
        instanceAddress: masterInstanceAddress,
        instanceNftId: masterInstanceNfdId,
    } as InstanceAddresses;
}

export async function cloneInstance(masterInstance: InstanceAddresses, libraries: LibraryAddresses, registry: RegistryAddresses, services: ServiceAddresses, instanceOwner: Signer): Promise<InstanceAddresses> {
    logger.info("======== Starting cloning of instance ========");

    const instanceServiceAsClonedInstanceOwner = InstanceService__factory.connect(await resolveAddress(services.instanceServiceAddress), instanceOwner);
    logger.debug(`cloning master instance ${masterInstance.instanceAddress} ...`);

    const cloneTx = await executeTx(
        async () => await instanceServiceAsClonedInstanceOwner.createInstance(
            false,
            getTxOpts()),
        "instanceService createInstance",
        [InstanceService__factory.createInterface()]
    );

    const clonedInstanceAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "instance");
    const clonedInstanceNftId = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceCloned", "instanceNftId");
    const clonedInstance = IInstance__factory.connect(clonedInstanceAddress as string, instanceOwner);
    const clonedInstanceAdminAddress = await clonedInstance.getInstanceAdmin();
    const clonedInstanceStoreAddress = await clonedInstance.getInstanceStore();
    const clonedInstanceBundleSetAddress = await clonedInstance.getBundleSet();
    const clonedInstanceReaderAddress = await clonedInstance.getInstanceReader();
    
    logger.info(`instance cloned - clonedInstanceNftId: ${clonedInstanceNftId}`);

    logger.info("======== Finished cloning of instance ========");
    
    return {
        instanceAddress: clonedInstanceAddress,
        instanceNftId: clonedInstanceNftId as string,
        instanceAdminAddress: clonedInstanceAdminAddress,
        instanceReaderAddress: clonedInstanceReaderAddress,
        instanceBundleSetAddress: clonedInstanceBundleSetAddress,
        instanceStoreAddress: clonedInstanceStoreAddress,
    } as InstanceAddresses;
}

