import { AddressLike, Signer } from "ethers";
import { DistributionServiceManager, InstanceService, InstanceServiceManager, InstanceService__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { getFieldFromTxRcptLogs } from "./transaction";
// import IRegistry abi

export type ServiceAddresses = {
    instanceServiceNftId: string,
    instanceServiceAddress: AddressLike,
    instanceService: InstanceService,
    instanceServiceManagerAddress: AddressLike,
    // componentOwnerServiceAddress: AddressLike,
    // componentOwnerServiceNftId: string,
    distributionServiceAddress: AddressLike,
    distributionServiceNftId: string,
    distributionService: InstanceService,
    distributionServiceManagerAddress: AddressLike,
    // productServiceAddress: AddressLike,
    // productServiceNftId: string,
    // poolServiceAddress: AddressLike,
    // poolServiceNftId: string,
}

export async function deployAndRegisterServices(owner: Signer, registry: RegistryAddresses, libraries: LibraryAddresses): Promise<ServiceAddresses> {
    const { address: instanceServiceManagerAddress, contract: instanceServiceManagerBaseContract, deploymentReceipt: ismDplRcpt } = await deployContract(
        "InstanceServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: { 
            BlocknumberLib: libraries.blockNumberLibAddress, 
            NftIdLib: libraries.nftIdLibAddress, 
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
        }});

    const instanceServiceManager = instanceServiceManagerBaseContract as InstanceServiceManager;
    const instanceServiceAddress = await instanceServiceManager.getInstanceService();
    const logRegistrationInfo = getFieldFromTxRcptLogs(ismDplRcpt!, registry.registry.interface, "LogRegistration", "info");
    const instanceServiceNfdId = (logRegistrationInfo as unknown[])[0];
    const instanceService = InstanceService__factory.connect(instanceServiceAddress, owner);
    logger.info(`instanceServiceManager deployed - instanceServiceAddress: ${instanceServiceAddress} instanceServiceManagerAddress: ${instanceServiceManagerAddress} nftId: ${instanceServiceNfdId}`);


    const { address: distributionServiceManagerAddress, contract: distributionServiceManagerBaseContract, deploymentReceipt: dsmDplRcpt } = await deployContract(
        "DistributionServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress, 
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});
    
    const distributionServiceManager = distributionServiceManagerBaseContract as DistributionServiceManager;
    const distributionServiceAddress = await distributionServiceManager.getDistributionService();
    const logRegistrationInfoDs = getFieldFromTxRcptLogs(dsmDplRcpt!, registry.registry.interface, "LogRegistration", "info");
    const distributionServiceNftId = (logRegistrationInfoDs as unknown[])[0];
    const distributionService = InstanceService__factory.connect(distributionServiceAddress, owner);
    logger.info(`distributionServiceManager deployed - distributionServiceAddress: ${distributionServiceAddress} distributionServiceManagerAddress: ${distributionServiceManagerAddress} nftId: ${distributionServiceNftId}`);

    // const { address: productServiceAddress, contract: productServiceBaseContract } = await deployContract(
    //     "ProductService",
    //     owner,
    //     [registry.registryAddress, registry.registryNftId],
    //     { libraries: {
    //             NftIdLib: libraries.nftIdLibAddress,
    //             BlocknumberLib: libraries.blockNumberLibAddress, 
    //             VersionLib: libraries.versionLibAddress, 
    //             TimestampLib: libraries.timestampLibAddress,
    //             UFixedMathLib: libraries.uFixedMathLibAddress,
    //             FeeLib: libraries.feeLibAddress,
    //         }});
    // const productServiceNftId = await register(productServiceBaseContract as Registerable, productServiceAddress, "ProductService", registry, owner);
    // logger.info(`productService registered - productServiceNftId: ${productServiceNftId}`);

    // const { address: poolServiceAddress, contract: PoolServiceBaseContract } = await deployContract(
    //     "PoolService",
    //     owner,
    //     [registry.registryAddress, registry.registryNftId],
    //     { libraries: { 
    //         NftIdLib: libraries.nftIdLibAddress,
    //         BlocknumberLib: libraries.blockNumberLibAddress,
    //         VersionLib: libraries.versionLibAddress,
    //     }});
    // const poolServiceNftId = await register(PoolServiceBaseContract as Registerable, poolServiceAddress, "PoolService", registry, owner);
    // logger.info(`poolService registered - poolServiceNftId: ${poolServiceNftId}`);

    return {
        instanceServiceNftId: instanceServiceNfdId as string,
        instanceServiceAddress: instanceServiceAddress,
        instanceService: instanceService,
        instanceServiceManagerAddress: instanceServiceManagerAddress,
        // componentOwnerServiceAddress,
        // componentOwnerServiceNftId,
        distributionServiceAddress,
        distributionServiceNftId: distributionServiceNftId as string,
        distributionService,
        distributionServiceManagerAddress,
        // productServiceAddress,
        // productServiceNftId,
        // poolServiceAddress,
        // poolServiceNftId,
    };
}
