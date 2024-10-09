
import { AddressLike, BytesLike, Signer, id } from "ethers";
import {
    AccountingService, AccountingServiceManager, AccountingService__factory,
    ApplicationService, ApplicationServiceManager, ApplicationService__factory,
    BundleService, BundleServiceManager, BundleService__factory,
    ClaimService, ClaimServiceManager, ClaimService__factory,
    ComponentService,
    ComponentService__factory,
    DistributionService, DistributionServiceManager, DistributionService__factory,
    IRegistry__factory,
    InstanceService, InstanceServiceManager, InstanceService__factory,
    OracleService, OracleServiceManager, OracleService__factory,
    PolicyService, PolicyServiceManager, PolicyService__factory,
    PoolService, PoolServiceManager, PoolService__factory,
    PricingService, PricingServiceManager, PricingService__factory,
    ProxyManager,
    RegistryService,
    RegistryService__factory,
    ReleaseRegistry,
    RiskService, RiskServiceManager, RiskService__factory,
    StakingService, StakingServiceManager, StakingService__factory
} from "../../typechain-types";
import { logger } from "../logger";
import { deployProxyManagerContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { createRelease } from "./release";
import { executeTx, getFieldFromTxRcptLogs, getTxOpts } from "./transaction";


export type ServiceAddresses = {
    registryServiceNftId: string,
    registryServiceAddress: AddressLike,
    registryService: RegistryService,
    registryServiceManagerAddress: AddressLike,

    instanceServiceNftId: string,
    instanceServiceAddress: AddressLike,
    instanceService: InstanceService,
    instanceServiceManagerAddress: AddressLike,

    accountingServiceNftId: string,
    accountingServiceAddress: AddressLike,
    accountingService: AccountingService,
    accountingServiceManagerAddress: AddressLike,

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

    riskServiceNftId: string,
    riskServiceAddress: AddressLike,
    riskService: RiskService,
    riskServiceManagerAddress: AddressLike,

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
    const release = await createRelease(owner, registry, salt);
    logger.info(`Release created - version: ${release.version} salt: ${release.salt} admin: ${release.adminAddress}`);

    logger.info("======== Starting deployment of services ========");
    logger.info("-------- registry service --------");
    const authority = await release.admin.authority();
    const { address: registryServiceManagerAddress, contract: registryServiceManagerBaseContract, proxyAddress: registryServiceAddress } = await deployProxyManagerContract(
        "RegistryServiceManager",
        "RegistryService",
        owner,
        [
            authority, // address itself can be a salt like value
            release.salt
        ],
        { libraries: { 
                BlocknumberLib: libraries.blockNumberLibAddress,
                ContractLib: libraries.contractLibAddress,
                NftIdLib: libraries.nftIdLibAddress, 
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }});

    const registryService = RegistryService__factory.connect(registryServiceAddress, owner);

    const rcptRs = await executeTx(
        async () => await registry.releaseRegistry.registerService(registryServiceAddress, getTxOpts()),
        "registerService - registryService"
    );
    const logRegistrationInfoRs = getFieldFromTxRcptLogs(rcptRs!, registry.registry.interface, "LogRegistryObjectRegistered", "nftId");
    const registryServiceNfdId = (logRegistrationInfoRs as string);

    // is not NftOwnable
    //await registry.tokenRegistry.linkToRegistryService();

    logger.info(`registryServiceManager deployed - registryServiceAddress: ${registryServiceAddress} registryServiceManagerAddress: ${registryServiceManagerAddress} nftId: ${registryServiceNfdId}`);

    logger.info("-------- staking service --------");
    const { address: stakingServiceManagerAddress, contract: stakingServiceManagerBaseContract, proxyAddress: stakingServiceAddress } = await deployProxyManagerContract(
        "StakingServiceManager",
        "StakingService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: {
            BlocknumberLib: libraries.blockNumberLibAddress,
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            ObjectTypeLib: libraries.objectTypeLibAddress, 
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
        }});

    const stakingServiceManager = stakingServiceManagerBaseContract as StakingServiceManager;
    const stakingService = StakingService__factory.connect(stakingServiceAddress, owner);

    const stakingServiceNftId = await registerAndLinkService(registry.releaseRegistry, stakingServiceAddress, stakingServiceManager);
    logger.info(`stakingServiceManager deployed - stakingServiceAddress: ${stakingServiceAddress} stakingServiceManagerAddress: ${stakingServiceManagerAddress} nftId: ${stakingServiceNftId}`);

    logger.info("-------- instance service --------");
    const { address: instanceServiceManagerAddress, contract: instanceServiceManagerBaseContract, proxyAddress: instanceServiceAddress } = await deployProxyManagerContract(
        "InstanceServiceManager",
        "InstanceService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: { 
            BlocknumberLib: libraries.blockNumberLibAddress,
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress, 
            RoleIdLib: libraries.roleIdLibAddress,
            TargetManagerLib: libraries.targetManagerLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
        }});

    const instanceServiceManager = instanceServiceManagerBaseContract as InstanceServiceManager;
    const instanceService = InstanceService__factory.connect(instanceServiceAddress, owner);

    const instanceServiceNftId = await registerAndLinkService(registry.releaseRegistry, instanceServiceAddress, instanceServiceManager);
    logger.info(`instanceServiceManager deployed - instanceServiceAddress: ${instanceServiceAddress} instanceServiceManagerAddress: ${instanceServiceManagerAddress} nftId: ${instanceServiceNftId}`);

    logger.info("-------- accounting service --------");
    const { address: accountingServiceManagerAddress, contract: accountingServiceManagerBaseContract, proxyAddress: accountingServiceAddress } = await deployProxyManagerContract(
        "AccountingServiceManager",
        "AccountingService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: { 
            AmountLib: libraries.amountLibAddress,
            BlocknumberLib: libraries.blockNumberLibAddress,
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress, 
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            ObjectTypeLib: libraries.objectTypeLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
        }});
    
    const accountingServiceManager = accountingServiceManagerBaseContract as AccountingServiceManager;
    const accountingService = AccountingService__factory.connect(accountingServiceAddress, owner);
    const accountingServiceNftId = await registerAndLinkService(registry.releaseRegistry, accountingServiceAddress, accountingServiceManager);
    logger.info(`accountingServiceManager deployed - accountingServiceAddress: ${accountingServiceAddress} accountingServiceManagerAddress: ${accountingServiceManagerAddress} nftId: ${accountingServiceNftId}`);

    logger.info("-------- component service --------");
    const { address: componentServiceManagerAddress, contract: componentServiceManagerBaseContract, proxyAddress: componentServiceAddress } = await deployProxyManagerContract(
        "ComponentServiceManager",
        "ComponentService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: { 
            AmountLib: libraries.amountLibAddress,
            BlocknumberLib: libraries.blockNumberLibAddress,
            ChainIdLib: libraries.chainIdLibAddress,
            ContractLib: libraries.contractLibAddress,
            FeeLib: libraries.feeLibAddress,
            NftIdLib: libraries.nftIdLibAddress, 
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            TokenHandlerDeployerLib: libraries.tokenHandlerDeployerLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
        }});

    const componentService = ComponentService__factory.connect(componentServiceAddress, owner);

    const rcptCmpt = await executeTx(
        async () => await registry.releaseRegistry.registerService(componentServiceAddress, getTxOpts()),
        "registerService - componentService"
    );
    const logRegistrationInfoCmpt = getFieldFromTxRcptLogs(rcptCmpt!, registry.registry.interface, "LogRegistryObjectRegistered", "nftId");
    const componentServiceNftId = (logRegistrationInfoCmpt as unknown);
    logger.info(`componentServiceManager deployed - componentServiceAddress: ${componentServiceAddress} componentServiceManagerAddress: ${componentServiceManagerAddress} nftId: ${componentServiceNftId}`);

    logger.info("-------- distribution service --------");
    const { address: distributionServiceManagerAddress, contract: distributionServiceManagerBaseContract, proxyAddress: distributionServiceAddress } = await deployProxyManagerContract(
        "DistributionServiceManager",
        "DistributionService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress,
                ContractLib: libraries.contractLibAddress,
                DistributorTypeLib: libraries.distributorTypeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ReferralLib: libraries.referralLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                SecondsLib: libraries.secondsLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
                VersionLib: libraries.versionLibAddress, 
                ObjectTypeLib: libraries.objectTypeLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }});
    
    const distributionServiceManager = distributionServiceManagerBaseContract as DistributionServiceManager;
    const distributionService = DistributionService__factory.connect(distributionServiceAddress, owner);
    const distributionServiceNftId = await registerAndLinkService(registry.releaseRegistry, distributionServiceAddress, distributionServiceManager);
    logger.info(`distributionServiceManager deployed - distributionServiceAddress: ${distributionServiceAddress} distributionServiceManagerAddress: ${distributionServiceManagerAddress} nftId: ${distributionServiceNftId}`);

    logger.info("-------- pricing service --------");
    const { address: pricingServiceManagerAddress, contract: pricingServiceManagerBaseContract, proxyAddress: pricingServiceAddress } = await deployProxyManagerContract(
        "PricingServiceManager",
        "PricingService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            BlocknumberLib: libraries.blockNumberLibAddress,
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
            ObjectTypeLib: libraries.objectTypeLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
        }});
    
    const pricingServiceManager = pricingServiceManagerBaseContract as PricingServiceManager;
    const pricingService = PricingService__factory.connect(pricingServiceAddress, owner);
    const pricingServiceNftId = await registerAndLinkService(registry.releaseRegistry, pricingServiceAddress, pricingServiceManager);
    logger.info(`pricingServiceManager deployed - pricingServiceAddress: ${pricingServiceAddress} pricingServiceManagerAddress: ${pricingServiceManagerAddress} nftId: ${pricingServiceNftId}`);

    logger.info("-------- bundle service --------");
    const { address: bundleServiceManagerAddress, contract: bundleServiceManagerBaseContract, proxyAddress: bundleServiceAddress } = await deployProxyManagerContract(
        "BundleServiceManager",
        "BundleService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress,
                ContractLib: libraries.contractLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                SecondsLib: libraries.secondsLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
                ObjectTypeLib: libraries.objectTypeLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }});

    const bundleServiceManager = bundleServiceManagerBaseContract as BundleServiceManager;
    const bundleService = BundleService__factory.connect(bundleServiceAddress, owner);
    const bundleServiceNftId = await registerAndLinkService(registry.releaseRegistry, bundleServiceAddress, bundleServiceManager);
    logger.info(`bundleServiceManager deployed - bundleServiceAddress: ${bundleServiceAddress} bundleServiceManagerAddress: ${bundleServiceManagerAddress} nftId: ${bundleServiceNftId}`);

    logger.info("-------- pool service --------");
    const { address: poolServiceManagerAddress, contract: poolServiceManagerBaseContract, proxyAddress: poolServiceAddress } = await deployProxyManagerContract(
        "PoolServiceManager",
        "PoolService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress,
                ContractLib: libraries.contractLibAddress,
                PoolLib: libraries.poolLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
                ObjectTypeLib: libraries.objectTypeLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }});
    
    const poolServiceManager = poolServiceManagerBaseContract as PoolServiceManager;
    const poolService = PoolService__factory.connect(poolServiceAddress, owner);
    const poolServiceNftId = await registerAndLinkService(registry.releaseRegistry, poolServiceAddress, poolServiceManager);
    logger.info(`poolServiceManager deployed - poolServiceAddress: ${poolServiceAddress} poolServiceManagerAddress: ${poolServiceManagerAddress} nftId: ${poolServiceNftId}`);

    logger.info("-------- oracle service --------");
    const { address: oracleServiceManagerAddress, contract: oracleServiceManagerBaseContract, proxyAddress: oracleServiceAddress } = await deployProxyManagerContract(
        "OracleServiceManager",
        "OracleService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: {
            ContractLib: libraries.contractLibAddress,
            BlocknumberLib: libraries.blockNumberLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            RequestIdLib: libraries.requestIdLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
            VersionPartLib: libraries.versionPartLibAddress,
        }});
    
    const oracleServiceManager = oracleServiceManagerBaseContract as OracleServiceManager;
    const oracleService = OracleService__factory.connect(oracleServiceAddress, owner);
    const oracleServiceNftId = await registerAndLinkService(registry.releaseRegistry, oracleServiceAddress, oracleServiceManager);
    logger.info(`oracleServiceManager deployed - oracleServiceAddress: ${oracleServiceAddress} oracleServiceManagerAddress: ${oracleServiceManagerAddress} nftId: ${oracleServiceNftId}`);

    logger.info("-------- risk service --------");
    const { address: riskServiceManagerAddress, contract: riskServiceManagerBaseContract, proxyAddress: riskServiceAddress} = await deployProxyManagerContract(
        "RiskServiceManager",
        "RiskService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: {
            ContractLib: libraries.contractLibAddress,
            BlocknumberLib: libraries.blockNumberLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            RiskIdLib: libraries.riskIdLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
            VersionPartLib: libraries.versionPartLibAddress, 
        }});

    const riskServiceManager = riskServiceManagerBaseContract as RiskServiceManager;
    const riskService = RiskService__factory.connect(riskServiceAddress, owner);
    const riskServiceNftId = await registerAndLinkService(registry.releaseRegistry, riskServiceAddress, riskServiceManager);
    logger.info(`riskServiceManager deployed - riskServiceAddress: ${riskServiceAddress} riskServiceManagerAddress: ${riskServiceManagerAddress} nftId: ${riskServiceNftId}`);

    logger.info("-------- policy service --------");
    const { address: policyServiceManagerAddress, contract: policyServiceManagerBaseContract, proxyAddress: policyServiceAddress } = await deployProxyManagerContract(
        "PolicyServiceManager",
        "PolicyService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            BlocknumberLib: libraries.blockNumberLibAddress,
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            PolicyServiceLib: libraries.policyServiceLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
            ObjectTypeLib: libraries.objectTypeLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
        }});

    const policyServiceManager = policyServiceManagerBaseContract as PolicyServiceManager;
    const policyService = PolicyService__factory.connect(policyServiceAddress, owner);
    const policyServiceNftId = await registerAndLinkService(registry.releaseRegistry, policyServiceAddress, policyServiceManager);
    logger.info(`policyServiceManager deployed - policyServiceAddress: ${policyServiceAddress} policyServiceManagerAddress: ${policyServiceManagerAddress} nftId: ${policyServiceNftId}`);

    logger.info("-------- claim service --------");
    const { address: claimServiceManagerAddress, contract: claimServiceManagerBaseContract, proxyAddress: claimServiceAddress } = await deployProxyManagerContract(
        "ClaimServiceManager",
        "ClaimService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress,
                ClaimIdLib: libraries.claimIdLibAddress,
                ContractLib: libraries.contractLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                PayoutIdLib: libraries.payoutIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
                ObjectTypeLib: libraries.objectTypeLibAddress,
                VersionPartLib: libraries.versionPartLibAddress,
            }});

    const claimServiceManager = claimServiceManagerBaseContract as ClaimServiceManager;
    const claimService = ClaimService__factory.connect(claimServiceAddress, owner);
    const claimServiceNftId = await registerAndLinkService(registry.releaseRegistry, claimServiceAddress, claimServiceManager);
    logger.info(`claimServiceManager deployed - claimServiceAddress: ${claimServiceAddress} claimServiceManagerAddress: ${claimServiceManagerAddress} nftId: ${claimServiceNftId}`);

    logger.info("-------- application service --------");
    const { address: applicationServiceManagerAddress, contract: applicationServiceManagerBaseContract, proxyAddress: applicationServiceAddress } = await deployProxyManagerContract(
        "ApplicationServiceManager",
        "ApplicationService",
        owner,
        [
            authority,
            release.salt
        ],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            BlocknumberLib: libraries.blockNumberLibAddress,
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            ReferralLib: libraries.referralLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
            ObjectTypeLib: libraries.objectTypeLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
        }});

    const applicationServiceManager = applicationServiceManagerBaseContract as ApplicationServiceManager;
    const applicationService = ApplicationService__factory.connect(applicationServiceAddress, owner);
    const applicationServiceNftId = await registerAndLinkService(registry.releaseRegistry, applicationServiceAddress, applicationServiceManager);
    logger.info(`applicationServiceManager deployed - applicationServiceAddress: ${applicationServiceAddress} policyServiceManagerAddress: ${applicationServiceManagerAddress} nftId: ${applicationServiceNftId}`);
    
    logger.info("======== Finished deployment of services ========");

    logger.info("======== Activating release ========");
    await executeTx(
        async () => await registry.releaseRegistry.activateNextRelease(getTxOpts()),
        "releaseRegistry.activateNextRelease",
        [registry.releaseRegistry.interface]
    );
    logger.info("======== release activated ========");

    return {
        registryServiceNftId: registryServiceNfdId,
        registryServiceAddress: registryServiceAddress,
        registryService: registryService,
        registryServiceManagerAddress: registryServiceManagerAddress,

        instanceServiceNftId: instanceServiceNftId,
        instanceServiceAddress: instanceServiceAddress,
        instanceService: instanceService,
        instanceServiceManagerAddress: instanceServiceManagerAddress,

        accountingServiceNftId: accountingServiceNftId as string,
        accountingServiceAddress: accountingServiceAddress,
        accountingService: accountingService,
        accountingServiceManagerAddress: accountingServiceManagerAddress,

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

        riskServiceNftId: riskServiceNftId as string,
        riskServiceAddress: riskServiceAddress,
        riskService: riskService,
        riskServiceManagerAddress: riskServiceManagerAddress,

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

async function registerAndLinkService(releaseRegistry: ReleaseRegistry, serviceAddress: AddressLike, proxyManager: ProxyManager): Promise<string> {
    const rcptBdl = await executeTx(
        async () => await releaseRegistry.registerService(serviceAddress, getTxOpts()),
        `registerService - ${serviceAddress}`
    );
    const logRegistrationInfo = getFieldFromTxRcptLogs(rcptBdl!, IRegistry__factory.createInterface(), "LogRegistryObjectRegistered", "nftId");
    const serviceNftId = (logRegistrationInfo as unknown);
    await executeTx(
        async () => await proxyManager.linkToProxy(getTxOpts()),
        `linkToProxy - ${await proxyManager.getAddress()}`
    );

    return serviceNftId as string;
}