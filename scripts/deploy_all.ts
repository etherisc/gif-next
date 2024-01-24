import { AddressLike, resolveAddress } from "ethers";
import { ethers } from "hardhat";
import { ChainNft__factory, IRegistry__factory } from "../typechain-types";
import { getNamedAccounts, printBalance, validateNftOwnerhip } from "./libs/accounts";
import { LibraryAddresses, deployLibraries } from "./libs/libraries";
import { RegistryAddresses, deployAndInitializeRegistry } from "./libs/registry";
import { logger } from "./logger";
import { InstanceAddresses, cloneInstance, deployAndRegisterMasterInstance } from "./libs/instance";
import { ServiceAddresses, authorizeServices, deployAndRegisterServices } from "./libs/services";


async function main() {
    const { protocolOwner, masterInstanceOwner, instanceOwner } = await getNamedAccounts();

    // deploy protocol contracts
    const libraries = await deployLibraries(protocolOwner);
    const registry = await deployAndInitializeRegistry(protocolOwner, libraries);
    const services = await deployAndRegisterServices(protocolOwner, registry, libraries);
    await authorizeServices(protocolOwner, libraries, registry, services);
    
    // // deploy instance contracts
    const masterInstance = await deployAndRegisterMasterInstance(masterInstanceOwner, libraries, registry, services);
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
    if (await registryC.getChainNft() !== registry.chainNftAddress) {
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
    await validateNftOwnerhip(registry.chainNftAddress, masterInstance.instanceNftId, masterInstanceOwner);
    
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
    addresses += `nftIdLibAddress: ${libraries.nftIdLibAddress}\n`;
    addresses += `mathLibAddress: ${libraries.mathLibAddress}\n`;
    addresses += `uFixedLibAddress: ${libraries.uFixedLibAddress}\n`;
    addresses += `objectTypeLibAddress: ${libraries.objectTypeLibAddress}\n`;
    addresses += `blockNumberLibAddress: ${libraries.blockNumberLibAddress}\n`;
    addresses += `versionLibAddress: ${libraries.versionLibAddress}\n`;
    addresses += `versionPartLibAddress: ${libraries.versionPartLibAddress}\n`;
    addresses += `timestampLibAddress: ${libraries.timestampLibAddress}\n`;
    addresses += `libNftIdSetAddress: ${libraries.libNftIdSetAddress}\n`;
    addresses += `key32LibAddress: ${libraries.key32LibAddress}\n`;
    addresses += `feeLibAddress: ${libraries.feeLibAddress}\n`;
    addresses += `stateIdLibAddress: ${libraries.stateIdLibAddress}\n`;
    addresses += `roleIdLibAddress: ${libraries.roleIdLibAddress}\n`;
    addresses += `riskIdLibAddress: ${libraries.riskIdLibAddress}\n`;
    addresses += `contractDeployerLibAddress: ${libraries.contractDeployerLibAddress}\n`;
    addresses += `--------\n`;
    addresses += `registryAddress: ${registry.registryAddress}\n`;
    addresses += `registryServiceAddress: ${registry.registryServiceAddress}\n`;
    addresses += `registryServiceManagerAddress: ${registry.registryServiceManagerAddress}\n`;
    addresses += `registryNftId: ${registry.registryNftId}\n`;
    addresses += `chainNftAddress: ${registry.chainNftAddress}\n`;
    addresses += `tokenRegistryAddress: ${registry.tokenRegistryAddress}\n`;
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
    addresses += `--------\n`;

    // addresses += `componentOwnerServiceAddress: ${services.componentOwnerServiceAddress}\n`;
    // addresses += `componentOwnerServiceNftId: ${services.componentOwnerServiceNftId}\n`;
    // addresses += `productServiceAddress: ${services.productServiceAddress}\n`;
    // addresses += `productServiceNftId: ${services.productServiceNftId}\n`;
    // addresses += `poolServiceAddress: ${services.poolServiceAddress}\n`;
    // addresses += `poolServiceNftId: ${services.poolServiceNftId}\n`;
    // addresses += `distributionServiceAddress: ${services.distributionServiceAddress}\n`;
    // addresses += `distributionServiceNftId: ${services.distributionServiceNftId}\n`;
    // addresses += `--------\n`;
    addresses += `masterInstanceAddress: ${masterInstance.instanceAddress}\n`;
    addresses += `masterInstanceNftId: ${masterInstance.instanceNftId}\n`;
    addresses += `--------\n`;
    addresses += `clonedInstanceAddress: ${clonedInstance.instanceAddress}\n`;
    addresses += `clonedInstanceNftId: ${clonedInstance.instanceNftId}\n`;
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



main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});


