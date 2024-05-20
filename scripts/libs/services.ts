
import { AddressLike, BytesLike, Signer, resolveAddress, id, TransactionResponse } from "ethers";
import { tenderly } from "hardhat";
import { 
    ReleaseManager__factory, 
    DistributionService, DistributionServiceManager, DistributionService__factory, 
    InstanceService, InstanceServiceManager, InstanceService__factory, 
    ComponentService, ComponentServiceManager, ComponentService__factory, 
    PoolService, PoolServiceManager, PoolService__factory, 
    ProductService, ProductServiceManager, ProductService__factory, 
    ApplicationService, ApplicationServiceManager, ApplicationService__factory, 
    PolicyService, PolicyServiceManager, PolicyService__factory, 
    ClaimService, ClaimServiceManager, ClaimService__factory, 
    BundleService, BundleServiceManager, BundleService__factory, 
    PricingService, PricingServiceManager, PricingService__factory,
    RegistryService, RegistryService__factory, RegistryServiceManager,
    StakingService, StakingServiceManager, StakingService__factory
} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract, addDeployedContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { executeTx, getFieldFromTxRcptLogs } from "./transaction";
import { getReleaseConfig, createRelease } from "./release";


export type ServiceAddresses = {
    registryServiceNftId: string,
    registryServiceAddress: AddressLike,
    registryService: RegistryService,
    registryServiceManagerAddress: AddressLike,

    stakingServiceNftId : string,
    stakingServiceAddress: AddressLike,
    stakingService: StakingService,
    stakingServiceManagerAddress: AddressLike

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
    logger.info("-------- registry service --------");
    const { 
        address: registryServiceManagerAddress, 
        contract: registryServiceManagerBaseContract,
        deploymentTransaction: registryServiceManagerDeploymentTransaction
    } = await deployContract(
        "RegistryServiceManager",
        "RegistryServiceManager",
        owner,
        [
            release.accessManager, // release access manager address it self can be a salt like value
            registry.registryAddress,
            release.salt
        ],
        { libraries: { 
                NftIdLib: libraries.nftIdLibAddress, 
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }});

    const registryServiceManager = registryServiceManagerBaseContract as RegistryServiceManager;
    const registryServiceAddress = await registryServiceManager.getRegistryService();
    const registryServiceImplementationAddress = await registryServiceManager.getImplementation();
    const registryService = RegistryService__factory.connect(registryServiceAddress, owner);

    logger.info("Verifying registry service implementation");
    // TODO 
    await addDeployedContract(
        "RegistryService",
        "RegistryService",
        registryServiceImplementationAddress,
        owner, //signer
        registryServiceManagerDeploymentTransaction as TransactionResponse,// deploymentTransaction,
        [],// constructor args
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    logger.info("Verifying registry service proxy");
    await addDeployedContract(
        "RegistryServiceProxy",
        "UpgradableProxyWithAdmin",
        registryServiceAddress,
        owner, //signer
        registryServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const rcptRs = await executeTx(async () => await releaseManager.registerService(registryServiceAddress));
    const logRegistrationInfoRs = getFieldFromTxRcptLogs(rcptRs!, registry.registry.interface, "LogRegistration", "nftId");
    const registryServiceNfdId = (logRegistrationInfoRs as unknown);
    logger.info(`registryServiceManager deployed - registryServiceAddress: ${registryServiceAddress} registryServiceManagerAddress: ${registryServiceManagerAddress} nftId: ${registryServiceNfdId}`);

    logger.info("-------- staking service --------");
    const { 
        address: stakingServiceManagerAddress,
        contract: stakingServiceManagerBaseContract,
        deploymentTransaction: stakingServiceManagerDeploymentTransaction
    } = await deployContract(
        "StakingServiceManager",
        "StakingServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
            NftIdLib: libraries.nftIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
            VersionPartLib: libraries.versionPartLibAddress,
            StakeManagerLib: libraries.stakeManagerLibAddress,
            TargetManagerLib: libraries.targetManagerLibAddress,
        }});

    const stakingServiceManager = stakingServiceManagerBaseContract as StakingServiceManager;
    const stakingServiceAddress = await stakingServiceManager.getStakingService();
    const stakingServiceImplementationAddress = await stakingServiceManager.getImplementation();
    const stakingService = StakingService__factory.connect(stakingServiceAddress, owner);

    logger.info("Verifying staking service implementation");
    /*
    await deployContract(
        "StakingService",
        owner,
        [],
        { libraries: { 
            NftIdLib: libraries.nftIdLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
            StakeManagerLib: libraries.stakeManagerLibAddress,
            TargetManagerLib: libraries.targetManagerLibAddress,
            }});
    */
    await addDeployedContract(
        "StakingService",
        "StakingService",
        stakingServiceImplementationAddress,
        owner, //signer
        stakingServiceManagerDeploymentTransaction as TransactionResponse,// deploymentTransaction,
        [],// constructor args
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
                StakeManagerLib: libraries.stakeManagerLibAddress,
                TargetManagerLib: libraries.targetManagerLibAddress,
            }
        });

    logger.info("Verifying staking service proxy");
    await addDeployedContract(
        "StakingServiceProxy",
        "UpgradableProxyWithAdmin",
        stakingServiceAddress,
        owner, //signer
        stakingServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const rcptStk = await executeTx(async () => await releaseManager.registerService(stakingServiceAddress));
    const logRegistrationInfoStk = getFieldFromTxRcptLogs(rcptStk!, registry.registry.interface, "LogRegistration", "nftId");
    const stakingServiceNftId = (logRegistrationInfoStk as unknown);
    await stakingServiceManager.linkToProxy();
    logger.info(`stakingServiceManager deployed - stakingServiceAddress: ${stakingServiceAddress} stakingServiceManagerAddress: ${stakingServiceManagerAddress} nftId: ${stakingServiceNftId}`);

    logger.info("-------- instance service --------");
    const { 
        address: instanceServiceManagerAddress, 
        contract: instanceServiceManagerBaseContract,
        deploymentTransaction: instanceServiceManagerDeploymentTransaction
    } = await deployContract(
        "InstanceServiceManager",
        "InstanceServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: { 
            NftIdLib: libraries.nftIdLibAddress, 
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            InstanceAuthorizationsLib: libraries.instanceAuthorizationsLibAddress,
            TargetManagerLib: libraries.targetManagerLibAddress,
        }});

    const instanceServiceManager = instanceServiceManagerBaseContract as InstanceServiceManager;
    const instanceServiceAddress = await instanceServiceManager.getInstanceService();
    const instanceServiceImplementationAddress = await instanceServiceManager.getImplementation();
    const instanceService = InstanceService__factory.connect(instanceServiceAddress, owner);

    logger.info("Verifying instance service implementation");
    /*
    await deployContract(
        "InstanceService",
        owner,
        [],
        { libraries: { 
            NftIdLib: libraries.nftIdLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
            InstanceAuthorizationsLib: libraries.instanceAuthorizationsLibAddress,
            TargetManagerLib: libraries.targetManagerLibAddress,
    }});
    */
    await addDeployedContract(
        "InstanceService",
        "InstanceService",
        instanceServiceImplementationAddress,
        owner, //signer
        instanceServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
                InstanceAuthorizationsLib: libraries.instanceAuthorizationsLibAddress,
                TargetManagerLib: libraries.targetManagerLibAddress,
            }
        });

    logger.info("Verifying instance service proxy");
    await addDeployedContract(
        "InstanceServiceProxy",
        "UpgradableProxyWithAdmin",
        instanceServiceAddress,
        owner, //signer
        instanceServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const rcptInst = await executeTx(async () => await releaseManager.registerService(instanceServiceAddress));
    const logRegistrationInfoInst = getFieldFromTxRcptLogs(rcptInst!, registry.registry.interface, "LogRegistration", "nftId");
    const instanceServiceNfdId = (logRegistrationInfoInst as unknown);
    await instanceServiceManager.linkToProxy();
    logger.info(`instanceServiceManager deployed - instanceServiceAddress: ${instanceServiceAddress} instanceServiceManagerAddress: ${instanceServiceManagerAddress} nftId: ${instanceServiceNfdId}`);

    logger.info("-------- component service --------");
    const { 
        address: componentServiceManagerAddress,
        contract: componentServiceManagerBaseContract,
        deploymentTransaction: componentServiceManagerDeploymentTransaction
    } = await deployContract(
        "ComponentServiceManager",
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
    const componentServiceImplementationAddress = await componentServiceManager.getImplementation();
    const componentService = ComponentService__factory.connect(componentServiceAddress, owner);

    logger.info("Verifying component service implementation");
    /*await deployContract(
        "ComponentService",
        owner,
        [],
        { libraries: { 
            NftIdLib: libraries.nftIdLibAddress,
            AmountLib: libraries.amountLibAddress,
            FeeLib: libraries.feeLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
    }});*/
    await addDeployedContract(
        "ComponentService",
        "ComponentService",
        componentServiceImplementationAddress,
        owner, //signer
        componentServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                AmountLib: libraries.amountLibAddress,
                FeeLib: libraries.feeLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    logger.info("Verifying component service proxy");
    await addDeployedContract(
        "ComponentServiceProxy",
        "UpgradableProxyWithAdmin",
        componentServiceAddress,
        owner, //signer
        componentServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });


    const rcptCmpt = await executeTx(async () => await releaseManager.registerService(componentServiceAddress));
    const logRegistrationInfoCmpt = getFieldFromTxRcptLogs(rcptCmpt!, registry.registry.interface, "LogRegistration", "nftId");
    const componentServiceNftId = (logRegistrationInfoCmpt as unknown);
    logger.info(`componentServiceManager deployed - componentServiceAddress: ${componentServiceAddress} componentServiceManagerAddress: ${componentServiceManagerAddress} nftId: ${componentServiceNftId}`);

    logger.info("-------- distribution service --------");
    const { 
        address: distributionServiceManagerAddress, 
        contract: distributionServiceManagerBaseContract,
        deploymentTransaction: distributionServiceManagerDeploymentTransaction
    } = await deployContract(
        "DistributionServiceManager",
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
                ReferralLib: libraries.referralLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});
    
    const distributionServiceManager = distributionServiceManagerBaseContract as DistributionServiceManager;
    const distributionServiceAddress = await distributionServiceManager.getDistributionService();
    const distributionServiceImplementationAddress = await distributionServiceManager.getImplementation();
    const distributionService = DistributionService__factory.connect(distributionServiceAddress, owner);

    logger.info("Verifying distribution service implementation");
    /*
    await deployContract(
        "DistributionService",
        owner,
        [],
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
    */
    await addDeployedContract(
        "DistributionService",
        "DistributionService",
        distributionServiceImplementationAddress,
        owner, //signer
        distributionServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                AmountLib: libraries.amountLibAddress,
                DistributorTypeLib: libraries.distributorTypeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ReferralLib: libraries.referralLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    logger.info("Verifying distribution service proxy");
    await addDeployedContract(
        "DistributionServiceProxy",
        "UpgradableProxyWithAdmin",
        distributionServiceAddress,
        owner, //signer
        distributionServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const rcptDs = await executeTx(async () => await releaseManager.registerService(distributionServiceAddress));
    const logRegistrationInfoDs = getFieldFromTxRcptLogs(rcptDs!, registry.registry.interface, "LogRegistration", "nftId");
    const distributionServiceNftId = (logRegistrationInfoDs as unknown);
    await distributionServiceManager.linkToProxy();
    logger.info(`distributionServiceManager deployed - distributionServiceAddress: ${distributionServiceAddress} distributionServiceManagerAddress: ${distributionServiceManagerAddress} nftId: ${distributionServiceNftId}`);

    logger.info("-------- pricing service --------");
    const { 
        address: pricingServiceManagerAddress, 
        contract: pricingServiceManagerBaseContract, 
        deploymentTransaction: pricingServiceManagerDeploymentTransaction
    } = await deployContract(
        "PricingServiceManager",
        "PricingServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
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
    const pricingServiceImplementationAddress = await pricingServiceManager.getImplementation();
    const pricingService = PricingService__factory.connect(pricingServiceAddress, owner);

    logger.info("Verifying pricing service implementation");
    /*
    await deployContract(
        "PricingService",
        owner,
        [],
        { libraries: { 
            NftIdLib: libraries.nftIdLibAddress,
            AmountLib: libraries.amountLibAddress,
            UFixedLib: libraries.uFixedLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
    }});
    */
    await addDeployedContract(
        "PricingService",
        "PricingService",
        pricingServiceImplementationAddress,
        owner, //signer
        pricingServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                AmountLib: libraries.amountLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });
    
    logger.info("Verifying pricing service proxy");
    await addDeployedContract(
        "PricingServiceProxy",
        "UpgradableProxyWithAdmin",
        pricingServiceAddress,
        owner, //signer
        pricingServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const rcptPrs = await executeTx(async () => await releaseManager.registerService(pricingServiceAddress));
    const logRegistrationInfoPrs = getFieldFromTxRcptLogs(rcptPrs!, registry.registry.interface, "LogRegistration", "nftId");
    const pricingServiceNftId = (logRegistrationInfoPrs as unknown);
    await pricingServiceManager.linkToProxy();
    logger.info(`pricingServiceManager deployed - pricingServiceAddress: ${pricingServiceAddress} pricingServiceManagerAddress: ${pricingServiceManagerAddress} nftId: ${pricingServiceNftId}`);

    logger.info("-------- bundle service --------");
    const { 
        address: bundleServiceManagerAddress, 
        contract: bundleServiceManagerBaseContract, 
        deploymentTransaction: bundleServiceManagerDeploymentTransaction
    } = await deployContract(
        "BundleServiceManager",
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
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});

    const bundleServiceManager = bundleServiceManagerBaseContract as BundleServiceManager;
    const bundleServiceAddress = await bundleServiceManager.getBundleService();
    const bundleServiceImplementationAddress = await bundleServiceManager.getImplementation();
    const bundleService = BundleService__factory.connect(bundleServiceAddress, owner);

    logger.info("Verifying bundle service implementation");
    /*
    await deployContract(
        "BundleService",
        owner,
        [],
        { libraries: { 
            AmountLib: libraries.amountLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
    }});
    */
    await addDeployedContract(
        "BundleService",
        "BundleService",
        bundleServiceImplementationAddress,
        owner, //signer
        bundleServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                AmountLib: libraries.amountLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });
    
    logger.info("Verifying bundle service proxy");
    await addDeployedContract(
        "BundleServiceProxy",
        "UpgradableProxyWithAdmin",
        bundleServiceAddress,
        owner, //signer
        bundleServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const rcptBdl = await executeTx(async () => await releaseManager.registerService(bundleServiceAddress));
    const logRegistrationInfoBdl = getFieldFromTxRcptLogs(rcptBdl!, registry.registry.interface, "LogRegistration", "nftId");
    const bundleServiceNftId = (logRegistrationInfoBdl as unknown);
    await bundleServiceManager.linkToProxy();
    logger.info(`bundleServiceManager deployed - bundleServiceAddress: ${bundleServiceAddress} bundleServiceManagerAddress: ${bundleServiceManagerAddress} nftId: ${bundleServiceNftId}`);

    logger.info("-------- pool service --------");
    const { 
        address: poolServiceManagerAddress, 
        contract: poolServiceManagerBaseContract, 
        deploymentTransaction: poolServiceManagerDeploymentTransaction
    } = await deployContract(
        "PoolServiceManager",
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
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});
    
    const poolServiceManager = poolServiceManagerBaseContract as PoolServiceManager;
    const poolServiceAddress = await poolServiceManager.getPoolService();
    const poolServiceImplementationAddress = await poolServiceManager.getImplementation();
    const poolService = PoolService__factory.connect(poolServiceAddress, owner);

    logger.info("Verifying pool service implementation");
    /*
    await deployContract(
        "PoolService",
        owner,
        [],
        { libraries: { 
            AmountLib: libraries.amountLibAddress,
            FeeLib: libraries.feeLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
    }});
    */
    await addDeployedContract(
        "PoolService",
        "PoolService",
        poolServiceImplementationAddress,
        owner, //signer
        poolServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                AmountLib: libraries.amountLibAddress,
                FeeLib: libraries.feeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    logger.info("Verifying pool service proxy");
    await addDeployedContract(
        "PoolServiceProxy",
        "UpgradableProxyWithAdmin",
        poolServiceAddress,
        owner, //signer
        poolServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const rcptPs = await executeTx(async () => await releaseManager.registerService(poolServiceAddress));
    const logRegistrationInfoPs = getFieldFromTxRcptLogs(rcptPs!, registry.registry.interface, "LogRegistration", "nftId");
    const poolServiceNftId = (logRegistrationInfoPs as unknown);
    await poolServiceManager.linkToProxy();
    logger.info(`poolServiceManager deployed - poolServiceAddress: ${poolServiceAddress} poolServiceManagerAddress: ${poolServiceManagerAddress} nftId: ${poolServiceNftId}`);

    logger.info("-------- product service --------");
    const { 
        address: productServiceManagerAddress, 
        contract: productServiceManagerBaseContract, 
        deploymentTransaction: productServiceManagerDeploymentTransaction
    } = await deployContract(
        "ProductServiceManager",
        "ProductServiceManager",
        owner,
        [
            release.accessManager,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});

    const productServiceManager = productServiceManagerBaseContract as ProductServiceManager;
    const productServiceAddress = await productServiceManager.getProductService();
    const productServiceImplementationAddress = await productServiceManager.getImplementation();
    const productService = ProductService__factory.connect(productServiceAddress, owner);

    logger.info("Verifying product service implementation");
    /*
    await deployContract(
        "ProductService",
        owner,
        [],
        { libraries: { 
            NftIdLib: libraries.nftIdLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
    }});
    */
    await addDeployedContract(
        "ProductService",
        "ProductService",
        productServiceImplementationAddress,
        owner, //signer
        productServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    logger.info("Verifying product service proxy");
    await addDeployedContract(
        "ProductServiceProxy",
        "UpgradableProxyWithAdmin",
        productServiceAddress,
        owner, //signer
        productServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const rcptPrd = await executeTx(async () => await releaseManager.registerService(productServiceAddress));
    const logRegistrationInfoPrd = getFieldFromTxRcptLogs(rcptPrd!, registry.registry.interface, "LogRegistration", "nftId");
    const productServiceNftId = (logRegistrationInfoPrd as unknown);
    await productServiceManager.linkToProxy();
    logger.info(`productServiceManager deployed - productServiceAddress: ${productServiceAddress} productServiceManagerAddress: ${productServiceManagerAddress} nftId: ${productServiceNftId}`);

    logger.info("-------- claim service --------");
    const { 
        address: claimServiceManagerAddress, 
        contract: claimServiceManagerBaseContract,
        deploymentTransaction: claimServiceManagerDeploymentTransaction
    } = await deployContract(
        "ClaimServiceManager",
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
                TimestampLib: libraries.timestampLibAddress,
                PayoutIdLib: libraries.payoutIdLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});

    const claimServiceManager = claimServiceManagerBaseContract as ClaimServiceManager;
    const claimServiceAddress = await claimServiceManager.getClaimService();
    const claimServiceImplementationAddress = await claimServiceManager.getImplementation();
    const claimService = ClaimService__factory.connect(claimServiceAddress, owner);

    logger.info("Verifying claim service implementation");
    /*
    await deployContract(
        "ClaimService",
        owner,
        [],
        { libraries: { 
            AmountLib: libraries.amountLibAddress,
            ClaimIdLib: libraries.claimIdLibAddress,
            FeeLib: libraries.feeLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            PayoutIdLib: libraries.payoutIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
    }});
    */
    await addDeployedContract(
        "ClaimService",
        "ClaimService",
        claimServiceImplementationAddress,
        owner, //signer
        claimServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                AmountLib: libraries.amountLibAddress,
                ClaimIdLib: libraries.claimIdLibAddress,
                FeeLib: libraries.feeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                PayoutIdLib: libraries.payoutIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    logger.info("Verifying claim service proxy");
    await addDeployedContract(
        "ClaimServiceProxy",
        "UpgradableProxyWithAdmin",
        claimServiceAddress,
        owner, //signer
        claimServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const rcptClm = await executeTx(async () => await releaseManager.registerService(claimServiceAddress));
    const logRegistrationInfoClm = getFieldFromTxRcptLogs(rcptClm!, registry.registry.interface, "LogRegistration", "nftId");
    const claimServiceNftId = (logRegistrationInfoClm as unknown);
    await claimServiceManager.linkToProxy();
    logger.info(`claimServiceManager deployed - claimServiceAddress: ${claimServiceAddress} claimServiceManagerAddress: ${claimServiceManagerAddress} nftId: ${claimServiceNftId}`);

    logger.info("-------- application service --------");
    const { 
        address: applicationServiceManagerAddress, 
        contract: applicationServiceManagerBaseContract, 
        deploymentTransaction: applicationServiceManagerDeploymentTransaction
    } = await deployContract(
        "ApplicationServiceManager",
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
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
            VersionPartLib: libraries.versionPartLibAddress, 
        }});

    const applicationServiceManager = applicationServiceManagerBaseContract as ApplicationServiceManager;
    const applicationServiceAddress = await applicationServiceManager.getApplicationService();
    const applicationServiceImplementationAddress = await applicationServiceManager.getImplementation();
    const applicationService = ApplicationService__factory.connect(applicationServiceAddress, owner);

    logger.info("Verifying application service implementation");
    /*
    await deployContract(
        "ApplicationService",
        owner,
        [],
        { libraries: { 
            AmountLib: libraries.amountLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
    }});
    */
    await addDeployedContract(
        "ApplicationService",
        "ApplicationService",
        applicationServiceImplementationAddress,
        owner, //signer
        applicationServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                AmountLib: libraries.amountLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });
    
    logger.info("Verifying application service proxy");
    await addDeployedContract(
        "ApplicationServiceProxy",
        "UpgradableProxyWithAdmin",
        applicationServiceAddress,
        owner, //signer
        applicationServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const rcptAppl = await executeTx(async () => await releaseManager.registerService(applicationServiceAddress));
    const logRegistrationInfoAppl = getFieldFromTxRcptLogs(rcptAppl!, registry.registry.interface, "LogRegistration", "nftId");
    const applicationServiceNftId = (logRegistrationInfoAppl as unknown);
    await applicationServiceManager.linkToProxy();
    logger.info(`applicationServiceManager deployed - applicationServiceAddress: ${applicationServiceAddress} policyServiceManagerAddress: ${applicationServiceManagerAddress} nftId: ${applicationServiceNftId}`);

    logger.info("-------- policy service --------");
    const { 
        address: policyServiceManagerAddress, 
        contract: policyServiceManagerBaseContract, 
        deploymentTransaction: policyServiceManagerDeploymentTransaction
    } = await deployContract(
        "PolicyServiceManager",
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
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
            VersionPartLib: libraries.versionPartLibAddress, 
        }});

    const policyServiceManager = policyServiceManagerBaseContract as PolicyServiceManager;
    const policyServiceAddress = await policyServiceManager.getPolicyService();
    const policyServiceImplementationAddress = await policyServiceManager.getImplementation();
    const policyService = PolicyService__factory.connect(policyServiceAddress, owner);

    logger.info("Verifying policy service implementation");
    /*
    await deployContract(
        "PolicyService",
        owner,
        [],
        { libraries: { 
            AmountLib: libraries.amountLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
    }});
    */
    await addDeployedContract(
        "PolicyService",
        "PolicyService",
        policyServiceImplementationAddress,
        owner, //signer
        policyServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                AmountLib: libraries.amountLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    logger.info("Verifying policy service proxy");
    await addDeployedContract(
        "PolicyServiceProxy",
        "UpgradableProxyWithAdmin",
        policyServiceAddress,
        owner, //signer
        policyServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

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

        stakingServiceNftId: stakingServiceNftId as string,
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

        distributionServiceNftId: distributionServiceNftId as string,
        distributionServiceAddress: distributionServiceAddress,
        distributionService: distributionService,
        distributionServiceManagerAddress: distributionServiceManagerAddress,

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
    };
}