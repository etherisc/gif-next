
import { AddressLike, BytesLike, Signer, resolveAddress, id, TransactionResponse, TransactionReceipt } from "ethers";
import { tenderly } from "hardhat";
import {
    Registry, Registry__factory,
    ReleaseManager, ReleaseManager__factory, ProxyManager,
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
import { deploymentState, isResumeableDeployment } from "./deployment_state";
import { LibraryAddresses } from "./libraries";
import { CoreAddresses } from "./registry";
import { executeTx, getFieldFromTxRcptLogs } from "./transaction";
import { getReleaseConfig, createRelease, activateRelease } from "./release";


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

// get service address from proxy manager then address -> name
async function registerService(owner: Signer, serviceName: string, serviceManager: ProxyManager, releaseManager: ReleaseManager): Promise<string>
{
    deploymentState.requireDeployed(serviceName);

    const serviceAddress = deploymentState.getContractAddress(serviceName)!;
    const registry = Registry__factory.connect(await releaseManager.getRegistry(), owner);
    let rcpt;

    if(!isResumeableDeployment) {
        logger.info(`Registering new ${serviceName}`);
        rcpt = await executeTx(async () => await releaseManager.registerService(serviceAddress));
        logger.debug(`${serviceName} is registered`);
        serviceManager.linkToProxy();
    } else {
        logger.info(`Trying to register ${serviceName}`);
        
        const isRegistered = await registry["isRegistered(address)"](serviceAddress);
        if(!isRegistered) {
            //serviceNftId = await _tryRegisterService(serviceName, releaseManager);
            //logger.debug(`${serviceName} is registered`);
            //_tryLinkToProxy(serviceManager);
            rcpt = await executeTx(async () => await releaseManager.registerService(serviceAddress));
            logger.debug(`${serviceName} is registered`);
            serviceManager.linkToProxy();
        } else {
            logger.info(`${serviceName} is already registered`);
            logger.info(`Assume service manager is already linked`);
            return await registry["getNftId(address)"](serviceAddress) as string;
        }
    }

    const serviceNftId = getFieldFromTxRcptLogs(rcpt!, registry.interface, "LogRegistration", "nftId") as string;
    return serviceNftId;
}
/*
async function _tryLinkToProxy(proxyManager: ProxyManager): Promise<ContractTransactionReceipt> {
    let rcpt;
    try {
        rcpt = await executeTx(async () => await proxyManager.linkToProxy());
    } catch (error) {
        logger.error(`Error linking to proxy with proxy manager ${await proxyManager.getAddress()}\n       ${error}`);
    } finally {
        return rcpt;
    }
}

async function _tryRegisterService(serviceName: string, releaseManager: ReleaseManager): Promise<any>
{
    let serviceNftId;
    let rcpt;
    const registry = Registry__factory.connect(await releaseManager.getRegistry());
    const serviceAddress = deploymentState.getContractAddress(serviceName)!;

    try{
        rcpt = await executeTx(async () => await releaseManager.registerService(serviceAddress));
        const logRegistrationInfo = getFieldFromTxRcptLogs(rcpt!, registry.interface, "LogRegistration", "nftId");
        serviceNftId = (logRegistrationInfo as unknown);
    } catch (error) {
        logger.error(`Error registering ${serviceName} at ${serviceAddress} with ReleaseManager ${await releaseManager.getAddress()} and Registry ${await registry.getAddress()}\n       ${error}`);
    } finally {
        return ({ nftId: serviceNftId, receipt: rcpt });
    }
}
*/

export async function deployRelease(owner: Signer, registry: CoreAddresses, libraries: LibraryAddresses): Promise<ServiceAddresses> 
{
    logger.info("======== Starting release creation ========");
    const registryContract = registry.registry.connect(owner);
    const releaseManager = registry.releaseManager.connect(owner);
    //const salt = zeroPadBytes("0x03", 32);
    const salt: BytesLike = id(`0x5678`);
    const config = await getReleaseConfig(owner, registry, libraries, salt);
    const release = await createRelease(releaseManager, config, salt);
    logger.info(`Release created - version: ${release.version} salt: ${release.salt} access manager: ${release.accessManager}`);

    logger.info("======== Starting deployment of services ========");
    logger.info("-------- registry service --------");
    const { 
        address: registryServiceManagerAddress, 
        contract: registryServiceManagerBaseContract,
        deploymentTransaction: registryServiceManagerDeploymentTransaction
    } = await deployContract(
        "RegistryServiceManager", // name
        "RegistryServiceManager", // type
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

    await addDeployedContract(
        "RegistryServiceImplementation",
        "RegistryService",
        registryServiceImplementationAddress,
        registryServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    await addDeployedContract(
        "RegistryServiceProxy",
        "UpgradableProxyWithAdmin",
        registryServiceAddress,
        registryServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const registryServiceNftId = await registerService(owner, "RegistryServiceProxy", registryServiceManager, releaseManager);

    logger.info(`RegistryServiceManager deployed - registryServiceAddress: ${registryServiceAddress} registryServiceManagerAddress: ${registryServiceManagerAddress} NftId: ${registryServiceNftId}`);



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

    await addDeployedContract(
        "StakingServiceImplementation",
        "StakingService",
        stakingServiceImplementationAddress,
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

    await addDeployedContract(
        "StakingServiceProxy",
        "UpgradableProxyWithAdmin",
        stakingServiceAddress,
        stakingServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const stakingServiceNftId = await registerService(owner, "StakingServiceProxy", stakingServiceManager, releaseManager);

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

    await addDeployedContract(
        "InstanceServiceImplementation",
        "InstanceService",
        instanceServiceImplementationAddress,
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

    await addDeployedContract(
        "InstanceServiceProxy",
        "UpgradableProxyWithAdmin",
        instanceServiceAddress,
        instanceServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const instanceServiceNftId = await registerService(owner, "InstanceServiceProxy", instanceServiceManager, releaseManager);

    logger.info(`instanceServiceManager deployed - instanceServiceAddress: ${instanceServiceAddress} instanceServiceManagerAddress: ${instanceServiceManagerAddress} nftId: ${instanceServiceNftId}`);



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

    await addDeployedContract(
        "ComponentServiceImplementation",
        "ComponentService",
        componentServiceImplementationAddress,
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

    await addDeployedContract(
        "ComponentServiceProxy",
        "UpgradableProxyWithAdmin",
        componentServiceAddress,
        componentServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const componentServiceNftId = await registerService(owner, "ComponentServiceProxy", componentServiceManager, releaseManager);

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

    await addDeployedContract(
        "DistributionServiceImplementation",
        "DistributionService",
        distributionServiceImplementationAddress,
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

    await addDeployedContract(
        "DistributionServiceProxy",
        "UpgradableProxyWithAdmin",
        distributionServiceAddress,
        distributionServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const distributionServiceNftId = await registerService(owner, "DistributionServiceProxy", distributionServiceManager, releaseManager, registryContract);

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

    await addDeployedContract(
        "PricingServiceImplementation",
        "PricingService",
        pricingServiceImplementationAddress,
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
    
    await addDeployedContract(
        "PricingServiceProxy",
        "UpgradableProxyWithAdmin",
        pricingServiceAddress,
        pricingServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const pricingServiceNftdId = await registerService(owner, "PricingServiceProxy", pricingServiceManager, releaseManager, registryContract);

    logger.info(`pricingServiceManager deployed - pricingServiceAddress: ${pricingServiceAddress} pricingServiceManagerAddress: ${pricingServiceManagerAddress} nftId: ${pricingServiceNftdId}`);



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

    await addDeployedContract(
        "BundleServiceImplementation",
        "BundleService",
        bundleServiceImplementationAddress,
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
    
    await addDeployedContract(
        "BundleServiceProxy",
        "UpgradableProxyWithAdmin",
        bundleServiceAddress,
        bundleServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const bundleServiceNftId = await registerService(owner, "BundleServiceProxy", bundleServiceManager, releaseManager, registryContract);

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

    await addDeployedContract(
        "PoolServiceImplementation",
        "PoolService",
        poolServiceImplementationAddress,
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

    await addDeployedContract(
        "PoolServiceProxy",
        "UpgradableProxyWithAdmin",
        poolServiceAddress,
        poolServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const poolServiceNftId = await registerService(owner, "PoolServiceProxy", poolServiceManager, releaseManager, registryContract);

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

    await addDeployedContract(
        "ProductServiceImplementation",
        "ProductService",
        productServiceImplementationAddress,
        productServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }
        });

    await addDeployedContract(
        "ProductServiceProxy",
        "UpgradableProxyWithAdmin",
        productServiceAddress,
        productServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const productServiceNftId = await registerService(owner, "ProductServiceProxy", productServiceManager, releaseManager, registryContract);

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

    await addDeployedContract(
        "ClaimServiceImplementation",
        "ClaimService",
        claimServiceImplementationAddress,
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

    await addDeployedContract(
        "ClaimServiceProxy",
        "UpgradableProxyWithAdmin",
        claimServiceAddress,
        claimServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const claimServiceNftId = await registerService(owner, "ClaimServiceProxy", claimServiceManager, releaseManager, registryContract);

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

    await addDeployedContract(
        "ApplicationServiceImplementation",
        "ApplicationService",
        applicationServiceImplementationAddress,
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
    
    await addDeployedContract(
        "ApplicationServiceProxy",
        "UpgradableProxyWithAdmin",
        applicationServiceAddress,
        applicationServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const applicationServiceNftId = await registerService(owner, "ApplicationServiceProxy", applicationServiceManager, releaseManager, registryContract);

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

    await addDeployedContract(
        "PolicyServiceImplementation",
        "PolicyService",
        policyServiceImplementationAddress,
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

    await addDeployedContract(
        "PolicyServiceProxy",
        "UpgradableProxyWithAdmin",
        policyServiceAddress,
        policyServiceManagerDeploymentTransaction as TransactionResponse,
        [],// constructor args
        {
            libraries: {
            }
        });

    const policyServiceNftId = await registerService(owner, "PolicyServiceProxy", policyServiceManager, releaseManager, registryContract);

    logger.info(`policyServiceManager deployed - policyServiceAddress: ${policyServiceAddress} policyServiceManagerAddress: ${policyServiceManagerAddress} nftId: ${policyServiceNftId}`);

    logger.info("======== Finished deployment of services ========");




    logger.info("======== Activating release ========");
    await activateRelease(releaseManager);
    //_tryActivateRelease(releaseManager);
    // release already was activated
    //await releaseManager.activateNextRelease();
    logger.info("======== release activated ========");

    return {
        registryServiceNftId: registryServiceNftId as string,
        registryServiceAddress: registryServiceAddress,
        registryService: registryService,
        registryServiceManagerAddress: registryServiceManagerAddress,

        stakingServiceNftId: stakingServiceNftId as string,
        stakingServiceAddress: stakingServiceAddress,
        stakingService: stakingService,
        stakingServiceManagerAddress: stakingServiceManagerAddress,

        instanceServiceNftId: instanceServiceNftId as string,
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