
import { AddressLike, BigNumberish, BytesLike, Signer } from "ethers";
import { logger } from "../logger";
import { RegistryAddresses } from "./registry";
import { executeTx, getFieldFromTxRcptLogs, getTxOpts } from "./transaction";


export type ReleaseAddresses = {
    registryServiceAddress: AddressLike,
    registryServiceManagerAddress: AddressLike,
    stakingServiceAddress: AddressLike,
    stakingServiceManagerAddress: AddressLike
    instanceServiceAddress: AddressLike,
    instanceServiceManagerAddress: AddressLike,
    componentServiceAddress: AddressLike,
    componentServiceManagerAddress: AddressLike,
    oracleServiceAddress: AddressLike,
    oracleServiceManagerAddress: AddressLike,
    distributionServiceAddress: AddressLike,
    distributionServiceManagerAddress: AddressLike,
    poolServiceAddress: AddressLike,
    poolServiceManagerAddress: AddressLike,
    productServiceAddress: AddressLike,
    productServiceManagerAddress: AddressLike,
    applicationServiceAddress: AddressLike,
    applicationServiceManagerAddress: AddressLike,
    policyServiceAddress: AddressLike,
    policyServiceManagerAddress: AddressLike,
    claimServiceAddress: AddressLike,
    claimServiceManagerAddress: AddressLike,
    bundleServiceAddress: AddressLike,
    bundleServiceManagerAddress: AddressLike,
    pricingServiceAddress: AddressLike,
    pricingServiceManagerAddress: AddressLike,
};

function logReleaseAddresses(release: ReleaseAddresses): void {
    logger.info(`registryServiceAddress: ${release.registryServiceAddress}`);
    logger.info(`registryServiceManagerAddress: ${release.registryServiceManagerAddress}`);
    logger.info(`stakingServiceAddress: ${release.stakingServiceAddress}`);
    logger.info(`stakingServiceManagerAddress: ${release.stakingServiceManagerAddress}`);
    logger.info(`instanceServiceAddress: ${release.instanceServiceAddress}`);
    logger.info(`instanceServiceManagerAddress: ${release.instanceServiceManagerAddress}`);
    logger.info(`componentServiceAddress: ${release.componentServiceAddress}`);
    logger.info(`componentServiceManagerAddress: ${release.componentServiceManagerAddress}`);
    logger.info(`oracleServiceAddress: ${release.oracleServiceAddress}`);
    logger.info(`oracleServiceManagerAddress: ${release.oracleServiceManagerAddress}`);
    logger.info(`distributionServiceAddress: ${release.distributionServiceAddress}`);
    logger.info(`distributionServiceManagerAddress: ${release.distributionServiceManagerAddress}`);
    logger.info(`poolServiceAddress: ${release.poolServiceAddress}`);
    logger.info(`poolServiceManagerAddress: ${release.poolServiceManagerAddress}`);
    logger.info(`productServiceAddress: ${release.productServiceAddress}`);
    logger.info(`productServiceManagerAddress: ${release.productServiceManagerAddress}`);
    logger.info(`applicationServiceAddress: ${release.applicationServiceAddress}`);
    logger.info(`applicationServiceManagerAddress: ${release.applicationServiceManagerAddress}`);
    logger.info(`policyServiceAddress: ${release.policyServiceAddress}`);
    logger.info(`policyServiceManagerAddress: ${release.policyServiceManagerAddress}`);
    logger.info(`claimServiceAddress: ${release.claimServiceAddress}`);
    logger.info(`claimServiceManagerAddress: ${release.claimServiceManagerAddress}`);
    logger.info(`bundleServiceAddress: ${release.bundleServiceAddress}`);
    logger.info(`bundleServiceManagerAddress: ${release.bundleServiceManagerAddress}`);
}

export const roles = {
    INSTANCE_OWNER_ROLE: 1900,
    INSTANCE_SERVICE_ROLE: 2000,
    COMPONENT_SERVICE_ROLE: 2001,
    ORACLE_SERVICE_ROLE: 2005,
    DISTRIBUTION_SERVICE_ROLE: 2100,
    POOL_SERVICE_ROLE: 2200,
    PRODUCT_SERVICE_ROLE: 2300,
    APPLICATION_SERVICE_ROLE: 2400,
    POLICY_SERVICE_ROLE: 2410,
    CLAIM_SERVICE_ROLE: 2420,
    BUNDLE_SERVICE_ROLE: 2500,
    INSTANCE_ROLE: 2600,
    REGISTRY_SERVICE_ROLE: 1800,
    STAKING_SERVICE_ROLE: 2900,
    CAN_CREATE_GIF_TARGET_ROLE: 1700,
    PRICING_SERVICE_ROLE: 2800
};

export const roleNames = {
    INSTANCE_OWNER_ROLE_NAME: "InstanceOwnerRole",
    INSTANCE_SERVICE_ROLE_NAME: "InstanceServiceRole",
    DISTRIBUTION_SERVICE_ROLE_NAME: "DistributionServiceRole",
    COMPONENT_SERVICE_ROLE_NAME: "ComponentServiceRole",
    ORACLE_SERVICE_ROLE_NAME: "OracleServiceRole",
    POOL_SERVICE_ROLE_NAME: "PoolServiceRole",
    PRODUCT_SERVICE_ROLE_NAME: "ProductServiceRole",
    APPLICATION_SERVICE_ROLE_NAME: "ApplicationServiceRole",
    POLICY_SERVICE_ROLE_NAME: "PolicyServiceRole",
    CLAIM_SERVICE_ROLE_NAME: "ClaimServiceRole",
    BUNDLE_SERVICE_ROLE_NAME: "BundleServiceRole",
    INSTANCE_ROLE_NAME: "InstanceRole",
    REGISTRY_SERVICE_ROLE_NAME: "RegistryServiceRole",
    STAKING_SERVICE_ROLE_NAME: "StakingServiceRole",
    CAN_CREATE_GIF_TARGET_ROLE_NAME: "CanCreateGifTargetRole",
    PRICING_SERVICE_ROLE_NAME: "PricingServiceRole"
};

export const serviceNames = {
    INSTANCE_SERVICE_NAME: "InstanceService",
    DISTRIBUTION_SERVICE_NAME: "DistributionService",
    POOL_SERVICE_NAME: "PoolService",
    PRODUCT_SERVICE_NAME: "ProductService",
    APPLICATION_SERVICE_NAME: "ApplicationService",
    POLICY_SERVICE_NAME: "PolicyService",
    CLAIM_SERVICE_NAME: "ClaimService",
    BUNDLE_SERVICE_NAME: "BundleService",
    PRICING_SERVICE_NAME: "PricingService",
    ORACLE_SERVICE_NAME: "OracleService",
    COMPONENT_SERVICE_NAME: "ComponentService",
    STAKING_SERVICE_NAME: "StakingService",
    REGISTRY_SERVICE_NAME: "RegistryService"
};

export const domains = {
    REGISTRY: 40,
    SERVICE: 60,
    INSTANCE: 70,
    STAKE: 80,
    PRODUCT: 110,
    DISTRIBUTION: 120,
    ORACLE: 130,
    POOL: 140,
    APPLICATION: 210,
    POLICY: 211,
    CLAIM: 212,
    BUNDLE: 220,
    PRICE: 230
};

export type ReleaseConfig = {
    addresses: AddressLike[],
    names: string[],
    serviceRoles: BigNumberish[][],
    serviceRoleNames: string[][],
    functionRoles: BigNumberish[][],
    functionRoleNames: string[][],
    selectors: BytesLike[][][] 
};

export type Release = {
    version: BigNumberish,
    salt: BytesLike,
    accessManager: AddressLike
};

// TODO implement release addresses computation
export async function computeReleaseAddresses(/*owner: Signer, registry: RegistryAddresses, libraries: LibraryAddresses, salt: BytesLike*/): Promise<ReleaseAddresses> {

    const releaseAddresses: ReleaseAddresses = {
        registryServiceAddress: "0x0000000000000000000000000000000000000001",
        registryServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        stakingServiceAddress: "0x0000000000000000000000000000000000000001",
        stakingServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        instanceServiceAddress: "0x0000000000000000000000000000000000000001",
        instanceServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        componentServiceAddress: "0x0000000000000000000000000000000000000001",
        componentServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        oracleServiceAddress: "0x0000000000000000000000000000000000000001",
        oracleServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        distributionServiceAddress: "0x0000000000000000000000000000000000000001",
        distributionServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        poolServiceAddress: "0x0000000000000000000000000000000000000001",
        poolServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        productServiceAddress: "0x0000000000000000000000000000000000000001",
        productServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        applicationServiceAddress: "0x0000000000000000000000000000000000000001",
        applicationServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        policyServiceAddress: "0x0000000000000000000000000000000000000001",
        policyServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        claimServiceAddress: "0x0000000000000000000000000000000000000001",
        claimServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        bundleServiceAddress: "0x0000000000000000000000000000000000000001",
        bundleServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        pricingServiceAddress: "0x0000000000000000000000000000000000000001",
        pricingServiceManagerAddress: "0x0000000000000000000000000000000000000001",
    };

    logReleaseAddresses(releaseAddresses);

    return releaseAddresses;
}


export async function createRelease(owner: Signer, registry: RegistryAddresses, salt: BytesLike): Promise<Release>
{
    const releaseRegistry = registry.releaseRegistry.connect(owner);
    
    await executeTx(
        async () => await releaseRegistry.createNextRelease(getTxOpts()),
        "releaseRegistry.createNextRelease",
        [releaseRegistry.interface]
    );


    const rcpt = await executeTx(
        async () =>  releaseRegistry.prepareNextRelease(
            registry.serviceAuthorizationV3,
            salt,
            getTxOpts()
        ),
        "releaseRegistry.prepareNextRelease",
        [releaseRegistry.interface]);

    let logCreationInfo = getFieldFromTxRcptLogs(rcpt!, registry.releaseRegistry.interface, "LogReleaseCreation", "version");
    const releaseVersion = (logCreationInfo as BigNumberish);
    logCreationInfo = getFieldFromTxRcptLogs(rcpt!, registry.releaseRegistry.interface, "LogReleaseCreation", "salt");
    const releaseSalt = (logCreationInfo as BytesLike);
    logCreationInfo = getFieldFromTxRcptLogs(rcpt!, registry.releaseRegistry.interface, "LogReleaseCreation", "accessManager");
    const releaseAccessManager = (logCreationInfo as AddressLike);

    const release: Release = {
        version: releaseVersion,
        salt: releaseSalt,
        accessManager: releaseAccessManager,
    };
    
    return release;
}