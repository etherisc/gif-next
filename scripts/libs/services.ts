
import { AddressLike, Signer, hexlify, resolveAddress } from "ethers";
import { ReleaseManager__factory, DistributionService, DistributionServiceManager, DistributionService__factory, InstanceService, InstanceServiceManager, InstanceService__factory, PoolService, PoolServiceManager, PoolService__factory, IRegistryService__factory, ProductService, ProductServiceManager, ProductService__factory, PolicyService, PolicyServiceManager, PolicyService__factory, BundleService, BundleServiceManager, BundleService__factory} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { executeTx, getFieldFromTxRcptLogs } from "./transaction";
// import IRegistry abi

export type ServiceAddresses = {
    instanceServiceNftId: string,
    instanceServiceAddress: AddressLike,
    instanceService: InstanceService,
    instanceServiceManagerAddress: AddressLike,
    distributionServiceNftId: string,
    distributionServiceAddress: AddressLike,
    distributionService: DistributionService,
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
    logger.info("======== Starting deployment of services ========");

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
    const releaseManager = ReleaseManager__factory.connect(await resolveAddress(registry.releaseManagerAddress), owner);
    const rcpt = await executeTx(async () => await releaseManager.registerService(instanceServiceAddress));
    const logRegistrationInfo = getFieldFromTxRcptLogs(rcpt!, registry.registry.interface, "LogRegistration", "nftId");
    const instanceServiceNfdId = (logRegistrationInfo as unknown);
    logger.info(`instanceServiceManager deployed - instanceServiceAddress: ${instanceServiceAddress} instanceServiceManagerAddress: ${instanceServiceManagerAddress} nftId: ${instanceServiceNfdId}`);


    const { address: distributionServiceManagerAddress, contract: distributionServiceManagerBaseContract, } = await deployContract(
        "DistributionServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                BlocknumberLib: libraries.blockNumberLibAddress, 
                DistributorTypeLib: libraries.distributorTypeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ReferralLib: libraries.referralLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});
    
    const distributionServiceManager = distributionServiceManagerBaseContract as DistributionServiceManager;
    const distributionServiceAddress = await distributionServiceManager.getDistributionService();
    const distributionService = DistributionService__factory.connect(distributionServiceAddress, owner);
    // FIXME temporal solution while registration in DistributionServiceManager constructor is not possible 
    const rcptDs = await executeTx(async () => await releaseManager.registerService(distributionServiceAddress));
    const logRegistrationInfoDs = getFieldFromTxRcptLogs(rcptDs!, registry.registry.interface, "LogRegistration", "nftId");
    const distributionServiceNftId = (logRegistrationInfoDs as unknown);
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
    const rcptPs = await executeTx(async () => await releaseManager.registerService(poolServiceAddress));
    const logRegistrationInfoPs = getFieldFromTxRcptLogs(rcptPs!, registry.registry.interface, "LogRegistration", "nftId");
    const poolServiceNftId = (logRegistrationInfoPs as unknown);
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
    const rcptPrd = await executeTx(async () => await releaseManager.registerService(productServiceAddress));
    const logRegistrationInfoPrd = getFieldFromTxRcptLogs(rcptPrd!, registry.registry.interface, "LogRegistration", "nftId");
    const productServiceNftId = (logRegistrationInfoPrd as unknown);
    logger.info(`productServiceManager deployed - productServiceAddress: ${productServiceAddress} productServiceManagerAddress: ${productServiceManagerAddress} nftId: ${productServiceNftId}`);

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

    const bundleServiceManager = bundleServiceManagerBaseContract as BundleServiceManager;
    const bundleServiceAddress = await bundleServiceManager.getBundleService();
    const bundleService = BundleService__factory.connect(bundleServiceAddress, owner);
    // FIXME temporal solution while registration in ProductServiceManager constructor is not possible
    const rcptBdl = await executeTx(async () => await releaseManager.registerService(bundleServiceAddress));
    const logRegistrationInfoBdl = getFieldFromTxRcptLogs(rcptBdl!, registry.registry.interface, "LogRegistration", "nftId");
    const bundleServiceNftId = (logRegistrationInfoBdl as unknown);
    logger.info(`bundleServiceManager deployed - bundleServiceAddress: ${bundleServiceAddress} bundleServiceManagerAddress: ${bundleServiceManagerAddress} nftId: ${bundleServiceNftId}`);

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
    const rcptPol = await executeTx(async () => await releaseManager.registerService(policyServiceAddress));
    const logRegistrationInfoPol = getFieldFromTxRcptLogs(rcptPol!, registry.registry.interface, "LogRegistration", "nftId");
    const policyServiceNftId = (logRegistrationInfoPol as unknown);
    logger.info(`policyServiceManager deployed - policyServiceAddress: ${policyServiceAddress} policyServiceManagerAddress: ${policyServiceManagerAddress} nftId: ${policyServiceNftId}`);

    // activate first release
    await releaseManager.activateNextRelease();

    // Now can link to "first" latest version
    await registry.registryServiceManager.linkToNftOwnable(registry.registryAddress);
    await registry.tokenRegistry.linkToNftOwnable(registry.registryAddress);

    logger.info("======== Finished deployment of services ========");

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
