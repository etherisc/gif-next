
import { getImplementationAddress } from '@openzeppelin/upgrades-core';
import { AddressLike, BytesLike, Signer, id } from "ethers";
import { ethers as hhEthers } from "hardhat";
import {
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
    RiskService, RiskServiceManager, RiskService__factory,
    RegistryService,
    RegistryServiceManager,
    RegistryService__factory,
    StakingService, StakingServiceManager, StakingService__factory,
    AccountingService__factory,
    AccountingServiceManager,
    AccountingService
} from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
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
    logger.info(`Release created - version: ${release.version} salt: ${release.salt} access manager: ${release.accessManager}`);

    logger.info("======== Starting deployment of services ========");
    const releaseRegistry = await registry.releaseRegistry.connect(owner);
    logger.info("-------- registry service --------");
    const authority = await registry.registryAdmin.authority();
    const { address: registryServiceManagerAddress, contract: registryServiceManagerBaseContract } = await deployContract(
        "RegistryServiceManager",
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
                VersionPartLib: libraries.versionPartLibAddress,
            }});

    const registryServiceManager = registryServiceManagerBaseContract as RegistryServiceManager;
    const registryServiceAddress = await registryServiceManager.getRegistryService();
    const registryService = RegistryService__factory.connect(registryServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "RegistryService", 
        await getImplementationAddress(hhEthers.provider, await registryServiceManager.getProxy()), 
        [], 
        undefined);

    const rcptRs = await executeTx(
        async () => await releaseRegistry.registerService(registryServiceAddress, getTxOpts()),
        "registerService - registryService"
    );
    const logRegistrationInfoRs = getFieldFromTxRcptLogs(rcptRs!, registry.registry.interface, "LogRegistration", "nftId");
    const registryServiceNfdId = (logRegistrationInfoRs as unknown);

    // is not NftOwnable
    //await registry.tokenRegistry.linkToRegistryService();

    logger.info(`registryServiceManager deployed - registryServiceAddress: ${registryServiceAddress} registryServiceManagerAddress: ${registryServiceManagerAddress} nftId: ${registryServiceNfdId}`);

    logger.info("-------- staking service --------");
    const { address: stakingServiceManagerAddress, contract: stakingServiceManagerBaseContract, } = await deployContract(
        "StakingServiceManager",
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
            VersionPartLib: libraries.versionPartLibAddress,
        }});

    const stakingServiceManager = stakingServiceManagerBaseContract as StakingServiceManager;
    const stakingServiceAddress = await stakingServiceManager.getStakingService();
    const stakingService = StakingService__factory.connect(stakingServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "StakingService", 
        await getImplementationAddress(hhEthers.provider, await stakingServiceManager.getProxy()), 
        [], 
        undefined);

    const rcptStk = await executeTx(
        async () => await releaseRegistry.registerService(stakingServiceAddress, getTxOpts()),
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
    const { address: instanceServiceManagerAddress, contract: instanceServiceManagerBaseContract, } = await deployContract(
        "InstanceServiceManager",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: { 
            ContractLib: libraries.contractLibAddress,
            NftIdLib: libraries.nftIdLibAddress, 
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
            TargetManagerLib: libraries.targetManagerLibAddress,
        }});

    const instanceServiceManager = instanceServiceManagerBaseContract as InstanceServiceManager;
    const instanceServiceAddress = await instanceServiceManager.getInstanceService();
    const instanceService = InstanceService__factory.connect(instanceServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "InstanceService", 
        await getImplementationAddress(hhEthers.provider, await instanceServiceManager.getProxy()), 
        [], 
        undefined);

    const rcptInst = await executeTx(
        async () => await releaseRegistry.registerService(instanceServiceAddress, getTxOpts()),
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
    const { address: accountingServiceManagerAddress, contract: accountingServiceManagerBaseContract, } = await deployContract(
        "AccountingServiceManager",
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
            VersionPartLib: libraries.versionPartLibAddress,
        }});
    
    const accountingServiceManager = accountingServiceManagerBaseContract as AccountingServiceManager;
    const accountingServiceAddress = await accountingServiceManager.getAccountingService();
    const accountingService = AccountingService__factory.connect(accountingServiceAddress, owner);

    // verify service implementation
    prepareVerificationData(
        "AccountingService", 
        await getImplementationAddress(hhEthers.provider, await accountingServiceManager.getProxy()), 
        [], 
        undefined);
    
    const rcptAcct = await executeTx(
        async () => await releaseRegistry.registerService(accountingServiceAddress, getTxOpts()),
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
    const { address: componentServiceManagerAddress, contract: componentServiceManagerBaseContract, } = await deployContract(
        "ComponentServiceManager",
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
            VersionPartLib: libraries.versionPartLibAddress,
        }});

    const componentServiceManager = componentServiceManagerBaseContract as ComponentServiceManager;
    const componentServiceAddress = await componentServiceManager.getComponentService();
    const componentService = ComponentService__factory.connect(componentServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "ComponentService", 
        await getImplementationAddress(hhEthers.provider, await componentServiceManager.getProxy()), 
        [], 
        undefined);

    const rcptCmpt = await executeTx(
        async () => await releaseRegistry.registerService(componentServiceAddress, getTxOpts()),
        "registerService - componentService"
    );
    const logRegistrationInfoCmpt = getFieldFromTxRcptLogs(rcptCmpt!, registry.registry.interface, "LogRegistration", "nftId");
    const componentServiceNftId = (logRegistrationInfoCmpt as unknown);
    logger.info(`componentServiceManager deployed - componentServiceAddress: ${componentServiceAddress} componentServiceManagerAddress: ${componentServiceManagerAddress} nftId: ${componentServiceNftId}`);

    logger.info("-------- distribution service --------");
    const { address: distributionServiceManagerAddress, contract: distributionServiceManagerBaseContract, } = await deployContract(
        "DistributionServiceManager",
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
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});
    
    const distributionServiceManager = distributionServiceManagerBaseContract as DistributionServiceManager;
    const distributionServiceAddress = await distributionServiceManager.getDistributionService();
    const distributionService = DistributionService__factory.connect(distributionServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "DistributuonService", 
        await getImplementationAddress(hhEthers.provider, await distributionServiceManager.getProxy()), 
        [], 
        undefined);

    const rcptDs = await executeTx(
        async () => await releaseRegistry.registerService(distributionServiceAddress, getTxOpts()),
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
    const { address: pricingServiceManagerAddress, contract: pricingServiceManagerBaseContract, } = await deployContract(
        "PricingServiceManager",
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
                TimestampLib: libraries.timestampLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress,
                AmountLib: libraries.amountLibAddress
            }});
    
    const pricingServiceManager = pricingServiceManagerBaseContract as PricingServiceManager;
    const pricingServiceAddress = await pricingServiceManager.getPricingService();
    const pricingService = PricingService__factory.connect(pricingServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "PricingService", 
        await getImplementationAddress(hhEthers.provider, await pricingServiceManager.getProxy()), 
        [], 
        undefined);

    const rcptPrs = await executeTx(
        async () => await releaseRegistry.registerService(pricingServiceAddress, getTxOpts()),
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
    const { address: bundleServiceManagerAddress, contract: bundleServiceManagerBaseContract, } = await deployContract(
        "BundleServiceManager",
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
                VersionPartLib: libraries.versionPartLibAddress, 
            }});

    const bundleServiceManager = bundleServiceManagerBaseContract as BundleServiceManager;
    const bundleServiceAddress = await bundleServiceManager.getBundleService();
    const bundleService = BundleService__factory.connect(bundleServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "BundleService", 
        await getImplementationAddress(hhEthers.provider, await bundleServiceManager.getProxy()), 
        [], 
        undefined);

    const rcptBdl = await executeTx(
        async () => await releaseRegistry.registerService(bundleServiceAddress, getTxOpts()),
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
    const { address: poolServiceManagerAddress, contract: poolServiceManagerBaseContract, } = await deployContract(
        "PoolServiceManager",
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
                // ObjectTypeLib: libraries.objectTypeLibAddress, 
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                UFixedLib: libraries.uFixedLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});
    
    const poolServiceManager = poolServiceManagerBaseContract as PoolServiceManager;
    const poolServiceAddress = await poolServiceManager.getPoolService();
    const poolService = PoolService__factory.connect(poolServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "PoolService", 
        await getImplementationAddress(hhEthers.provider, await poolServiceManager.getProxy()), 
        [], 
        undefined);

    const rcptPs = await executeTx(
        async () => await releaseRegistry.registerService(poolServiceAddress, getTxOpts()),
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
    const { address: oracleServiceManagerAddress, contract: oracleServiceManagerBaseContract, } = await deployContract(
        "OracleServiceManager",
        owner,
        [
            authority,
            registry.registryAddress,
            release.salt
        ],
        { libraries: {
            ContractLib: libraries.contractLibAddress,
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

    // verify service implementation 
    prepareVerificationData(
        "OracleService", 
        await getImplementationAddress(hhEthers.provider, await oracleServiceManager.getProxy()), 
        [], 
        undefined);

    const orclPrs = await executeTx(
        async () => await releaseRegistry.registerService(oracleServiceAddress, getTxOpts()),
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
    const { address: riskServiceManagerAddress, contract: riskServiceManagerBaseContract, } = await deployContract(
        "RiskServiceManager",
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
            TimestampLib: libraries.timestampLibAddress,
            VersionLib: libraries.versionLibAddress, 
            VersionPartLib: libraries.versionPartLibAddress, 
        }});

    const riskServiceManager = riskServiceManagerBaseContract as RiskServiceManager;
    const riskServiceAddress = await riskServiceManager.getRiskService();
    const riskService = RiskService__factory.connect(riskServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "RiskService", 
        await getImplementationAddress(hhEthers.provider, await riskServiceManager.getProxy()), 
        [], 
        undefined);

    const rcptPrd = await executeTx(
        async () => await releaseRegistry.registerService(riskServiceAddress, getTxOpts()),
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
    const { address: policyServiceManagerAddress, contract: policyServiceManagerBaseContract, } = await deployContract(
        "PolicyServiceManager",
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
            VersionPartLib: libraries.versionPartLibAddress, 
        }});

    const policyServiceManager = policyServiceManagerBaseContract as PolicyServiceManager;
    const policyServiceAddress = await policyServiceManager.getPolicyService();
    const policyService = PolicyService__factory.connect(policyServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "PolicyService", 
        await getImplementationAddress(hhEthers.provider, await policyServiceManager.getProxy()), 
        [], 
        undefined);

    const rcptPol = await executeTx(
        async () => await releaseRegistry.registerService(policyServiceAddress, getTxOpts()),
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
    const { address: claimServiceManagerAddress, contract: claimServiceManagerBaseContract, } = await deployContract(
        "ClaimServiceManager",
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
                FeeLib: libraries.feeLibAddress,
                NftIdLib: libraries.nftIdLibAddress,
                RoleIdLib: libraries.roleIdLibAddress,
                TimestampLib: libraries.timestampLibAddress,
                PayoutIdLib: libraries.payoutIdLibAddress,
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
            }});

    const claimServiceManager = claimServiceManagerBaseContract as ClaimServiceManager;
    const claimServiceAddress = await claimServiceManager.getClaimService();
    const claimService = ClaimService__factory.connect(claimServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "ClaimService", 
        await getImplementationAddress(hhEthers.provider, await claimServiceManager.getProxy()), 
        [], 
        undefined);

    const rcptClm = await executeTx(
        async () => await releaseRegistry.registerService(claimServiceAddress, getTxOpts()),
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
    const { address: applicationServiceManagerAddress, contract: applicationServiceManagerBaseContract, } = await deployContract(
        "ApplicationServiceManager",
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
            VersionPartLib: libraries.versionPartLibAddress, 
        }});

    const applicationServiceManager = applicationServiceManagerBaseContract as ApplicationServiceManager;
    const applicationServiceAddress = await applicationServiceManager.getApplicationService();
    const applicationService = ApplicationService__factory.connect(applicationServiceAddress, owner);

    // verify service implementation 
    prepareVerificationData(
        "ApplicationService", 
        await getImplementationAddress(hhEthers.provider, await applicationServiceManager.getProxy()), 
        [], 
        undefined);
    
    const rcptAppl = await executeTx(
        async () => await releaseRegistry.registerService(applicationServiceAddress, getTxOpts()),
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
        async () => await releaseRegistry.activateNextRelease(getTxOpts()),
        "releaseRegistry.activateNextRelease",
        [releaseRegistry.interface]
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