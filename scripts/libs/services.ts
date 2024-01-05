import { AddressLike, Signer } from "ethers";
import { InstanceService, InstanceServiceManager, Registerable } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses, register } from "./registry";
import { executeTx, getFieldFromLogs } from "./transaction";
// import IRegistry abi
import IRegistryABI from "../../artifacts/contracts/registry/IRegistry.sol/IRegistry.json";
import { IRegistryInterface } from "../../typechain-types/contracts/registry/IRegistry";

export type ServiceAddresses = {
    instanceServiceNftId: string,
    instanceServiceAddress: AddressLike,
    instanceService: InstanceService,
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
    const { address: instanceServiceManagerAddress, contract: instanceServiceManagerBaseContract } = await deployContract(
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

    logger.info(`instanceService deployed - instanceServiceAddress: ${instanceServiceAddress} instanceServiceManagerAddress: ${instanceServiceManagerAddress}`);

    // TODO - register as owner if instanceServiceManager
    logger.info(`registering instanceService as owner => ${await owner.getAddress()}`);
    const rcpt = await executeTx(() => registry.registryService.connect(owner).registerService(instanceServiceAddress));
    const nfdId = getFieldFromLogs(rcpt, registry.registry.interface, "LogRegistration", "nftId");
    
    logger.info(`instanceService registered - instanceServiceAddress: ${instanceServiceAddress} nftId: ${nfdId}`);

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
