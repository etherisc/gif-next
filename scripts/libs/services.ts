
import { AddressLike, BytesLike, Signer, resolveAddress, id } from "ethers";
import { 
    DistributionService, DistributionServiceManager, DistributionService__factory, 
    InstanceService, InstanceServiceManager, InstanceService__factory, 
    ComponentService, ComponentServiceManager, ComponentService__factory, 
    PoolService, PoolServiceManager, PoolService__factory, 
    ProductService, ProductServiceManager, ProductService__factory, 
    ApplicationService, ApplicationServiceManager, ApplicationService__factory, 
    PolicyService, PolicyServiceManager, PolicyService__factory, 
    ClaimService, ClaimServiceManager, ClaimService__factory, 
    BundleService, BundleServiceManager, BundleService__factory, 
    OracleService, OracleServiceManager, OracleService__factory,
    PricingService, PricingServiceManager, PricingService__factory,
    RegistryService, RegistryService__factory, RegistryServiceManager,
    StakingService, StakingServiceManager, StakingService__factory
} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { executeTx, getFieldFromTxRcptLogs } from "./transaction";
import { getReleaseConfig, createRelease } from "./release";


export type ServiceAddresses = {
    registryServiceNftId: string,
    registryServiceAddress: AddressLike,
    registryService: RegistryService,
    registryServiceManagerAddress: AddressLike,

    instanceServiceNftId: string,
    instanceServiceAddress: AddressLike,
    instanceService: InstanceService,
    instanceServiceManagerAddress: AddressLike,

    componentServiceNftId: string,
    componentServiceAddress: AddressLike,
    componentService: ComponentService,
    componentServiceManagerAddress: AddressLike,

    distributionServiceNftId: string,
    distributionServiceAddress: AddressLike,
    distributionService: DistributionService,
    distributionServiceManagerAddress: AddressLike,

    oracleServiceNftId: string,
    oracleServiceAddress: AddressLike,
    oracleService: OracleService,
    oracleServiceManagerAddress: AddressLike,

    pricingServiceNftId: string,
    pricingServiceAddress: AddressLike,
    pricingService: PricingService,
    pricingServiceManagerAddress: AddressLike,

    poolServiceNftId: string,
    poolServiceAddress: AddressLike,
    poolService: PoolService,
    poolServiceManagerAddress: AddressLike,

    productServiceNftId: string,
    productServiceAddress: AddressLike,
    productService: ProductService,
    productServiceManagerAddress: AddressLike,

    applicationServiceNftId : string,
    applicationServiceAddress: AddressLike,
    applicationService: ApplicationService,
    applicationServiceManagerAddress: AddressLike

    policyServiceNftId : string,
    policyServiceAddress: AddressLike,
    policyService: PolicyService,
    policyServiceManagerAddress: AddressLike

    claimServiceNftId : string,
    claimServiceAddress: AddressLike,
    claimService: ClaimService,
    claimServiceManagerAddress: AddressLike

    bundleServiceNftId : string,
    bundleServiceAddress: AddressLike,
    bundleService: BundleService,
    bundleServiceManagerAddress: AddressLike

    stakingServiceNftId : string,
    stakingServiceAddress: AddressLike,
    stakingService: StakingService,
    stakingServiceManagerAddress: AddressLike
}

export async function deployAndRegisterServices(owner: Signer, registry: RegistryAddresses, libraries: LibraryAddresses): Promise<ServiceAddresses> 
{
    logger.info("======== Starting release creation ========");
    //const salt = zeroPadBytes("0x03", 32);
    const salt: BytesLike = id(`0x5678`);
    const config = await getReleaseConfig(owner, registry, libraries, salt);
    const release = await createRelease(owner, registry, config, salt);
    logger.info(`Release created - version: ${release.version} salt: ${release.salt} access manager: ${release.accessManager}`);

    logger.info("======== Starting deployment of services ========");
    const releaseManager = await registry.releaseManager.connect(owner);
    logger.info("-------- regtistry service --------");
    const { address: registryServiceManagerAddress, contract: registryServiceManagerBaseContract } = await deployContract(
        "RegistryServiceManager",
        owner,
        [
            release.accessManager, // release access manager address it self can be a salt like value
            registry.registryAddress,
            release.salt
        ],
        { libraries: { 
                NftIdLib: libraries.nftIdLibAddress, 
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }});

    logger.info("a");

    const registryServiceManager = registryServiceManagerBaseContract as RegistryServiceManager;
    const registryServiceAddress = await registryServiceManager.getRegistryService();
    const registryService = RegistryService__factory.connect(registryServiceAddress, owner);
    logger.info("b");

    const rcptRs = await executeTx(async () => await releaseManager.registerService(registryServiceAddress));
    const logRegistrationInfoRs = getFieldFromTxRcptLogs(rcptRs!, registry.registry.interface, "LogRegistration", "nftId");
    const registryServiceNfdId = (logRegistrationInfoRs as unknown);
    logger.info("c");

    // is not NftOwnable
    //await registry.tokenRegistry.linkToRegistryService();

    logger.info(`registryServiceManager deployed - registryServiceAddress: ${registryServiceAddress} registryServiceManagerAddress: ${registryServiceManagerAddress} nftId: ${registryServiceNfdId}`);

    logger.info("-------- staking service --------");
    const { address: stakingServiceManagerAddress, contract: stakingServiceManagerBaseContract, } = await deployContract(
        "StakingServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
            VersionPartLib: libraries.versionPartLibAddress,
            TargetManagerLib: libraries.targetManagerLibAddress,
        }});

    const stakingServiceManager = stakingServiceManagerBaseContract as StakingServiceManager;
    const stakingServiceAddress = await stakingServiceManager.getStakingService();
    const stakingService = StakingService__factory.connect(stakingServiceAddress, owner);

    const rcptStk = await executeTx(async () => await releaseManager.registerService(stakingServiceAddress));
    const logRegistrationInfoStk = getFieldFromTxRcptLogs(rcptStk!, registry.registry.interface, "LogRegistration", "nftId");
    const stakingServiceNftId = (logRegistrationInfoStk as unknown);
    await stakingServiceManager.linkToProxy();
    logger.info(`stakingServiceManager deployed - stakingServiceAddress: ${stakingServiceAddress} stakingServiceManagerAddress: ${stakingServiceManagerAddress} nftId: ${stakingServiceNftId}`);

    logger.info("-------- instance service --------");
    const { address: instanceServiceManagerAddress, contract: instanceServiceManagerBaseContract, } = await deployContract(
        "InstanceServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: { 
            NftIdLib: libraries.nftIdLibAddress, 
            // ObjectTypeLib: libraries.objectTypeLibAddress, 
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            InstanceAuthorizationsLib: libraries.instanceAuthorizationsLibAddress,
            TargetManagerLib: libraries.targetManagerLibAddress,
        }});

    const instanceServiceManager = instanceServiceManagerBaseContract as InstanceServiceManager;
    const instanceServiceAddress = await instanceServiceManager.getInstanceService();
    const instanceService = InstanceService__factory.connect(instanceServiceAddress, owner);

    const rcptInst = await executeTx(async () => await releaseManager.registerService(instanceServiceAddress));
    const logRegistrationInfoInst = getFieldFromTxRcptLogs(rcptInst!, registry.registry.interface, "LogRegistration", "nftId");
    const instanceServiceNfdId = (logRegistrationInfoInst as unknown);
    await instanceServiceManager.linkToProxy();
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
            // ObjectTypeLib: libraries.objectTypeLibAddress, 
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

    logger.info("-------- oracle service --------");
    const { address: oracleServiceManagerAddress, contract: oracleServiceManagerBaseContract, } = await deployContract(
        "OracleServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                // ObjectTypeLib: libraries.objectTypeLibAddress, 
                RequestIdLib: libraries.requestIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress,
            }});
    
    const oracleServiceManager = oracleServiceManagerBaseContract as OracleServiceManager;
    const oracleServiceAddress = await oracleServiceManager.getOracleService();
    const oracleService = OracleService__factory.connect(oracleServiceAddress, owner);

    const orclPrs = await executeTx(async () => await releaseManager.registerService(oracleServiceAddress));
    const logRegistrationInfoOrc = getFieldFromTxRcptLogs(orclPrs!, registry.registry.interface, "LogRegistration", "nftId");
    const oracleServiceNftId = (logRegistrationInfoOrc as unknown);
    await oracleServiceManager.linkToProxy();
    logger.info(`oracleServiceManager deployed - oracleServiceAddress: ${oracleServiceAddress} oracleServiceManagerAddress: ${oracleServiceManagerAddress} nftId: ${oracleServiceNftId}`);

    logger.info("-------- distribution service --------");
    const { address: distributionServiceManagerAddress, contract: distributionServiceManagerBaseContract, } = await deployContract(
        "DistributionServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                DistributorTypeLib: libraries.distributorTypeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                // ObjectTypeLib: libraries.objectTypeLibAddress, 
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
    await distributionServiceManager.linkToProxy();
    logger.info(`distributionServiceManager deployed - distributionServiceAddress: ${distributionServiceAddress} distributionServiceManagerAddress: ${distributionServiceManagerAddress} nftId: ${distributionServiceNftId}`);

    logger.info("-------- pricing service --------");
    const { address: pricingServiceManagerAddress, contract: pricingServiceManagerBaseContract, } = await deployContract(
        "PricingServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                // ObjectTypeLib: libraries.objectTypeLibAddress, 
                RoleIdLib: libraries.roleIdLibAddress,
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
    await pricingServiceManager.linkToProxy();
    logger.info(`pricingServiceManager deployed - pricingServiceAddress: ${pricingServiceAddress} pricingServiceManagerAddress: ${pricingServiceManagerAddress} nftId: ${pricingServiceNftId}`);

    logger.info("-------- bundle service --------");
    const { address: bundleServiceManagerAddress, contract: bundleServiceManagerBaseContract, } = await deployContract(
        "BundleServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                // ObjectTypeLib: libraries.objectTypeLibAddress, 
                RoleIdLib: libraries.roleIdLibAddress,
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
    await bundleServiceManager.linkToProxy();
    logger.info(`bundleServiceManager deployed - bundleServiceAddress: ${bundleServiceAddress} bundleServiceManagerAddress: ${bundleServiceManagerAddress} nftId: ${bundleServiceNftId}`);

    logger.info("-------- pool service --------");
    const { address: poolServiceManagerAddress, contract: poolServiceManagerBaseContract, } = await deployContract(
        "PoolServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                FeeLib: libraries.feeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                // ObjectTypeLib: libraries.objectTypeLibAddress, 
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
    await poolServiceManager.linkToProxy();
    logger.info(`poolServiceManager deployed - poolServiceAddress: ${poolServiceAddress} poolServiceManagerAddress: ${poolServiceManagerAddress} nftId: ${poolServiceNftId}`);

    logger.info("-------- product service --------");
    const { address: productServiceManagerAddress, contract: productServiceManagerBaseContract, } = await deployContract(
        "ProductServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                // ObjectTypeLib: libraries.objectTypeLibAddress, 
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
    await productServiceManager.linkToProxy();
    logger.info(`productServiceManager deployed - productServiceAddress: ${productServiceAddress} productServiceManagerAddress: ${productServiceManagerAddress} nftId: ${productServiceNftId}`);

    logger.info("-------- claim service --------");
    const { address: claimServiceManagerAddress, contract: claimServiceManagerBaseContract, } = await deployContract(
        "ClaimServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                ClaimIdLib: libraries.claimIdLibAddress,
                FeeLib: libraries.feeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                // ObjectTypeLib: libraries.objectTypeLibAddress, 
                RoleIdLib: libraries.roleIdLibAddress,
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
    await claimServiceManager.linkToProxy();
    logger.info(`claimServiceManager deployed - claimServiceAddress: ${claimServiceAddress} claimServiceManagerAddress: ${claimServiceManagerAddress} nftId: ${claimServiceNftId}`);

    logger.info("-------- application service --------");
    const { address: applicationServiceManagerAddress, contract: applicationServiceManagerBaseContract, } = await deployContract(
        "ApplicationServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            // ObjectTypeLib: libraries.objectTypeLibAddress, 
            RoleIdLib: libraries.roleIdLibAddress,
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
    await applicationServiceManager.linkToProxy();
    logger.info(`applicationServiceManager deployed - applicationServiceAddress: ${applicationServiceAddress} policyServiceManagerAddress: ${applicationServiceManagerAddress} nftId: ${applicationServiceNftId}`);

    logger.info("-------- policy service --------");
    const { address: policyServiceManagerAddress, contract: policyServiceManagerBaseContract, } = await deployContract(
        "PolicyServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            // ObjectTypeLib: libraries.objectTypeLibAddress, 
            RoleIdLib: libraries.roleIdLibAddress,
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
    await policyServiceManager.linkToProxy();
    logger.info(`policyServiceManager deployed - policyServiceAddress: ${policyServiceAddress} policyServiceManagerAddress: ${policyServiceManagerAddress} nftId: ${policyServiceNftId}`);
    
    logger.info("======== Finished deployment of services ========");

    logger.info("======== Activating release ========");
    await releaseManager.activateNextRelease();
    logger.info("======== release activated ========");

    return {
        registryServiceNftId: registryServiceNfdId as string,
        registryServiceAddress: registryServiceAddress,
        registryService: registryService,
        registryServiceManagerAddress: registryServiceManagerAddress,

        instanceServiceNftId: instanceServiceNfdId as string,
        instanceServiceAddress: instanceServiceAddress,
        instanceService: instanceService,
        instanceServiceManagerAddress: instanceServiceManagerAddress,

        componentServiceNftId: componentServiceNftId as string,
        componentServiceAddress: componentServiceAddress,
        componentService: componentService,
        componentServiceManagerAddress: componentServiceManagerAddress,

        distributionServiceNftId: distributionServiceNftId as string,
        distributionServiceAddress: distributionServiceAddress,
        distributionService: distributionService,
        distributionServiceManagerAddress: distributionServiceManagerAddress,

        oracleServiceNftId: oracleServiceNftId as string,
        oracleServiceAddress: oracleServiceAddress,
        oracleService: oracleService,
        oracleServiceManagerAddress: oracleServiceManagerAddress,

        pricingServiceNftId: distributionServiceNftId as string,
        pricingServiceAddress: pricingServiceAddress,
        pricingService: pricingService,
        pricingServiceManagerAddress: pricingServiceManagerAddress,

        poolServiceNftId: poolServiceNftId as string,
        poolServiceAddress: poolServiceAddress,
        poolService: poolService,
        poolServiceManagerAddress: poolServiceManagerAddress,

        productServiceNftId: productServiceNftId as string,
        productServiceAddress: productServiceAddress,
        productService: productService,
        productServiceManagerAddress: productServiceManagerAddress,

        applicationServiceNftId: applicationServiceNftId as string,
        applicationServiceAddress: applicationServiceAddress,
        applicationService: applicationService,
        applicationServiceManagerAddress: applicationServiceManagerAddress,

        policyServiceNftId: policyServiceNftId as string,
        policyServiceAddress: policyServiceAddress,
        policyService: policyService,
        policyServiceManagerAddress: policyServiceManagerAddress,

        claimServiceNftId: claimServiceNftId as string,
        claimServiceAddress: claimServiceAddress,
        claimService: claimService,
        claimServiceManagerAddress: claimServiceManagerAddress,

        bundleServiceNftId: bundleServiceNftId as string,
        bundleServiceAddress: bundleServiceAddress,
        bundleService: bundleService,
        bundleServiceManagerAddress: bundleServiceManagerAddress,

        stakingServiceNftId: stakingServiceNftId as string,
        stakingServiceAddress: stakingServiceAddress,
        stakingService: stakingService,
        stakingServiceManagerAddress: stakingServiceManagerAddress
    };
}