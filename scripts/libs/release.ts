
import { AddressLike, BytesLike, Signer, resolveAddress, AbiCoder, keccak256, hexlify, Interface, solidityPacked, solidityPackedKeccak256, getCreate2Address, defaultAbiCoder, id, concat, Typed, BigNumberish } from "ethers";
import { logger } from "../logger";
import { PoolService__factory, BundleService__factory, DistributionService__factory, InstanceService__factory, RegistryService__factory, ReleaseManager__factory } from "../../typechain-types";
import { RegistryAddresses } from "./registry";
import { LibraryAddresses } from "./libraries";
import { executeTx, getFieldFromTxRcptLogs } from "./transaction";


export type ReleaseAddresses = {
    registryServiceAddress: AddressLike,
    registryServiceManagerAddress: AddressLike,
    instanceServiceAddress: AddressLike,
    instanceServiceManagerAddress: AddressLike,
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
    stakingServiceAddress: AddressLike,
    stakingServiceManagerAddress: AddressLike
};

function logReleaseAddresses(release: ReleaseAddresses): void {
    logger.info(`registryServiceAddress: ${release.registryServiceAddress}`);
    logger.info(`registryServiceManagerAddress: ${release.registryServiceManagerAddress}`);
    logger.info(`instanceServiceAddress: ${release.instanceServiceAddress}`);
    logger.info(`instanceServiceManagerAddress: ${release.instanceServiceManagerAddress}`);
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
    logger.info(`stakingServiceAddress: ${release.stakingServiceAddress}`);
    logger.info(`stakingServiceManagerAddress: ${release.stakingServiceManagerAddress}`);
}

export const roles = {
    INSTANCE_OWNER_ROLE: 1900,
    INSTANCE_SERVICE_ROLE: 2000,
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
    config: ReleaseConfig
};

// TODO implement release addresses computation
export async function computeReleaseAddresses(owner: Signer, registry: RegistryAddresses, libraries: LibraryAddresses, salt: BytesLike): Promise<ReleaseAddresses> {

    const releaseAddresses: ReleaseAddresses = {
        registryServiceAddress: "0x0000000000000000000000000000000000000001",
        registryServiceManagerAddress: "0x0000000000000000000000000000000000000001",
        instanceServiceAddress: "0x0000000000000000000000000000000000000001",
        instanceServiceManagerAddress: "0x0000000000000000000000000000000000000001",
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
        stakingServiceAddress: "0x0000000000000000000000000000000000000001",
        stakingServiceManagerAddress: "0x0000000000000000000000000000000000000001"
    };

    logReleaseAddresses(releaseAddresses);

    return releaseAddresses;
}


export async function getReleaseConfig(owner: Signer, registry: RegistryAddresses, libraries: LibraryAddresses, salt: BytesLike): Promise<ReleaseConfig>
{
    const serviceAddresses = await computeReleaseAddresses(owner, registry, libraries, salt);

    // prepare config
    const config: ReleaseConfig =
    {
        addresses: [
            serviceAddresses.stakingServiceAddress,
            serviceAddresses.policyServiceAddress,
            serviceAddresses.applicationServiceAddress,
            serviceAddresses.claimServiceAddress,
            serviceAddresses.productServiceAddress,
            serviceAddresses.poolServiceAddress,
            serviceAddresses.bundleServiceAddress,
            serviceAddresses.pricingServiceAddress,
            serviceAddresses.distributionServiceAddress,
            serviceAddresses.instanceServiceAddress,
            serviceAddresses.registryServiceAddress
        ],
        names: [
            serviceNames.STAKING_SERVICE_NAME,
            serviceNames.POLICY_SERVICE_NAME,
            serviceNames.APPLICATION_SERVICE_NAME,
            serviceNames.CLAIM_SERVICE_NAME,
            serviceNames.PRODUCT_SERVICE_NAME,
            serviceNames.POOL_SERVICE_NAME,
            serviceNames.BUNDLE_SERVICE_NAME,
            serviceNames.PRICING_SERVICE_NAME,
            serviceNames.DISTRIBUTION_SERVICE_NAME,
            serviceNames.INSTANCE_SERVICE_NAME,
            serviceNames.REGISTRY_SERVICE_NAME
        ],
        serviceRoles: [
            [roles.STAKING_SERVICE_ROLE],
            [roles.POLICY_SERVICE_ROLE],
            [roles.APPLICATION_SERVICE_ROLE],
            [roles.CLAIM_SERVICE_ROLE],
            [roles.PRODUCT_SERVICE_ROLE, roles.CAN_CREATE_GIF_TARGET_ROLE],
            [roles.POOL_SERVICE_ROLE, roles.CAN_CREATE_GIF_TARGET_ROLE],
            [roles.BUNDLE_SERVICE_ROLE, roles.CAN_CREATE_GIF_TARGET_ROLE],
            [roles.PRICING_SERVICE_ROLE],
            [roles.DISTRIBUTION_SERVICE_ROLE, roles.CAN_CREATE_GIF_TARGET_ROLE],
            [roles.INSTANCE_SERVICE_ROLE],
            [roles.REGISTRY_SERVICE_ROLE]
        ],
        serviceRoleNames: [
            [roleNames.STAKING_SERVICE_ROLE_NAME],
            [roleNames.POLICY_SERVICE_ROLE_NAME],
            [roleNames.APPLICATION_SERVICE_ROLE_NAME],
            [roleNames.CLAIM_SERVICE_ROLE_NAME],
            [roleNames.PRODUCT_SERVICE_ROLE_NAME, roleNames.CAN_CREATE_GIF_TARGET_ROLE_NAME],
            [roleNames.POOL_SERVICE_ROLE_NAME, roleNames.CAN_CREATE_GIF_TARGET_ROLE_NAME],
            [roleNames.BUNDLE_SERVICE_ROLE_NAME, roleNames.CAN_CREATE_GIF_TARGET_ROLE_NAME],
            [roleNames.PRICING_SERVICE_ROLE_NAME],
            [roleNames.DISTRIBUTION_SERVICE_ROLE_NAME, roleNames.CAN_CREATE_GIF_TARGET_ROLE_NAME],
            [roleNames.INSTANCE_SERVICE_ROLE_NAME],
            [roleNames.REGISTRY_SERVICE_ROLE_NAME]
        ],
        functionRoles: [
            [],  // staking
            [],  // policy
            [],  // application
            [],  // claim
            [],  // product
            [roles.POLICY_SERVICE_ROLE, roles.CLAIM_SERVICE_ROLE], // pool
            [roles.POLICY_SERVICE_ROLE, roles.POOL_SERVICE_ROLE],  // bundle
            [], // pricing
            [roles.POLICY_SERVICE_ROLE], // distribution
            [roles.CAN_CREATE_GIF_TARGET_ROLE], // instance
            [ // registry
                //roles.STAKING_SERVICE_ROLE,
                roles.APPLICATION_SERVICE_ROLE,
                roles.PRODUCT_SERVICE_ROLE,
                roles.POOL_SERVICE_ROLE,
                roles.BUNDLE_SERVICE_ROLE,
                roles.DISTRIBUTION_SERVICE_ROLE,
                roles.INSTANCE_SERVICE_ROLE
            ] 
        ],
        functionRoleNames: [
            [], // staking
            [], // policy
            [], // application
            [], // claim
            [], // product
            [roleNames.POLICY_SERVICE_ROLE_NAME, roleNames.CLAIM_SERVICE_ROLE_NAME], // pool
            [roleNames.POLICY_SERVICE_ROLE_NAME, roleNames.POOL_SERVICE_ROLE_NAME], // bundle
            [], // pricing
            [roleNames.POLICY_SERVICE_ROLE_NAME], // distribution
            [roleNames.CAN_CREATE_GIF_TARGET_ROLE_NAME], // instance
            [ // registry
                //roleNames.STAKING_SERVICE_ROLE_NAME,
                roleNames.APPLICATION_SERVICE_ROLE_NAME,
                roleNames.PRODUCT_SERVICE_ROLE_NAME,
                roleNames.POOL_SERVICE_ROLE_NAME,
                roleNames.BUNDLE_SERVICE_ROLE_NAME,
                roleNames.DISTRIBUTION_SERVICE_ROLE_NAME,
                roleNames.INSTANCE_SERVICE_ROLE_NAME
            ]
        ],
        selectors: [
            [], // staking
            [], // policy
            [], // application
            [], // claim
            [], // product
            [ 
                [
                    PoolService__factory.createInterface().getFunction("lockCollateral").selector,
                    PoolService__factory.createInterface().getFunction("releaseCollateral").selector,
                    PoolService__factory.createInterface().getFunction("processSale").selector
                ],
                [PoolService__factory.createInterface().getFunction("reduceCollateral").selector]
            ],
            [
                [BundleService__factory.createInterface().getFunction("increaseBalance").selector],
                [
                    BundleService__factory.createInterface().getFunction("create").selector,
                    BundleService__factory.createInterface().getFunction("lockCollateral").selector,
                    BundleService__factory.createInterface().getFunction("close").selector,
                    BundleService__factory.createInterface().getFunction("releaseCollateral").selector,
                    BundleService__factory.createInterface().getFunction("unlinkPolicy").selector
                ]
            ],
            [], // pricing
            [
                [DistributionService__factory.createInterface().getFunction("processSale").selector]
            ],
            [
                [InstanceService__factory.createInterface().getFunction("createGifTarget").selector]
            ],
            [
                [RegistryService__factory.createInterface().getFunction("registerPolicy").selector],
                [RegistryService__factory.createInterface().getFunction("registerProduct").selector],
                [RegistryService__factory.createInterface().getFunction("registerPool").selector],
                [RegistryService__factory.createInterface().getFunction("registerBundle").selector],
                [RegistryService__factory.createInterface().getFunction("registerDistribution").selector],
                [RegistryService__factory.createInterface().getFunction("registerInstance").selector]
            ]
        ]
    };

    return config;
}

export async function createRelease(owner: Signer, registry: RegistryAddresses, config: ReleaseConfig, salt: BytesLike): Promise<Release>
{
    const releaseManager = await registry.releaseManager.connect(owner);
    await releaseManager.createNextRelease();

    const rcpt = await executeTx(async () =>  releaseManager.prepareNextRelease(
        config.addresses,
        config.names,
        config.serviceRoles,
        config.serviceRoleNames,
        config.functionRoles,
        config.functionRoleNames,
        config.selectors,
        salt
    ));

    let logCreationInfo = getFieldFromTxRcptLogs(rcpt!, registry.releaseManager.interface, "LogReleaseCreation", "version");
    const releaseVersion = (logCreationInfo as BigNumberish);
    logCreationInfo = getFieldFromTxRcptLogs(rcpt!, registry.releaseManager.interface, "LogReleaseCreation", "salt");
    const releaseSalt = (logCreationInfo as BytesLike);
    logCreationInfo = getFieldFromTxRcptLogs(rcpt!, registry.releaseManager.interface, "LogReleaseCreation", "releaseAccessManager");
    const releaseAccessManager = (logCreationInfo as AddressLike);

    const release: Release = {
        version: releaseVersion,
        salt: releaseSalt,
        accessManager: releaseAccessManager,
        config: config
    };
    
    return release;
}