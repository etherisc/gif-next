import { AddressLike, resolveAddress } from "ethers";
import { ethers } from "hardhat";
import { ChainNft__factory, IRegistry__factory } from "../typechain-types";
import { getNamedAccounts, printBalance, validateNftOwnerhip } from "./libs/accounts";
import { LibraryAddresses, deployLibraries } from "./libs/libraries";
import { RegistryAddresses, deployAndInitializeRegistry } from "./libs/registry";
import { logger } from "./logger";
import { InstanceAddresses, MASTER_INSTANCE_OWNER, cloneInstance, deployAndRegisterMasterInstance } from "./libs/instance";
import { ServiceAddresses, authorizeServices, deployAndRegisterServices } from "./libs/services";


async function main() {
    logger.info("deploying new GIF instance...");
    const { protocolOwner, masterInstanceOwner, instanceOwner } = await getNamedAccounts();

    // deploy protocol contracts
    const libraries = await deployLibraries(protocolOwner);
    const registry = await deployAndInitializeRegistry(protocolOwner, libraries);
    const services = await deployAndRegisterServices(protocolOwner, registry, libraries);
    
    // // deploy instance contracts
    const masterInstance = await deployAndRegisterMasterInstance(protocolOwner, libraries, registry, services);
    const clonedInstance = await cloneInstance(masterInstance, libraries, registry, services, instanceOwner);

    // await grantRole(instanceOwner, libraries, instance, Role.POOL_OWNER_ROLE, poolOwner);
    // await grantRole(instanceOwner, libraries, instance, Role.DISTRIBUTION_OWNER_ROLE, distributionOwner);
    // await grantRole(instanceOwner, libraries, instance, Role.PRODUCT_OWNER_ROLE, productOwner);

    
    // // deploy pool & product contracts
    // const { poolAddress, poolNftId, tokenAddress } = await deployPool(poolOwner, libraries, registry, instance);
    // const { distributionAddress, distributionNftId } = await deployDistribution(distributionOwner, libraries, registry, instance, tokenAddress);
    // const { productAddress, productNftId } = await deployProduct(productOwner, libraries, registry, instance, tokenAddress, poolAddress, distributionAddress);
    
    printAddresses(libraries, registry, services, masterInstance, clonedInstance);

    await verifyOwnership(
        protocolOwner, masterInstanceOwner,
        //, productOwner, poolOwner, distributionOwner,
        libraries, registry, //services,
        masterInstance, 
        // tokenAddress, 
        // poolAddress, poolNftId,
        // distributionAddress, distributionNftId,
        // productAddress, productNftId);
    );

    // print final balance
    await printBalance(
        ["protocolOwner", protocolOwner],
        ["masterInstanceOwner", masterInstanceOwner] , 
        // ["instanceServiceOwner", instanceServiceOwner],
        ["instanceOwner", instanceOwner],
        // ["productOwner", productOwner], 
        // ["distributionOwner", distributionOwner], 
        // ["poolOwner", poolOwner]
        );
    logger.info("GIF instance deployed successfully");
}

/**
 * Verifies the smart contract deployment has correct ownerships. 
 * Check that NFT and registry are linked correctly.
 * Check that the instance, instance NFT, pool NFT and product NFTs are owned by their respective owners.
 */
async function verifyOwnership(
    protocolOwner: AddressLike, masterInstanceOwner: AddressLike,
    // productOwner: AddressLike, poolOwner: AddressLike, distributionOwner: AddressLike,
    libraries: LibraryAddresses, registry: RegistryAddresses, //services: ServiceAddresses,
    masterInstance: InstanceAddresses,
    // tokenAddress: AddressLike, 
    // poolAddress: AddressLike, poolNftId: string,
    // distributionAddress: AddressLike, distributionNftId: string,
    // productAddress: AddressLike, productNftId: string,
) {
    logger.debug("validating ownerships ...");
    const chainNft = ChainNft__factory.connect(await resolveAddress(registry.chainNftAddress), ethers.provider);
    if (await chainNft.getRegistryAddress() !== resolveAddress(registry.registryAddress)) {
        throw new Error("chainNft registry address mismatch");
    }
    const registryC = IRegistry__factory.connect(await resolveAddress(registry.registryAddress), ethers.provider);
    if (await registryC.getChainNftAddress() !== registry.chainNftAddress) {
        throw new Error("registry chainNft address mismatch");
    }

    // await validateOwnership(protocolOwner, services.componentOwnerServiceAddress);
    // await validateOwnership(protocolOwner, services.productServiceAddress);
    // await validateOwnership(protocolOwner, services.poolServiceAddress);

    // await validateNftOwnerhip(registry.chainNftAddress, registry.registryNftId, protocolOwner);
    // await validateNftOwnerhip(registry.chainNftAddress, services.componentOwnerServiceNftId, protocolOwner);
    // await validateNftOwnerhip(registry.chainNftAddress, services.distributionServiceNftId, protocolOwner);
    // await validateNftOwnerhip(registry.chainNftAddress, services.productServiceNftId, protocolOwner);
    // await validateNftOwnerhip(registry.chainNftAddress, services.poolServiceNftId, protocolOwner);
    
    if (masterInstance.instanceNftId === undefined) {
        throw new Error("instance masterInstanceNftId undefined");
    }
    const masterInstanceNftIdFromReg = await registry.registry["getNftId(address)"](masterInstance.instanceAddress);
    if (BigInt(masterInstance.instanceNftId) !== masterInstanceNftIdFromReg) {
        throw new Error(`instance masterInstanceNftId (${masterInstance.instanceNftId}) mismatch: ${masterInstanceNftIdFromReg}`);
    }
    await validateNftOwnerhip(registry.chainNftAddress, masterInstance.instanceNftId, MASTER_INSTANCE_OWNER);
    
    // await validateNftOwnerhip(registry.chainNftAddress, instance.instanceNftId, instanceOwner);
    
    // await validateNftOwnerhip(registry.chainNftAddress, poolNftId, poolOwner);
    // await validateNftOwnerhip(registry.chainNftAddress, distributionNftId, distributionOwner);
    // await validateNftOwnerhip(registry.chainNftAddress, productNftId, productOwner);
    logger.info("ownerships verified");
}

function printAddresses(
    libraries: LibraryAddresses, registry: RegistryAddresses, 
    services: ServiceAddresses,
    masterInstance: InstanceAddresses, clonedInstance: InstanceAddresses,
    // tokenAddress: AddressLike, 
    // poolAddress: AddressLike, poolNftId: string,
    // distributionAddress: AddressLike, distributionNftId: string,
    // productAddress: AddressLike, productNftId: string,
) {
    let addresses = "\nAddresses of deployed smart contracts:\n==========\n";
    addresses += `Library Addresses:\n----------\n`;
    for (const lib in libraries) {
        let libName = lib.toUpperCase();
        libName = libName.replace("ADDRESS", "_ADDRESS");
        // @ts-expect-error types are from static list
        addresses += `${libName}=${libraries[lib]}\n`;
    }

    addresses += `--------\n`;
    addresses += `REGISTRY_ADMIN_ADDRESS=${registry.registryAdminAddress}\n`;
    addresses += `RELEASE_MANAGER_ADDRESS=${registry.releaseManagerAddress}\n`;
    addresses += `REGISTRY_ADDRESS=${registry.registryAddress}\n`;
    addresses += `REGISTRY_NFT_ID=${registry.registryNftId}\n`;
    addresses += `CHAIN_NFT_ADDRESS=${registry.chainNftAddress}\n`;
    addresses += `TOKEN_REGISTRY_ADDRESS=${registry.tokenRegistryAddress}\n`;
    addresses += `STAKING_NFT_ID=${registry.stakingNftId}\n`;
    addresses += `STAKING_ADDRESS=${registry.stakingAddress}\n`;
    addresses += `DIP_ADDRESS=${registry.dipAddress}\n`;
    addresses += `--------\n`;
    addresses += `REGISTRY_SERVICE_MANAGER_ADDRESS=${services.registryServiceManagerAddress}\n`;
    addresses += `REGISTRY_SERVICE_ADDRESS=${services.registryServiceAddress}\n`;
    addresses += `REGISTRY_SERVICE_NFT_ID=${services.registryServiceNftId}\n`;

    addresses += `STAKING_SERVICE_MANAGER_ADDRESS=${services.stakingServiceManagerAddress}\n`;
    addresses += `STAKING_SERVICE_ADDRESS=${services.stakingServiceAddress}\n`;
    addresses += `STAKING_SERVICE_NFT_ID=${services.stakingServiceNftId}\n`;

    addresses += `INSTANCE_SERVICE_MANAGER_ADDRESS=${services.instanceServiceManagerAddress}\n`;
    addresses += `INSTANCE_SERVICE_ADDRESS=${services.instanceServiceAddress}\n`;
    addresses += `INSTANCE_SERVICE_NFT_ID=${services.instanceServiceNftId}\n`;

    addresses += `COMPONENT_SERVICE_MANAGER_ADDRESS=${services.componentServiceManagerAddress}\n`;
    addresses += `COMPONENT_SERVICE_ADDRESS=${services.componentServiceAddress}\n`;
    addresses += `COMPONENT_SERVICE_NFT_ID=${services.componentServiceNftId}\n`;

    addresses += `DISTRIBUTION_SERVICE_MANAGER_ADDRESS=${services.distributionServiceManagerAddress}\n`;
    addresses += `DISTRIBUTION_SERVICE_ADDRESS=${services.distributionServiceAddress}\n`;
    addresses += `DISTRIBUTION_SERVICE_NFT_ID=${services.distributionServiceNftId}\n`;

    addresses += `POOL_SERVICE_MANAGER_ADDRESS=${services.poolServiceManagerAddress}\n`;
    addresses += `POOL_SERVICE_ADDRESS=${services.poolServiceAddress}\n`;
    addresses += `POOL_SERVICE_NFT_ID=${services.poolServiceNftId}\n`;

    addresses += `PRODUCT_SERVICE_MANAGER_ADDRESS=${services.productServiceManagerAddress}\n`;
    addresses += `PRODUCT_SERVICE_ADDRESS=${services.productServiceAddress}\n`;
    addresses += `PRODUCT_SERVICE_NFT_ID=${services.productServiceNftId}\n`;

    addresses += `APPLICATION_SERVICE_MANAGER_ADDRESS=${services.applicationServiceManagerAddress}\n`;
    addresses += `APPLICATION_SERVICE_ADDRESS=${services.applicationServiceAddress}\n`;
    addresses += `APPLICATION_SERVICE_NFT_ID=${services.applicationServiceNftId}\n`;

    addresses += `POLICY_SERVICE_MANAGER_ADDRESS=${services.policyServiceManagerAddress}\n`;
    addresses += `POLICY_SERVICE_ADDRESS=${services.policyServiceAddress}\n`;
    addresses += `POLICY_SERVICE_NFT_ID=${services.policyServiceNftId}\n`;

    addresses += `CLAIM_SERVICE_MANAGER_ADDRESS=${services.claimServiceManagerAddress}\n`;
    addresses += `CLAIM_SERVICE_ADDRESS=${services.claimServiceAddress}\n`;
    addresses += `CLAIM_SERVICE_NFT_ID=${services.claimServiceNftId}\n`;

    addresses += `BUNDLE_SERVICE_MANAGER_ADDRESS=${services.bundleServiceManagerAddress}\n`;
    addresses += `BUNDLE_SERVICE_ADDRESS=${services.bundleServiceAddress}\n`;
    addresses += `BUNDLE_SERVICE_NFT_ID=${services.bundleServiceNftId}\n`;
    addresses += `--------\n`;
    addresses += `MASTER_INSTANCE_ADDRESS=${masterInstance.instanceAddress}\n`;
    addresses += `MASTER_INSTANCE_NFT_ID=${masterInstance.instanceNftId}\n`;
    addresses += `MASTER_INSTANCE_ACCESS_MANAGER_ADDRESS=${masterInstance.accessManagerAddress}\n`;
    addresses += `MASTER_INSTANCE_ADMIN_ADDRESS=${masterInstance.instanceAdminAddress}\n`;
    addresses += `MASTER_BUNDLE_MANAGER_ADDRESS=${masterInstance.instanceBundleManagerAddress}\n`;
    addresses += `MASTER_INSTANCE_READER_ADDRESS=${masterInstance.instanceReaderAddress}\n`;
    addresses += `MASTER_INSTANCE_STORE_ADDRESS=${masterInstance.instanceStoreAddress}\n`;
    addresses += `--------\n`;
    addresses += `CLONED_INSTANCE_ADDRESS=${clonedInstance.instanceAddress}\n`;
    addresses += `CLONED_INSTANCE_NFT_ID=${clonedInstance.instanceNftId}\n`;
    addresses += `CLONED_INSTANCE_ACCESS_MANAGER_ADDRESS=${clonedInstance.accessManagerAddress}\n`;
    addresses += `CLONED_INSTANCE_ADMIN_ADDRESS=${clonedInstance.instanceAdminAddress}\n`;
    addresses += `CLONED_BUNDLE_MANAGER_ADDRESS=${clonedInstance.instanceBundleManagerAddress}\n`;
    addresses += `CLONED_INSTANCE_READER_ADDRESS=${clonedInstance.instanceReaderAddress}\n`;
    addresses += `--------\n`;
    // addresses += `tokenAddress: ${tokenAddress}\n`;
    // addresses += `poolAddress: ${poolAddress}\n`;
    // addresses += `poolNftId: ${poolNftId}\n`;
    // addresses += `distributionAddress: ${distributionAddress}\n`;
    // addresses += `distributionNftId: ${distributionNftId}\n`;
    // addresses += `productAddress: ${productAddress}\n`;
    // addresses += `productNftId: ${productNftId}\n`;    
    
    logger.info(addresses);
}

export type InstanceAddresses = {
    ozAccessManagerAddress: AddressLike,
    instanceAccessManagerAddress: AddressLike,
    instanceReaderAddress: AddressLike,
    instanceBundleManagerAddress: AddressLike,
    instanceAddress: AddressLike,
    instanceNftId: string,
}


main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});