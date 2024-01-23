import { AddressLike, Signer, hexlify } from "ethers";
import { AccessManager__factory, DistributionServiceManager, InstanceService, InstanceServiceManager, InstanceService__factory, PoolService, PoolServiceManager, PoolService__factory } from "../../typechain-types";
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
    poolServiceAddress: AddressLike,
    poolServiceNftId: string,
    poolService: PoolService,
    poolServiceManagerAddress: AddressLike,
    // productServiceAddress: AddressLike,
    // productServiceNftId: string,
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
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});
    
    const distributionServiceManager = distributionServiceManagerBaseContract as DistributionServiceManager;
    const distributionServiceAddress = await distributionServiceManager.getDistributionService();
    const logRegistrationInfoDs = getFieldFromTxRcptLogs(dsmDplRcpt!, registry.registry.interface, "LogRegistration", "info");
    const distributionServiceNftId = (logRegistrationInfoDs as unknown[])[0];
    const distributionService = InstanceService__factory.connect(distributionServiceAddress, owner);
    logger.info(`distributionServiceManager deployed - distributionServiceAddress: ${distributionServiceAddress} distributionServiceManagerAddress: ${distributionServiceManagerAddress} nftId: ${distributionServiceNftId}`);

    const { address: poolServiceManagerAddress, contract: poolServiceManagerBaseContract, deploymentReceipt: psmDplRcpt } = await deployContract(
        "PoolServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                BlocknumberLib: libraries.blockNumberLibAddress, 
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});
    
    const poolServiceManager = poolServiceManagerBaseContract as PoolServiceManager;
    const poolServiceAddress = await poolServiceManager.getPoolService();
    const logRegistrationInfoPs = getFieldFromTxRcptLogs(psmDplRcpt!, registry.registry.interface, "LogRegistration", "info");
    const poolServiceNftId = (logRegistrationInfoPs as unknown[])[0];
    const poolService = PoolService__factory.connect(poolServiceAddress, owner);
    logger.info(`poolServiceManager deployed - poolServiceAddress: ${poolServiceAddress} poolServiceManagerAddress: ${poolServiceManagerAddress} nftId: ${poolServiceNftId}`);

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
        poolServiceAddress,
        poolServiceNftId: poolServiceNftId as string,
        poolService,
        poolServiceManagerAddress,
        // productServiceAddress,
        // productServiceNftId,
    };
}

const DISTRIBUTION_REGISTRAR_ROLE = 1000;
// const POLICY_REGISTRAR_ROLE = 1100;
const BUNDLE_REGISTRAR_ROLE = 1200;
const POOL_REGISTRAR_ROLE = 1300;
// const PRODUCT_REGISTRAR_ROLE = 1400;


export async function authorizeServices(protocolOwner: Signer, libraries: LibraryAddresses, registry: RegistryAddresses, services: ServiceAddresses) {
    const registryAccessManagerAddress = await registry.registryServiceManager.getAccessManager();
    const registryAccessManager = AccessManager__factory.connect(registryAccessManagerAddress, protocolOwner);

    // grant DISTRIBUTION_REGISTRAR_ROLE to distribution service
    // allow role DISTRIBUTION_REGISTRAR_ROLE to call registerDistribution on registry service
    await registryAccessManager.grantRole(DISTRIBUTION_REGISTRAR_ROLE, services.distributionServiceAddress, 0);
    const fctSelector = registry.registryService.interface.getFunction("registerDistribution").selector;
    logger.debug(`setting function role for ${hexlify(fctSelector)} to ${DISTRIBUTION_REGISTRAR_ROLE}`);
    await registryAccessManager.setTargetFunctionRole(
        registry.registryService,
        [fctSelector],
        DISTRIBUTION_REGISTRAR_ROLE,
    );

    // grant POOL_REGISTRAR_ROLE to pool service
    // allow role POOL_REGISTRAR_ROLE to call registerPool on registry service
    await registryAccessManager.grantRole(POOL_REGISTRAR_ROLE, services.poolServiceAddress, 0);
    const fctSelector2 = registry.registryService.interface.getFunction("registerPool").selector;
    logger.debug(`setting function role for ${hexlify(fctSelector2)} to ${POOL_REGISTRAR_ROLE}`);
    await registryAccessManager.setTargetFunctionRole(
        registry.registryService,
        [fctSelector2],
        POOL_REGISTRAR_ROLE,
    );

    // grant BUNDLE_REGISTRAR_ROLE to pool service
    // allow role BUNDLE_REGISTRAR_ROLE to call registerBundle on registry service
    await registryAccessManager.grantRole(BUNDLE_REGISTRAR_ROLE, services.poolServiceAddress, 0);
    const fctSelector3 = registry.registryService.interface.getFunction("registerBundle").selector;
    logger.debug(`setting function role for ${hexlify(fctSelector3)} to ${BUNDLE_REGISTRAR_ROLE}`);
    await registryAccessManager.setTargetFunctionRole(
        registry.registryService,
        [fctSelector3],
        BUNDLE_REGISTRAR_ROLE,
    );
}

