
import { AddressLike, Signer, hexlify, resolveAddress } from "ethers";
import { 
    ReleaseManager__factory,
    DistributionService, DistributionServiceManager, DistributionService__factory, 
    StakingService, StakingServiceManager, StakingService__factory, 
    InstanceService, InstanceServiceManager, InstanceService__factory, 
    ComponentService, ComponentServiceManager, ComponentService__factory, 
    PoolService, PoolServiceManager, PoolService__factory, 
    ProductService, ProductServiceManager, ProductService__factory, 
    ApplicationService, ApplicationServiceManager, ApplicationService__factory, 
    PolicyService, PolicyServiceManager, PolicyService__factory, 
    ClaimService, ClaimServiceManager, ClaimService__factory, 
    BundleService, BundleServiceManager, BundleService__factory, 
    PricingService, PricingServiceManager, PricingService__factory
} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { executeTx, getFieldFromTxRcptLogs } from "./transaction";
// import IRegistry abi

export type ServiceAddresses = {
    stakingServiceNftId: string,
    stakingServiceAddress: AddressLike,
    stakingService: StakingService,
    stakingServiceManagerAddress: AddressLike,

    instanceServiceNftId: string,
    instanceServiceAddress: AddressLike,
    instanceService: InstanceService,
    instanceServiceManagerAddress: AddressLike,

    componentServiceNftId: string,
    componentServiceAddress: AddressLike,
    componentService: ComponentService,
    componentServiceManagerAddress: AddressLike,

    distributionServiceAddress: AddressLike,
    distributionServiceNftId: string,
    distributionService: DistributionService,
    distributionServiceManagerAddress: AddressLike,

    pricingServiceAddress: AddressLike,
    pricingServiceNftId: string,
    pricingService: PricingService,
    pricingServiceManagerAddress: AddressLike,

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

    logger.info("-------- staking service --------");
    const { address: stakingServiceManagerAddress, contract: stakingServiceManagerBaseContract, } = await deployContract(
        "StakingServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: { 
            NftIdLib: libraries.nftIdLibAddress, 
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
        }});

    const stakingServiceManager = stakingServiceManagerBaseContract as StakingServiceManager;
    const stakingServiceAddress = await stakingServiceManager.getStakingService();
    const stakingService = StakingService__factory.connect(stakingServiceAddress, owner);

    const rcpt = await executeTx(async () => await releaseManager.registerService(stakingServiceAddress));
    const logRegistrationInfo = getFieldFromTxRcptLogs(rcpt!, registry.registry.interface, "LogRegistration", "nftId");
    const stakingServiceNfdId = (logRegistrationInfo as unknown);
    logger.info(`stakingServiceManager deployed - stakingServiceAddress: ${stakingServiceAddress} stakingServiceManagerAddress: ${stakingServiceManagerAddress} nftId: ${stakingServiceNfdId}`);

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
            InstanceAuthorizationsLib: libraries.instanceAuthorizationsLibAddress,
        }});

    const instanceServiceManager = instanceServiceManagerBaseContract as InstanceServiceManager;
    const instanceServiceAddress = await instanceServiceManager.getInstanceService();
    const instanceService = InstanceService__factory.connect(instanceServiceAddress, owner);

    const rcptInst = await executeTx(async () => await releaseManager.registerService(instanceServiceAddress));
    const logRegistrationInfoInst = getFieldFromTxRcptLogs(rcptInst!, registry.registry.interface, "LogRegistration", "nftId");
    const instanceServiceNfdId = (logRegistrationInfoInst as unknown);
    logger.info(`instanceServiceManager deployed - instanceServiceAddress: ${instanceServiceAddress} instanceServiceManagerAddress: ${instanceServiceManagerAddress} nftId: ${instanceServiceNfdId}`);

    logger.info("-------- component service --------");
    const { address: componentServiceManagerAddress, contract: componentServiceManagerBaseContract, } = await deployContract(
        "ComponentServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: { 
            AmountLib: libraries.amountLibAddress,
            FeeLib: libraries.feeLibAddress,
            NftIdLib: libraries.nftIdLibAddress, 
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
        }});

    const componentServiceManager = componentServiceManagerBaseContract as ComponentServiceManager;
    const componentServiceAddress = await componentServiceManager.getComponentService();
    const componentService = ComponentService__factory.connect(componentServiceAddress, owner);

    const rcptCmpt = await executeTx(async () => await releaseManager.registerService(componentServiceAddress));
    const logRegistrationInfoCmpt = getFieldFromTxRcptLogs(rcptCmpt!, registry.registry.interface, "LogRegistration", "nftId");
    const componentServiceNftId = (logRegistrationInfoCmpt as unknown);
    logger.info(`componentServiceManager deployed - componentServiceAddress: ${componentServiceAddress} componentServiceManagerAddress: ${componentServiceManagerAddress} nftId: ${componentServiceNftId}`);

    logger.info("-------- distribution service --------");
    const { address: distributionServiceManagerAddress, contract: distributionServiceManagerBaseContract, } = await deployContract(
        "DistributionServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                DistributorTypeLib: libraries.distributorTypeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ReferralLib: libraries.referralLibAddress,
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

    logger.info("-------- pricing service --------");
    const { address: pricingServiceManagerAddress, contract: pricingServiceManagerBaseContract, } = await deployContract(
        "PricingServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress,
                AmountLib: libraries.amountLibAddress
            }});
    
    const pricingServiceManager = pricingServiceManagerBaseContract as PricingServiceManager;
    const pricingServiceAddress = await pricingServiceManager.getPricingService();
    const pricingService = PricingService__factory.connect(pricingServiceAddress, owner);

    const rcptPrs = await executeTx(async () => await releaseManager.registerService(pricingServiceAddress));
    const logRegistrationInfoPrs = getFieldFromTxRcptLogs(rcptPrs!, registry.registry.interface, "LogRegistration", "nftId");
    const pricingServiceNftId = (logRegistrationInfoPrs as unknown);
    logger.info(`pricingServiceManager deployed - pricingServiceAddress: ${pricingServiceAddress} pricingServiceManagerAddress: ${pricingServiceManagerAddress} nftId: ${pricingServiceNftId}`);

    logger.info("-------- bundle service --------");
    const { address: bundleServiceManagerAddress, contract: bundleServiceManagerBaseContract, } = await deployContract(
        "BundleServiceManager",
        owner,
        [registry.registryAddress],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
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
                FeeLib: libraries.feeLibAddress,
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
                ClaimIdLib: libraries.claimIdLibAddress,
                FeeLib: libraries.feeLibAddress,
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
            VersionLib: libraries.versionLibAddress, 
            VersionPartLib: libraries.versionPartLibAddress, 
        }});

    const applicationServiceManager = applicationServiceManagerBaseContract as ApplicationServiceManager;
    const applicationServiceAddress = await applicationServiceManager.getApplicationService();
    const applicationService = ApplicationService__factory.connect(applicationServiceAddress, owner);

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
            TimestampLib: libraries.timestampLibAddress,
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
        stakingServiceNftId: stakingServiceNfdId as string,
        stakingServiceAddress: stakingServiceAddress,
        stakingService: stakingService,
        stakingServiceManagerAddress: stakingServiceManagerAddress,

        instanceServiceNftId: instanceServiceNfdId as string,
        instanceServiceAddress: instanceServiceAddress,
        instanceService: instanceService,
        instanceServiceManagerAddress: instanceServiceManagerAddress,

        componentServiceNftId: componentServiceNftId as string,
        componentServiceAddress: componentServiceAddress,
        componentService: componentService,
        componentServiceManagerAddress: componentServiceManagerAddress,

        distributionServiceAddress,
        distributionServiceNftId: distributionServiceNftId as string,
        distributionService,
        distributionServiceManagerAddress,

        pricingServiceAddress,
        pricingServiceNftId: distributionServiceNftId as string,
        pricingService,
        pricingServiceManagerAddress,

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