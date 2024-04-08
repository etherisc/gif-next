
import { AddressLike, Signer, hexlify, resolveAddress } from "ethers";
import { 
    ReleaseManager__factory, IRegistryService__factory, 
    DistributionService, DistributionServiceManager, DistributionService__factory, 
    InstanceService, InstanceServiceManager, InstanceService__factory, 
    PoolService, PoolServiceManager, PoolService__factory, 
    ProductService, ProductServiceManager, ProductService__factory, 
    ApplicationService, ApplicationServiceManager, ApplicationService__factory, 
    PolicyService, PolicyServiceManager, PolicyService__factory, 
    ClaimService, ClaimServiceManager, ClaimService__factory, 
    BundleService, BundleServiceManager, BundleService__factory
} from "../../typechain-types";
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

    applicationServiceAddress: AddressLike,
    applicationServiceNftId : string,
    applicationService: ApplicationService,
    applicationServiceManagerAddress: AddressLike

    policyServiceAddress: AddressLike,
    policyServiceNftId : string,
    policyService: PolicyService,
    policyServiceManagerAddress: AddressLike

    claimServiceAddress: AddressLike,
    claimServiceNftId : string,
    claimService: ClaimService,
    claimServiceManagerAddress: AddressLike

    bundleServiceAddress: AddressLike,
    bundleServiceNftId : string,
    bundleService: BundleService,
    bundleServiceManagerAddress: AddressLike
}

export async function deployAndRegisterServices(owner: Signer, registry: RegistryAddresses, libraries: LibraryAddresses): Promise<ServiceAddresses> {
    logger.info("======== Starting deployment of services ========");

    // FIXME temporal solution while registration in InstanceServiceManager constructor is not possible 
    const releaseManager = ReleaseManager__factory.connect(await resolveAddress(registry.releaseManagerAddress), owner);

    logger.info("-------- instance service --------");
    const { address: instanceServiceManagerAddress, contract: instanceServiceManagerBaseContract, } = await deployContract(
        "InstanceServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: { 
            NftIdLib: libraries.nftIdLibAddress, 
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
        }});

    const instanceServiceManager = instanceServiceManagerBaseContract as InstanceServiceManager;
    const instanceServiceAddress = await instanceServiceManager.getInstanceService();
    const instanceService = InstanceService__factory.connect(instanceServiceAddress, owner);

    const rcpt = await executeTx(async () => await releaseManager.registerService(instanceServiceAddress));
    const logRegistrationInfo = getFieldFromTxRcptLogs(rcpt!, registry.registry.interface, "LogRegistration", "nftId");
    const instanceServiceNfdId = (logRegistrationInfo as unknown);
    logger.info(`instanceServiceManager deployed - instanceServiceAddress: ${instanceServiceAddress} instanceServiceManagerAddress: ${instanceServiceManagerAddress} nftId: ${instanceServiceNfdId}`);

    logger.info("-------- distribution service --------");
    const { address: distributionServiceManagerAddress, contract: distributionServiceManagerBaseContract, } = await deployContract(
        "DistributionServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                DistributorTypeLib: libraries.distributorTypeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ReferralLib: libraries.referralLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});
    
    const distributionServiceManager = distributionServiceManagerBaseContract as DistributionServiceManager;
    const distributionServiceAddress = await distributionServiceManager.getDistributionService();
    const distributionService = DistributionService__factory.connect(distributionServiceAddress, owner);

    const rcptDs = await executeTx(async () => await releaseManager.registerService(distributionServiceAddress));
    const logRegistrationInfoDs = getFieldFromTxRcptLogs(rcptDs!, registry.registry.interface, "LogRegistration", "nftId");
    const distributionServiceNftId = (logRegistrationInfoDs as unknown);
    logger.info(`distributionServiceManager deployed - distributionServiceAddress: ${distributionServiceAddress} distributionServiceManagerAddress: ${distributionServiceManagerAddress} nftId: ${distributionServiceNftId}`);

    logger.info("-------- bundle service --------");
    const { address: bundleServiceManagerAddress, contract: bundleServiceManagerBaseContract, } = await deployContract(
        "BundleServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                FeeLib: libraries.feeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});

    const bundleServiceManager = bundleServiceManagerBaseContract as BundleServiceManager;
    const bundleServiceAddress = await bundleServiceManager.getBundleService();
    const bundleService = BundleService__factory.connect(bundleServiceAddress, owner);

    const rcptBdl = await executeTx(async () => await releaseManager.registerService(bundleServiceAddress));
    const logRegistrationInfoBdl = getFieldFromTxRcptLogs(rcptBdl!, registry.registry.interface, "LogRegistration", "nftId");
    const bundleServiceNftId = (logRegistrationInfoBdl as unknown);
    logger.info(`bundleServiceManager deployed - bundleServiceAddress: ${bundleServiceAddress} bundleServiceManagerAddress: ${bundleServiceManagerAddress} nftId: ${bundleServiceNftId}`);

    logger.info("-------- pool service --------");
    const { address: poolServiceManagerAddress, contract: poolServiceManagerBaseContract, } = await deployContract(
        "PoolServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});
    
    const poolServiceManager = poolServiceManagerBaseContract as PoolServiceManager;
    const poolServiceAddress = await poolServiceManager.getPoolService();
    const poolService = PoolService__factory.connect(poolServiceAddress, owner);

    const rcptPs = await executeTx(async () => await releaseManager.registerService(poolServiceAddress));
    const logRegistrationInfoPs = getFieldFromTxRcptLogs(rcptPs!, registry.registry.interface, "LogRegistration", "nftId");
    const poolServiceNftId = (logRegistrationInfoPs as unknown);
    logger.info(`poolServiceManager deployed - poolServiceAddress: ${poolServiceAddress} poolServiceManagerAddress: ${poolServiceManagerAddress} nftId: ${poolServiceNftId}`);

    logger.info("-------- product service --------");
    const { address: productServiceManagerAddress, contract: productServiceManagerBaseContract, } = await deployContract(
        "ProductServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});

    const productServiceManager = productServiceManagerBaseContract as ProductServiceManager;
    const productServiceAddress = await productServiceManager.getProductService();
    const productService = ProductService__factory.connect(productServiceAddress, owner);

    const rcptPrd = await executeTx(async () => await releaseManager.registerService(productServiceAddress));
    const logRegistrationInfoPrd = getFieldFromTxRcptLogs(rcptPrd!, registry.registry.interface, "LogRegistration", "nftId");
    const productServiceNftId = (logRegistrationInfoPrd as unknown);
    logger.info(`productServiceManager deployed - productServiceAddress: ${productServiceAddress} productServiceManagerAddress: ${productServiceManagerAddress} nftId: ${productServiceNftId}`);

    logger.info("-------- claim service --------");
    const { address: claimServiceManagerAddress, contract: claimServiceManagerBaseContract, } = await deployContract(
        "ClaimServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                PayoutIdLib: libraries.payoutIdLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});

    const claimServiceManager = claimServiceManagerBaseContract as ClaimServiceManager;
    const claimServiceAddress = await claimServiceManager.getClaimService();
    const claimService = ClaimService__factory.connect(claimServiceAddress, owner);

    const rcptClm = await executeTx(async () => await releaseManager.registerService(claimServiceAddress));
    const logRegistrationInfoClm = getFieldFromTxRcptLogs(rcptClm!, registry.registry.interface, "LogRegistration", "nftId");
    const claimServiceNftId = (logRegistrationInfoClm as unknown);
    logger.info(`claimServiceManager deployed - claimServiceAddress: ${claimServiceAddress} claimServiceManagerAddress: ${claimServiceManagerAddress} nftId: ${claimServiceNftId}`);

    logger.info("-------- application service --------");
    const { address: applicationServiceManagerAddress, contract: applicationServiceManagerBaseContract, } = await deployContract(
        "ApplicationServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            UFixedLib: libraries.uFixedLibAddress,
            VersionLib: libraries.versionLibAddress, 
            VersionPartLib: libraries.versionPartLibAddress, 
        }});

    const applicationServiceManager = applicationServiceManagerBaseContract as ApplicationServiceManager;
    const applicationServiceAddress = await applicationServiceManager.getApplicationService();
    const applicationService = PolicyService__factory.connect(applicationServiceAddress, owner);

    const rcptAppl = await executeTx(async () => await releaseManager.registerService(applicationServiceAddress));
    const logRegistrationInfoAppl = getFieldFromTxRcptLogs(rcptAppl!, registry.registry.interface, "LogRegistration", "nftId");
    const applicationServiceNftId = (logRegistrationInfoAppl as unknown);
    logger.info(`applicaionServiceManager deployed - applicaionServiceAddress: ${applicationServiceAddress} policyServiceManagerAddress: ${applicationServiceManagerAddress} nftId: ${applicationServiceNftId}`);

    logger.info("-------- policy service --------");
    const { address: policyServiceManagerAddress, contract: policyServiceManagerBaseContract, } = await deployContract(
        "PolicyServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            ClaimIdLib: libraries.claimIdLibAddress,
            PayoutIdLib: libraries.payoutIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            UFixedLib: libraries.uFixedLibAddress,
            VersionLib: libraries.versionLibAddress, 
            VersionPartLib: libraries.versionPartLibAddress, 
        }});

    const policyServiceManager = policyServiceManagerBaseContract as PolicyServiceManager;
    const policyServiceAddress = await policyServiceManager.getPolicyService();
    const policyService = PolicyService__factory.connect(policyServiceAddress, owner);

    const rcptPol = await executeTx(async () => await releaseManager.registerService(policyServiceAddress));
    const logRegistrationInfoPol = getFieldFromTxRcptLogs(rcptPol!, registry.registry.interface, "LogRegistration", "nftId");
    const policyServiceNftId = (logRegistrationInfoPol as unknown);
    logger.info(`policyServiceManager deployed - policyServiceAddress: ${policyServiceAddress} policyServiceManagerAddress: ${policyServiceManagerAddress} nftId: ${policyServiceNftId}`);

    logger.info("======== Finished deployment of services ========");

    // activate first release
    await releaseManager.activateNextRelease();
    logger.info("======== release activated ========");

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

        applicationServiceAddress,
        applicationServiceNftId : applicationServiceNftId as string,
        applicationService,
        applicationServiceManagerAddress,

        policyServiceAddress,
        policyServiceNftId : policyServiceNftId as string,
        policyService,
        policyServiceManagerAddress,

        claimServiceAddress,
        claimServiceNftId : claimServiceNftId as string,
        claimService,
        claimServiceManagerAddress,

        bundleServiceAddress,
        bundleServiceNftId : bundleServiceNftId as string,
        bundleService,
        bundleServiceManagerAddress,
    };
}
