
import { getImplementationAddress } from '@openzeppelin/upgrades-core';
import { AddressLike, BytesLike, Signer, id } from "ethers";
import { ethers as hhEthers } from "hardhat";
import {
    AccountingService, AccountingServiceManager, AccountingService__factory,
    ApplicationService, ApplicationServiceManager, ApplicationService__factory,
    BundleService, BundleServiceManager, BundleService__factory,
    ClaimService, ClaimServiceManager, ClaimService__factory,
    ComponentService, ComponentServiceManager, ComponentService__factory,
    DistributionService, DistributionServiceManager, DistributionService__factory,
    InstanceService, InstanceServiceManager, InstanceService__factory,
    OracleService, OracleServiceManager, OracleService__factory,
    PolicyService, PolicyServiceManager, PolicyService__factory,
    PoolService, PoolServiceManager, PoolService__factory,
    PricingService, PricingServiceManager, PricingService__factory,
    RegistryService,
    RegistryServiceManager,
    RegistryService__factory,
    RiskService, RiskServiceManager, RiskService__factory,
    StakingService, StakingServiceManager, StakingService__factory
} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract, deployProxyManagerContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { createRelease } from "./release";
import { executeTx, getFieldFromTxRcptLogs, getTxOpts } from "./transaction";
import { prepareVerificationData } from './verification';


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
            registry.registryAddress,
            release.salt
        ],
        { libraries: { 
                ContractLib: libraries.contractLibAddress,
                NftIdLib: libraries.nftIdLibAddress, 
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress,
            }});

    const registryService = RegistryService__factory.connect(registryServiceAddress, owner);

    const rcptRs = await executeTx(
        async () => await registry.releaseRegistry.registerService(registryServiceAddress, getTxOpts()),
        "registerService - registryService"
    );
    const logRegistrationInfoRs = getFieldFromTxRcptLogs(rcptRs!, registry.registry.interface, "LogRegistration", "nftId");
    const registryServiceNfdId = (logRegistrationInfoRs as unknown);

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
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
        }});

    const stakingServiceManager = stakingServiceManagerBaseContract as StakingServiceManager;
    const stakingService = StakingService__factory.connect(stakingServiceAddress, owner);

    const rcptStk = await executeTx(
        async () => await registry.releaseRegistry.registerService(stakingServiceAddress, getTxOpts()),
        "registerService - stakingService"
    );
    const logRegistrationInfoStk = getFieldFromTxRcptLogs(rcptStk!, registry.registry.interface, "LogRegistration", "nftId");
    const stakingServiceNftId = (logRegistrationInfoStk as unknown);
    await executeTx(
        async () => await stakingServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - stakingService"
    );
    logger.info(`stakingServiceManager deployed - stakingServiceAddress: ${stakingServiceAddress} stakingServiceManagerAddress: ${stakingServiceManagerAddress} nftId: ${stakingServiceNftId}`);

    logger.info("-------- instance service --------");
    const { address: instanceServiceManagerAddress, contract: instanceServiceManagerBaseContract, proxyAddress: instanceServiceAddress } = await deployProxyManagerContract(
        "InstanceServiceManager",
        "InstanceService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: { 
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

    const rcptInst = await executeTx(
        async () => await registry.releaseRegistry.registerService(instanceServiceAddress, getTxOpts()),
        "registerService - instanceService"
    );
    const logRegistrationInfoInst = getFieldFromTxRcptLogs(rcptInst!, registry.registry.interface, "LogRegistration", "nftId");
    const instanceServiceNfdId = (logRegistrationInfoInst as unknown);
    await executeTx(
        async () => await instanceServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - instanceService"
    );
    logger.info(`instanceServiceManager deployed - instanceServiceAddress: ${instanceServiceAddress} instanceServiceManagerAddress: ${instanceServiceManagerAddress} nftId: ${instanceServiceNfdId}`);

    logger.info("-------- accounting service --------");
    const { address: accountingServiceManagerAddress, contract: accountingServiceManagerBaseContract, proxyAddress: accountingServiceAddress } = await deployProxyManagerContract(
        "AccountingServiceManager",
        "AccountingService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: { 
            AmountLib: libraries.amountLibAddress,
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress, 
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
        }});
    
    const accountingServiceManager = accountingServiceManagerBaseContract as AccountingServiceManager;
    const accountingService = AccountingService__factory.connect(accountingServiceAddress, owner);
    
    const rcptAcct = await executeTx(
        async () => await registry.releaseRegistry.registerService(accountingServiceAddress, getTxOpts()),
        "registerService - accountingService"
    );
    const logRegistrationInfoAcct = getFieldFromTxRcptLogs(rcptAcct!, registry.registry.interface, "LogRegistration", "nftId");
    const accountingServiceNfdId = (logRegistrationInfoAcct as unknown);
    await executeTx(
        async () => await accountingServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - accountingService"
    );
    logger.info(`accountingServiceManager deployed - accountingServiceAddress: ${accountingServiceAddress} accountingServiceManagerAddress: ${accountingServiceManagerAddress} nftId: ${accountingServiceNfdId}`);

    logger.info("-------- component service --------");
    const { address: componentServiceManagerAddress, contract: componentServiceManagerBaseContract, proxyAddress: componentServiceAddress } = await deployProxyManagerContract(
        "ComponentServiceManager",
        "ComponentService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: { 
            AmountLib: libraries.amountLibAddress,
            ContractLib: libraries.contractLibAddress,
            FeeLib: libraries.feeLibAddress,
            NftIdLib: libraries.nftIdLibAddress, 
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            TokenHandlerDeployerLib: libraries.tokenHandlerDeployerLibAddress,
            VersionLib: libraries.versionLibAddress,
        }});

    const componentServiceManager = componentServiceManagerBaseContract as ComponentServiceManager;
    const componentService = ComponentService__factory.connect(componentServiceAddress, owner);

    const rcptCmpt = await executeTx(
        async () => await registry.releaseRegistry.registerService(componentServiceAddress, getTxOpts()),
        "registerService - componentService"
    );
    const logRegistrationInfoCmpt = getFieldFromTxRcptLogs(rcptCmpt!, registry.registry.interface, "LogRegistration", "nftId");
    const componentServiceNftId = (logRegistrationInfoCmpt as unknown);
    logger.info(`componentServiceManager deployed - componentServiceAddress: ${componentServiceAddress} componentServiceManagerAddress: ${componentServiceManagerAddress} nftId: ${componentServiceNftId}`);

    logger.info("-------- distribution service --------");
    const { address: distributionServiceManagerAddress, contract: distributionServiceManagerBaseContract, proxyAddress: distributionServiceAddress } = await deployProxyManagerContract(
        "DistributionServiceManager",
        "DistributionService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                ContractLib: libraries.contractLibAddress,
                DistributorTypeLib: libraries.distributorTypeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                ReferralLib: libraries.referralLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                SecondsLib: libraries.secondsLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});
    
    const distributionServiceManager = distributionServiceManagerBaseContract as DistributionServiceManager;
    const distributionService = DistributionService__factory.connect(distributionServiceAddress, owner);

    const rcptDs = await executeTx(
        async () => await registry.releaseRegistry.registerService(distributionServiceAddress, getTxOpts()),
        "registerService - distributionService"
    );
    const logRegistrationInfoDs = getFieldFromTxRcptLogs(rcptDs!, registry.registry.interface, "LogRegistration", "nftId");
    const distributionServiceNftId = (logRegistrationInfoDs as unknown);
    await executeTx(
        async () => await distributionServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - distributionService"
    );
    logger.info(`distributionServiceManager deployed - distributionServiceAddress: ${distributionServiceAddress} distributionServiceManagerAddress: ${distributionServiceManagerAddress} nftId: ${distributionServiceNftId}`);

    logger.info("-------- pricing service --------");
    const { address: pricingServiceManagerAddress, contract: pricingServiceManagerBaseContract, proxyAddress: pricingServiceAddress } = await deployProxyManagerContract(
        "PricingServiceManager",
        "PricingService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
        }});
    
    const pricingServiceManager = pricingServiceManagerBaseContract as PricingServiceManager;
    const pricingService = PricingService__factory.connect(pricingServiceAddress, owner);

    const rcptPrs = await executeTx(
        async () => await registry.releaseRegistry.registerService(pricingServiceAddress, getTxOpts()),
        "registerService - pricingService"
    );
    const logRegistrationInfoPrs = getFieldFromTxRcptLogs(rcptPrs!, registry.registry.interface, "LogRegistration", "nftId");
    const pricingServiceNftId = (logRegistrationInfoPrs as unknown);
    await executeTx(
        async () => await pricingServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - pricingService"
    );
    logger.info(`pricingServiceManager deployed - pricingServiceAddress: ${pricingServiceAddress} pricingServiceManagerAddress: ${pricingServiceManagerAddress} nftId: ${pricingServiceNftId}`);

    logger.info("-------- bundle service --------");
    const { address: bundleServiceManagerAddress, contract: bundleServiceManagerBaseContract, proxyAddress: bundleServiceAddress } = await deployProxyManagerContract(
        "BundleServiceManager",
        "BundleService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                ContractLib: libraries.contractLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                SecondsLib: libraries.secondsLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});

    const bundleServiceManager = bundleServiceManagerBaseContract as BundleServiceManager;
    const bundleService = BundleService__factory.connect(bundleServiceAddress, owner);

    const rcptBdl = await executeTx(
        async () => await registry.releaseRegistry.registerService(bundleServiceAddress, getTxOpts()),
        "registerService - bundleService"
    );
    const logRegistrationInfoBdl = getFieldFromTxRcptLogs(rcptBdl!, registry.registry.interface, "LogRegistration", "nftId");
    const bundleServiceNftId = (logRegistrationInfoBdl as unknown);
    await executeTx(
        async () => await bundleServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - bundleService"
    );
    logger.info(`bundleServiceManager deployed - bundleServiceAddress: ${bundleServiceAddress} bundleServiceManagerAddress: ${bundleServiceManagerAddress} nftId: ${bundleServiceNftId}`);

    logger.info("-------- pool service --------");
    const { address: poolServiceManagerAddress, contract: poolServiceManagerBaseContract, proxyAddress: poolServiceAddress } = await deployProxyManagerContract(
        "PoolServiceManager",
        "PoolService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                ContractLib: libraries.contractLibAddress,
                PoolLib: libraries.poolLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});
    
    const poolServiceManager = poolServiceManagerBaseContract as PoolServiceManager;
    const poolService = PoolService__factory.connect(poolServiceAddress, owner);

    const rcptPs = await executeTx(
        async () => await registry.releaseRegistry.registerService(poolServiceAddress, getTxOpts()),
        "registerService - poolService"
    );
    const logRegistrationInfoPs = getFieldFromTxRcptLogs(rcptPs!, registry.registry.interface, "LogRegistration", "nftId");
    const poolServiceNftId = (logRegistrationInfoPs as unknown);
    await executeTx(
        async () => await poolServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - poolService"
    );
    logger.info(`poolServiceManager deployed - poolServiceAddress: ${poolServiceAddress} poolServiceManagerAddress: ${poolServiceManagerAddress} nftId: ${poolServiceNftId}`);

    logger.info("-------- oracle service --------");
    const { address: oracleServiceManagerAddress, contract: oracleServiceManagerBaseContract, proxyAddress: oracleServiceAddress } = await deployProxyManagerContract(
        "OracleServiceManager",
        "OracleService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
                RequestIdLib: libraries.requestIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});
    
    const oracleServiceManager = oracleServiceManagerBaseContract as OracleServiceManager;
    const oracleService = OracleService__factory.connect(oracleServiceAddress, owner);

    const orclPrs = await executeTx(
        async () => await registry.releaseRegistry.registerService(oracleServiceAddress, getTxOpts()),
        "registerService - oracleService"
    );
    const logRegistrationInfoOrc = getFieldFromTxRcptLogs(orclPrs!, registry.registry.interface, "LogRegistration", "nftId");
    const oracleServiceNftId = (logRegistrationInfoOrc as unknown);
    await executeTx(
        async () => await oracleServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - oracleService"
    );
    logger.info(`oracleServiceManager deployed - oracleServiceAddress: ${oracleServiceAddress} oracleServiceManagerAddress: ${oracleServiceManagerAddress} nftId: ${oracleServiceNftId}`);

    logger.info("-------- product service --------");
    const { address: riskServiceManagerAddress, contract: riskServiceManagerBaseContract, proxyAddress: riskServiceAddress } = await deployProxyManagerContract(
        "RiskServiceManager",
        "RiskService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            RiskIdLib: libraries.riskIdLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
        }});

    const riskServiceManager = riskServiceManagerBaseContract as RiskServiceManager;
    const riskService = RiskService__factory.connect(riskServiceAddress, owner);

    const rcptPrd = await executeTx(
        async () => await registry.releaseRegistry.registerService(riskServiceAddress, getTxOpts()),
        "registerService - riskService"
    );
    const logRegistrationInfoPrd = getFieldFromTxRcptLogs(rcptPrd!, registry.registry.interface, "LogRegistration", "nftId");
    const riskServiceNftId = (logRegistrationInfoPrd as unknown);
    await executeTx(
        async () => await riskServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - riskService"
    );
    logger.info(`riskServiceManager deployed - riskServiceAddress: ${riskServiceAddress} riskServiceManagerAddress: ${riskServiceManagerAddress} nftId: ${riskServiceNftId}`);

    logger.info("-------- policy service --------");
    const { address: policyServiceManagerAddress, contract: policyServiceManagerBaseContract, proxyAddress: policyServiceAddress } = await deployProxyManagerContract(
        "PolicyServiceManager",
        "PolicyService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            PolicyServiceLib: libraries.policyServiceLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
        }});

    const policyServiceManager = policyServiceManagerBaseContract as PolicyServiceManager;
    const policyService = PolicyService__factory.connect(policyServiceAddress, owner);

    const rcptPol = await executeTx(
        async () => await registry.releaseRegistry.registerService(policyServiceAddress, getTxOpts()),
        "registerService - policyService"
    );
    const logRegistrationInfoPol = getFieldFromTxRcptLogs(rcptPol!, registry.registry.interface, "LogRegistration", "nftId");
    const policyServiceNftId = (logRegistrationInfoPol as unknown);
    await executeTx(
        async () => await policyServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - policyService"
    );
    logger.info(`policyServiceManager deployed - policyServiceAddress: ${policyServiceAddress} policyServiceManagerAddress: ${policyServiceManagerAddress} nftId: ${policyServiceNftId}`);

    logger.info("-------- claim service --------");
    const { address: claimServiceManagerAddress, contract: claimServiceManagerBaseContract, proxyAddress: claimServiceAddress } = await deployProxyManagerContract(
        "ClaimServiceManager",
        "ClaimService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
                AmountLib: libraries.amountLibAddress,
                ClaimIdLib: libraries.claimIdLibAddress,
                ContractLib: libraries.contractLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                PayoutIdLib: libraries.payoutIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
            }});

    const claimServiceManager = claimServiceManagerBaseContract as ClaimServiceManager;
    const claimService = ClaimService__factory.connect(claimServiceAddress, owner);

    const rcptClm = await executeTx(
        async () => await registry.releaseRegistry.registerService(claimServiceAddress, getTxOpts()),
        "registerService - claimService"
    );
    const logRegistrationInfoClm = getFieldFromTxRcptLogs(rcptClm!, registry.registry.interface, "LogRegistration", "nftId");
    const claimServiceNftId = (logRegistrationInfoClm as unknown);
    await executeTx(
        async () => await claimServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - claimService"
    );
    logger.info(`claimServiceManager deployed - claimServiceAddress: ${claimServiceAddress} claimServiceManagerAddress: ${claimServiceManagerAddress} nftId: ${claimServiceNftId}`);

    logger.info("-------- application service --------");
    const { address: applicationServiceManagerAddress, contract: applicationServiceManagerBaseContract, proxyAddress: applicationServiceAddress } = await deployProxyManagerContract(
        "ApplicationServiceManager",
        "ApplicationService",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
            AmountLib: libraries.amountLibAddress,
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress,
            ReferralLib: libraries.referralLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
        }});

    const applicationServiceManager = applicationServiceManagerBaseContract as ApplicationServiceManager;
    const applicationService = ApplicationService__factory.connect(applicationServiceAddress, owner);
    
    const rcptAppl = await executeTx(
        async () => await registry.releaseRegistry.registerService(applicationServiceAddress, getTxOpts()),
        "registerService - applicationService"
    );
    const logRegistrationInfoAppl = getFieldFromTxRcptLogs(rcptAppl!, registry.registry.interface, "LogRegistration", "nftId");
    const applicationServiceNftId = (logRegistrationInfoAppl as unknown);
    await executeTx(
        async () => await applicationServiceManager.linkToProxy(getTxOpts()),
        "linkToProxy - applicationService"
    );
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
        registryServiceNftId: registryServiceNfdId as string,
        registryServiceAddress: registryServiceAddress,
        registryService: registryService,
        registryServiceManagerAddress: registryServiceManagerAddress,

        instanceServiceNftId: instanceServiceNfdId as string,
        instanceServiceAddress: instanceServiceAddress,
        instanceService: instanceService,
        instanceServiceManagerAddress: instanceServiceManagerAddress,

        accountingServiceNftId: accountingServiceNfdId as string,
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