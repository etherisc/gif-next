
import { AddressLike, BytesLike, Signer, resolveAddress, AbiCoder, keccak256, hexlify, Interface, solidityPacked, solidityPackedKeccak256, getCreate2Address, defaultAbiCoder, id, concat, Typed, BigNumberish } from "ethers";
import { logger } from "../logger";
import { UpgradableProxyWithAdmin__factory, IVersionable__factory, ReleaseManager__factory, ReleaseManager, PoolService__factory, PoolServiceManager__factory, BundleService__factory, DistributionService__factory, InstanceService__factory, RegistryService__factory } from "../../typechain-types";
import { RegistryAddresses } from "./registry";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";


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
    REGISTRY_SERVICE_ROLE: 2700,
    STAKING_SERVICE_ROLE: 2900,
    CAN_CREATE_GIF_TARGET_ROLE: 1700,
    PRICING_SERVICE_ROLE: 2800
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
    serviceRoles: BigNumberish[][],
    functionRoles: BigNumberish[][],
    selectors: BytesLike[][][] 
}; 

export async function getReleaseConfig(owner: Signer, registry: RegistryAddresses, libraries: LibraryAddresses, salt: BytesLike): Promise<ReleaseConfig>
{
    const releaseAddresses = await computeReleaseAddresses(owner, registry, libraries, salt);

    // prepare config
    const config: ReleaseConfig =
    {
        addresses: [
            releaseAddresses.stakingServiceAddress,
            releaseAddresses.policyServiceAddress,
            releaseAddresses.applicationServiceAddress,
            releaseAddresses.claimServiceAddress,
            releaseAddresses.productServiceAddress,
            releaseAddresses.poolServiceAddress,
            releaseAddresses.bundleServiceAddress,
            releaseAddresses.pricingServiceAddress,
            releaseAddresses.distributionServiceAddress,
            releaseAddresses.instanceServiceAddress,
            releaseAddresses.registryServiceAddress
        ],
        serviceRoles: [
            [
                roles.STAKING_SERVICE_ROLE
            ],
            [
                roles.POLICY_SERVICE_ROLE
            ],
            [
                roles.APPLICATION_SERVICE_ROLE
            ],
            [
                roles.CLAIM_SERVICE_ROLE
            ],
            [
                roles.PRODUCT_SERVICE_ROLE,
                roles.CAN_CREATE_GIF_TARGET_ROLE
            ],
            [
                roles.POOL_SERVICE_ROLE,
                roles.CAN_CREATE_GIF_TARGET_ROLE
            ],
            [
                roles.BUNDLE_SERVICE_ROLE,
                roles.CAN_CREATE_GIF_TARGET_ROLE
            ],
            [
                roles.PRICING_SERVICE_ROLE
            ],
            [
                roles.DISTRIBUTION_SERVICE_ROLE,
                roles.CAN_CREATE_GIF_TARGET_ROLE
            ],
            [
                roles.INSTANCE_SERVICE_ROLE,
            ],
            [
                roles.REGISTRY_SERVICE_ROLE
            ]
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