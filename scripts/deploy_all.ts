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
    addresses += `amountLibAddress: ${libraries.amountLibAddress}\n`;
    addresses += `blockNumberLibAddress: ${libraries.blockNumberLibAddress}\n`;
    addresses += `contractDeployerLibAddress: ${libraries.contractDeployerLibAddress}\n`;
    addresses += `feeLibAddress: ${libraries.feeLibAddress}\n`;
    addresses += `key32LibAddress: ${libraries.key32LibAddress}\n`;
    addresses += `libNftIdSetAddress: ${libraries.libNftIdSetAddress}\n`;
    addresses += `mathLibAddress: ${libraries.mathLibAddress}\n`;
    addresses += `nftIdLibAddress: ${libraries.nftIdLibAddress}\n`;
    addresses += `objectTypeLibAddress: ${libraries.objectTypeLibAddress}\n`;
    addresses += `referralLibAddress: ${libraries.referralLibAddress}\n`;
    addresses += `riskIdLibAddress: ${libraries.riskIdLibAddress}\n`;
    addresses += `roleIdLibAddress: ${libraries.roleIdLibAddress}\n`;
    addresses += `stateIdLibAddress: ${libraries.stateIdLibAddress}\n`;
    addresses += `timestampLibAddress: ${libraries.timestampLibAddress}\n`;
    addresses += `uFixedLibAddress: ${libraries.uFixedLibAddress}\n`;
    addresses += `versionLibAddress: ${libraries.versionLibAddress}\n`;
    addresses += `versionPartLibAddress: ${libraries.versionPartLibAddress}\n`;
    addresses += `instanceAuthorizationsLibAddress: ${libraries.instanceAuthorizationsLibAddress}\n`;
    addresses += `--------\n`;
    addresses += `registryAccessManagerAddress: ${registry.registryAccessManagerAddress}\n`;
    addresses += `releaseManagerAddress: ${registry.releaseManagerAddress}\n`;
    addresses += `registryAddress: ${registry.registryAddress}\n`;
    addresses += `registryNftId: ${registry.registryNftId}\n`;
    addresses += `chainNftAddress: ${registry.chainNftAddress}\n`;
    addresses += `tokenRegistryAddress: ${registry.tokenRegistryAddress}\n`;
    addresses += `registryServiceManagerAddress: ${registry.registryServiceManagerAddress}\n`;
    addresses += `registryServiceAddress: ${registry.registryServiceAddress}\n`;
    addresses += `registryServiceNftId: ${registry.registryServiceNftId}\n`;
    addresses += `--------\n`;
    addresses += `instanceServiceManagerAddress: ${services.instanceServiceManagerAddress}\n`;
    addresses += `instanceServiceAddress: ${services.instanceServiceAddress}\n`;
    addresses += `instanceServiceNftId: ${services.instanceServiceNftId}\n`;

    addresses += `distributionServiceManagerAddress: ${services.distributionServiceManagerAddress}\n`;
    addresses += `distributionServiceAddress: ${services.distributionServiceAddress}\n`;
    addresses += `distributionServiceNftId: ${services.distributionServiceNftId}\n`;

    addresses += `poolServiceManagerAddress: ${services.poolServiceManagerAddress}\n`;
    addresses += `poolServiceAddress: ${services.poolServiceAddress}\n`;
    addresses += `poolServiceNftId: ${services.poolServiceNftId}\n`;

    addresses += `productServiceManagerAddress: ${services.productServiceManagerAddress}\n`;
    addresses += `productServiceAddress: ${services.productServiceAddress}\n`;
    addresses += `productServiceNftId: ${services.productServiceNftId}\n`;

    addresses += `applicationServiceManagerAddress: ${services.applicationServiceManagerAddress}\n`;
    addresses += `applicationServiceAddress: ${services.applicationServiceAddress}\n`;
    addresses += `applicationServiceNftId: ${services.applicationServiceNftId}\n`;

    addresses += `policyServiceManagerAddress: ${services.policyServiceManagerAddress}\n`;
    addresses += `policyServiceAddress: ${services.policyServiceAddress}\n`;
    addresses += `policyServiceNftId: ${services.policyServiceNftId}\n`;

    addresses += `claimServiceManagerAddress: ${services.claimServiceManagerAddress}\n`;
    addresses += `claimServiceAddress: ${services.claimServiceAddress}\n`;
    addresses += `claimServiceNftId: ${services.claimServiceNftId}\n`;

    addresses += `bundleServiceManagerAddress: ${services.bundleServiceManagerAddress}\n`;
    addresses += `bundleServiceAddress: ${services.bundleServiceAddress}\n`;
    addresses += `bundleServiceNftId: ${services.bundleServiceNftId}\n`;
    addresses += `--------\n`;
    addresses += `masterInstanceAddress: ${masterInstance.instanceAddress}\n`;
    addresses += `masterInstanceNftId: ${masterInstance.instanceNftId}\n`;
    addresses += `masterOzAccessManagerAddress: ${masterInstance.ozAccessManagerAddress}\n`;
    addresses += `masterInstanceAccessManagerAddress: ${masterInstance.instanceAccessManagerAddress}\n`;
    addresses += `masterBundleManagerAddress: ${masterInstance.instanceBundleManagerAddress}\n`;
    addresses += `masterInstanceReaderAddress: ${masterInstance.instanceReaderAddress}\n`;
    addresses += `masterInstanceStoreAddress: ${masterInstance.instanceStoreAddress}\n`;
    addresses += `--------\n`;
    addresses += `clonedInstanceAddress: ${clonedInstance.instanceAddress}\n`;
    addresses += `clonedInstanceNftId: ${clonedInstance.instanceNftId}\n`;
    addresses += `clonedOzAccessManagerAddress: ${clonedInstance.ozAccessManagerAddress}\n`;
    addresses += `clonedInstanceAccessManagerAddress: ${clonedInstance.instanceAccessManagerAddress}\n`;
    addresses += `clonedBundleManagerAddress: ${clonedInstance.instanceBundleManagerAddress}\n`;
    addresses += `clonedInstanceReaderAddress: ${clonedInstance.instanceReaderAddress}\n`;
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


