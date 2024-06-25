import { AddressLike, Signer, ethers, resolveAddress } from "ethers";
import { BundleSet, IInstance__factory, Instance, InstanceAdmin, InstanceAuthorizationV3, InstanceReader, InstanceService__factory, InstanceStore } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { ServiceAddresses } from "./services";
import { executeTx, getFieldFromLogs, getFieldFromTxRcptLogs, getTxOpts } from "./transaction";

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

    const { address: masterInstanceAuthorizationV3Address, contract: masterInstanceAuthorizationV3Contract } = await deployContract(
        "InstanceAuthorizationV3",
        owner,
        [],
        {
            libraries: {
                ObjectTypeLib: libraries.objectTypeLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                SelectorLib: libraries.selectorLibAddress,
                StrLib: libraries.strLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        }
    );
    const masterInstanceAuthorizationV3 = masterInstanceAuthorizationV3Contract as InstanceAuthorizationV3;

    const { address: masterInstanceAdminAddress, contract: masterInstanceAdminContract } = await deployContract(
        "InstanceAdmin",
        owner,
        [masterInstanceAuthorizationV3],
        {
            libraries: {
                RoleIdLib: libraries.roleIdLibAddress,
                SelectorLib: libraries.selectorLibAddress,
                SelectorSetLib: libraries.selectorSetLibAddress,
                StrLib: libraries.strLibAddress,
                TimestampLib: libraries.timestampLibAddress,
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
                NftIdLib: libraries.nftIdLibAddress,
                LibNftIdSet: libraries.libNftIdSetAddress,
            }
        }
    );
    const masterInstanceBundleSet = masterBundleSetContrat as BundleSet;

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
                ReferralLib: libraries.referralLibAddress,
                RequestIdLib: libraries.requestIdLibAddress,
                RiskIdLib: libraries.riskIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
            }
        }
    );
    const masterInstanceReader = masterInstanceReaderContract as InstanceReader;

    // await executeTx(
    //     () => masterInstanceReader.initialize(masterInstanceReaderAddress, getTxOpts()),
    //     "masterInstance instanceReader.initialize"
    // );

    const { address: masterInstanceAddress, contract: masterInstanceBaseContract } = await deployContract(
        "Instance",
        owner,
        undefined,
        { 
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        }
    );
    const masterInstance = masterInstanceBaseContract as Instance;

    await executeTx(
        () => masterInstance.initialize(
            masterInstanceAdmin,
            masterInstanceStore,
            masterInstanceBundleSet,
            masterInstanceReader,
            registry.registryAddress, 
            resolveAddress(owner),
            getTxOpts()),
        "masterInstance initialize");

    const rcpt = await executeTx(
        () => services.instanceService.setAndRegisterMasterInstance(
            masterInstanceAddress, 
            getTxOpts()),
            "masterInstance setAndRegisterMasterInstance"
        );

    // this extracts the ObjectInfo struct from the LogRegistration event
    const logRegistrationInfo = getFieldFromTxRcptLogs(rcpt!, registry.registry.interface, "LogRegistration", "nftId");
    // nftId is the first field of the ObjectInfo struct
    const masterInstanceNfdId = (logRegistrationInfo as unknown);

    await executeTx(
        () => registry.chainNft.transferFrom(
            resolveAddress(owner), 
            MASTER_INSTANCE_OWNER,
            BigInt(masterInstanceNfdId as string), 
            getTxOpts()),
        "masterInstance transfer ownership nft"
    );

    logger.info(`master instance registered - masterInstanceNftId: ${masterInstanceNfdId}`);
    logger.info(`master addresses set`);
    
    logger.info("======== Finished deployment of master instance ========");

    return {
        instanceAuthorizationV3Address: masterInstanceAuthorizationV3Address,
        instanceAdminAddress: masterInstanceAdminAddress,
        instanceReaderAddress: masterInstanceReaderAddress,
        instanceBundleSetAddress: masterInstanceBundleSetAddress,
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
            getTxOpts()),
        "instanceService createInstance"
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

