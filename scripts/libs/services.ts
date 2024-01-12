import { AddressLike, Signer } from "ethers";
import { InstanceService, InstanceServiceManager, InstanceService__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { getFieldFromLogs } from "./transaction";
// import IRegistry abi

export type ServiceAddresses = {
    instanceServiceNftId: string,
    instanceServiceAddress: AddressLike,
    instanceService: InstanceService,
    instanceServiceManagerAddress: AddressLike,
    // componentOwnerServiceAddress: AddressLike,
    // componentOwnerServiceNftId: string,
    // distributionServiceAddress: AddressLike,
    // distributionServiceNftId: string,
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
            // ContractDeployerLib: libraries.contractDeployerLibAddress,
            NftIdLib: libraries.nftIdLibAddress, 
            // ObjectTypeLib: libraries.objectTypeLibAddress,
            // RiskIdLib: libraries.riskIdLibAddress,
            // RoleIdLib: libraries.roleIdLibAddress,
            // StateIdLib: libraries.stateIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
        }});

    const instanceServiceManager = instanceServiceManagerBaseContract as InstanceServiceManager;
    const instanceServiceAddress = await instanceServiceManager.getInstanceService();
    const logRegistrationInfo = getFieldFromLogs(ismDplRcpt!, registry.registry.interface, "LogRegistration", "info");
    const instanceServiceNfdId = (logRegistrationInfo as unknown[])[0];

    
    logger.info(`instanceServiceManager deployed - instanceServiceAddress: ${instanceServiceAddress} instanceServiceManagerAddress: ${instanceServiceManagerAddress} nftId: ${instanceServiceNfdId}`);

    const instanceService = InstanceService__factory.connect(instanceServiceAddress, owner);

    // const componentOwnerServiceNftId = await register(componentOwnerServiceBaseContract as Registerable, componentOwnerServiceAddress, "ComponentOwnerService", registry, owner);
    // logger.info(`componentOwnerService registered - componentOwnerServiceNftId: ${componentOwnerServiceNftId}`);

    // const { address: distributionServiceAddress, contract: distributionServiceBaseContract } = await deployContract(
    //     "DistributionService",
    //     owner,
    //     [registry.registryAddress, registry.registryNftId],
    //     { libraries: {
    //             NftIdLib: libraries.nftIdLibAddress,
    //             BlocknumberLib: libraries.blockNumberLibAddress, 
    //             VersionLib: libraries.versionLibAddress, 
    //         }});
    // const distributionServiceNftId = await register(distributionServiceBaseContract as Registerable, distributionServiceAddress, "DistributionService", registry, owner);
    // logger.info(`distributionService registered - distributionServiceNftId: ${distributionServiceNftId}`);

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
        // distributionServiceAddress,
        // distributionServiceNftId,
        // productServiceAddress,
        // productServiceNftId,
        // poolServiceAddress,
        // poolServiceNftId,
    };
}
