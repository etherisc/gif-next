
import { AddressLike, Signer, hexlify, resolveAddress } from "ethers";
import { AccessManager__factory, DistributionServiceManager, InstanceService, InstanceServiceManager, InstanceService__factory, PoolService, PoolServiceManager, PoolService__factory, IRegistryService__factory, ProductService, ProductServiceManager, ProductService__factory, PolicyService, PolicyServiceManager, PolicyService__factory, BundleService, BundleServiceManager, Bundleservice__factory} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { getFieldFromTxRcptLogs, executeTx } from "./transaction";
// import IRegistry abi

export type ServiceAddresses = {
    instanceServiceNftId: string,
    instanceServiceAddress: AddressLike,
    instanceService: InstanceService,
    instanceServiceManagerAddress: AddressLike,
    distributionServiceAddress: AddressLike,
    distributionServiceNftId: string,
    distributionService: InstanceService,
    distributionServiceManagerAddress: AddressLike,
    poolServiceAddress: AddressLike,
    poolServiceNftId: string,
    poolService: PoolService,
    poolServiceManagerAddress: AddressLike,
    productServiceAddress: AddressLike,
    productServiceNftId: string,
    productService: ProductService,
    productServiceManagerAddress: AddressLike,
    policyServiceAddress: AddressLike,
    policyServiceNftId : string,
    policyService: PolicyService,
    policyServiceManagerAddress: AddressLike
    bundleServiceAddress: AddressLike,
    bundleServiceNftId : string,
    bundleService: BundleService,
    bundleServiceManagerAddress: AddressLike
}

export async function deployAndRegisterServices(owner: Signer, registry: RegistryAddresses, libraries: LibraryAddresses): Promise<ServiceAddresses> {
    const { address: instanceServiceManagerAddress, contract: instanceServiceManagerBaseContract, } = await deployContract(
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
    const instanceService = InstanceService__factory.connect(instanceServiceAddress, owner);
    // FIXME temporal solution while registration in InstanceServiceManager constructor is not possible 
    const registryService = IRegistryService__factory.connect(await resolveAddress(registry.registryServiceAddress), owner);
    const rcpt = await executeTx(async () => await registryService.registerService(instanceServiceAddress));
    const logRegistrationInfo = getFieldFromTxRcptLogs(rcpt!, registry.registry.interface, "LogRegistration", "info");
    const instanceServiceNfdId = (logRegistrationInfo as unknown[])[0];
    logger.info(`instanceServiceManager deployed - instanceServiceAddress: ${instanceServiceAddress} instanceServiceManagerAddress: ${instanceServiceManagerAddress} nftId: ${instanceServiceNfdId}`);


    const { address: distributionServiceManagerAddress, contract: distributionServiceManagerBaseContract, } = await deployContract(
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
    const distributionService = InstanceService__factory.connect(distributionServiceAddress, owner);
    // FIXME temporal solution while registration in DistributionServiceManager constructor is not possible 
    const rcptDs = await executeTx(async () => await registryService.registerService(distributionServiceAddress));
    const logRegistrationInfoDs = getFieldFromTxRcptLogs(rcptDs!, registry.registry.interface, "LogRegistration", "info");
    const distributionServiceNftId = (logRegistrationInfoDs as unknown[])[0];
    logger.info(`distributionServiceManager deployed - distributionServiceAddress: ${distributionServiceAddress} distributionServiceManagerAddress: ${distributionServiceManagerAddress} nftId: ${distributionServiceNftId}`);

    const { address: poolServiceManagerAddress, contract: poolServiceManagerBaseContract, } = await deployContract(
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
    const poolService = PoolService__factory.connect(poolServiceAddress, owner);
    // FIXME temporal solution while registration in PoolServiceManager constructor is not possible 
    const rcptPs = await executeTx(async () => await registryService.registerService(poolServiceAddress));
    const logRegistrationInfoPs = getFieldFromTxRcptLogs(rcptPs!, registry.registry.interface, "LogRegistration", "info");
    const poolServiceNftId = (logRegistrationInfoPs as unknown[])[0];
    logger.info(`poolServiceManager deployed - poolServiceAddress: ${poolServiceAddress} poolServiceManagerAddress: ${poolServiceManagerAddress} nftId: ${poolServiceNftId}`);

    const { address: productServiceManagerAddress, contract: productServiceManagerBaseContract, } = await deployContract(
        "ProductServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                BlocknumberLib: libraries.blockNumberLibAddress, 
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});

    const productServiceManager = productServiceManagerBaseContract as ProductServiceManager;
    const productServiceAddress = await productServiceManager.getProductService();
    const productService = ProductService__factory.connect(productServiceAddress, owner);
    // FIXME temporal solution while registration in ProductServiceManager constructor is not possible
    const rcptPrd = await executeTx(async () => await registryService.registerService(productServiceAddress));
    const logRegistrationInfoPrd = getFieldFromTxRcptLogs(rcptPrd!, registry.registry.interface, "LogRegistration", "info");
    const productServiceNftId = (logRegistrationInfoPrd as unknown[])[0];
    logger.info(`productServiceManager deployed - productServiceAddress: ${productServiceAddress} productServiceManagerAddress: ${productServiceManagerAddress} nftId: ${productServiceNftId}`);

    const { address: policyServiceManagerAddress, contract: policyServiceManagerBaseContract, } = await deployContract(
        "PolicyServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                BlocknumberLib: libraries.blockNumberLibAddress, 
                FeeLib: libraries.feeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});

    const policyServiceManager = policyServiceManagerBaseContract as PolicyServiceManager;
    const policyServiceAddress = await policyServiceManager.getPolicyService();
    const policyService = PolicyService__factory.connect(policyServiceAddress, owner);
    // FIXME temporal solution while registration in ProductServiceManager constructor is not possible
    const rcptPol = await executeTx(async () => await registryService.registerService(policyServiceAddress));
    const logRegistrationInfoPol = getFieldFromTxRcptLogs(rcptPol!, registry.registry.interface, "LogRegistration", "info");
    const policyServiceNftId = (logRegistrationInfoPol as unknown[])[0];
    logger.info(`policyServiceManager deployed - policyServiceAddress: ${policyServiceAddress} policyServiceManagerAddress: ${policyServiceManagerAddress} nftId: ${policyServiceNftId}`);

    const { address: bundleServiceManagerAddress, contract: bundleServiceManagerBaseContract, } = await deployContract(
        "BundleServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                BlocknumberLib: libraries.blockNumberLibAddress, 
                FeeLib: libraries.feeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});

    const bundleServiceManager = bundleServiceManagerBaseContract as PolicyServiceManager;
    const bundleServiceAddress = await bundleServiceManager.getBundleService();
    const bundleService = PolicyService__factory.connect(bundleServiceAddress, owner);
    // FIXME temporal solution while registration in ProductServiceManager constructor is not possible
    const rcptBdl = await executeTx(async () => await registryService.registerService(bundleServiceAddress));
    const logRegistrationInfoBdl = getFieldFromTxRcptLogs(rcptBdl!, registry.registry.interface, "LogRegistration", "info");
    const bundleServiceNftId = (logRegistrationInfoBdl as unknown[])[0];
    logger.info(`bundleServiceManager deployed - bundleServiceAddress: ${bundleServiceAddress} bundleServiceManagerAddress: ${bundleServiceManagerAddress} nftId: ${bundleServiceNftId}`);

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
        productServiceAddress,
        productServiceNftId : productServiceNftId as string,
        productService,
        productServiceManagerAddress,
        policyServiceAddress,
        policyServiceNftId : policyServiceNftId as string,
        policyService,
        policyServiceManagerAddress,

        bundleServiceAddress,
        bundleServiceNftId : bundleServiceNftId as string,
        bundleService,
        bundleServiceManagerAddress,
    };
}

const DISTRIBUTION_REGISTRAR_ROLE = 1000;
const POLICY_REGISTRAR_ROLE = 1100;
const BUNDLE_REGISTRAR_ROLE = 1200;
const POOL_REGISTRAR_ROLE = 1300;
const PRODUCT_REGISTRAR_ROLE = 1400;


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

    // grant PRODUCT_REGISTRAR_ROLE to product service
    // allow role PRODUCT_REGISTRAR_ROLE to call registerProduct on registry service
    await registryAccessManager.grantRole(PRODUCT_REGISTRAR_ROLE, services.productServiceAddress, 0);
    const fctSelector4 = registry.registryService.interface.getFunction("registerProduct").selector;
    logger.debug(`setting function role for ${hexlify(fctSelector4)} to ${PRODUCT_REGISTRAR_ROLE}`);
    await registryAccessManager.setTargetFunctionRole(
        registry.registryService,
        [fctSelector4],
        PRODUCT_REGISTRAR_ROLE,
    );

    // grant POLICY_REGISTRAR_ROLE to product service
    // allow role POLICY_REGISTRAR_ROLE to call registerPolicy on registry service
    await registryAccessManager.grantRole(POLICY_REGISTRAR_ROLE, services.policyServiceAddress, 0);
    const fctSelector5 = registry.registryService.interface.getFunction("registerPolicy").selector;
    logger.debug(`setting function role for ${hexlify(fctSelector5)} to ${POLICY_REGISTRAR_ROLE}`);
    await registryAccessManager.setTargetFunctionRole(
        registry.registryService,
        [fctSelector5],
        POLICY_REGISTRAR_ROLE,
    );
}

