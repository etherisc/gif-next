import { AddressLike, Signer, resolveAddress } from "ethers";
import { ethers } from "hardhat";
import { IChainNft__factory, IRegistry__factory, Registerable, UFixedMathLib__factory } from "../typechain-types";
import { getNamedAccounts, printBalance, validateNftOwnerhip, validateOwnership } from "./libs/accounts";
import { POOL_COLLATERALIZATION_LEVEL, POOL_IS_VERIFYING } from "./libs/constants";
import { deployContract } from "./libs/deployment";
import { InstanceAddresses, Role, deployAndRegisterInstance, grantRole } from "./libs/instance";
import { LibraryAddresses, deployLibraries } from "./libs/libraries";
import { RegistryAddresses, deployAndInitializeRegistry, registerContract } from "./libs/registry";
import { ServiceAddresses, deployAndRegisterServices, registerPool, registerProduct } from "./libs/services";
import { logger } from "./logger";


async function main() {
    const { protocolOwner, instanceOwner, productOwner, poolOwner } = await getNamedAccounts();

    // deploy protocol contracts
    const libraries = await deployLibraries(protocolOwner);
    const registry = await deployAndInitializeRegistry(protocolOwner, libraries);
    const { tokenAddress, tokenNftId } = await deployToken(protocolOwner, registry);
    const services = await deployAndRegisterServices(protocolOwner, registry, libraries);
    
    // deploy instance contracts
    const instance = await deployAndRegisterInstance(instanceOwner, libraries, services, registry);

    await grantRole(instanceOwner, libraries, instance, Role.POOL_OWNER_ROLE, poolOwner);
    await grantRole(instanceOwner, libraries, instance, Role.PRODUCT_OWNER_ROLE, productOwner);

    
    // deploy pool & product contracts
    const { poolAddress, poolNftId } = await deployPool(poolOwner, libraries, registry, instance, services, tokenAddress);
    const { productAddress, productNftId } = await deployProduct(productOwner, libraries, registry, instance, services, tokenAddress, poolAddress);
    
    printAddresses(
        libraries, registry, services,
        instance, 
        tokenAddress, tokenNftId,
        poolAddress, poolNftId,
        productAddress, productNftId);

    await verifyOwnership(
        protocolOwner, instanceOwner, productOwner, poolOwner,
        libraries, registry, services,
        instance, 
        tokenAddress, poolAddress, poolNftId,
        productAddress, productNftId);

    // print final balance
    await printBalance(
        ["protocolOwner", protocolOwner] ,
        ["instanceOwner", instanceOwner] , 
        ["productOwner", productOwner], 
        ["poolOwner", poolOwner]);
}

/**
 * Verifies the smart contract deployment has correct ownerships. 
 * Check that NFT and registry are linked correctly.
 * Check that the instance, instance NFT, pool NFT and product NFTs are owned by their respective owners.
 */
async function verifyOwnership(
    protocolOwner: AddressLike, instanceOwner: AddressLike, productOwner: AddressLike, poolOwner: AddressLike,
    libraries: LibraryAddresses, registry: RegistryAddresses, services: ServiceAddresses,
    instance: InstanceAddresses,
    tokenAddress: AddressLike, poolAddress: AddressLike, poolNftId: string,
    productAddress: AddressLike, productNftId: string,
) {
    logger.debug("validating ownerships ...");
    const chainNft = IChainNft__factory.connect(await resolveAddress(registry.chainNftAddress), ethers.provider);
    if (await chainNft.getRegistryAddress() !== resolveAddress(registry.registryAddress)) {
        throw new Error("chainNft registry address mismatch");
    }
    const registryC = IRegistry__factory.connect(await resolveAddress(registry.registryAddress), ethers.provider);
    if (await registryC.getChainNft() !== registry.chainNftAddress) {
        throw new Error("registry chainNft address mismatch");
    }

    await validateOwnership(protocolOwner, services.componentOwnerServiceAddress);
    await validateOwnership(protocolOwner, services.productServiceAddress);
    await validateOwnership(protocolOwner, services.poolServiceAddress);

    await validateNftOwnerhip(registry.chainNftAddress, registry.registryNftId, protocolOwner);
    await validateNftOwnerhip(registry.chainNftAddress, services.componentOwnerServiceNftId, protocolOwner);
    await validateNftOwnerhip(registry.chainNftAddress, services.productServiceNftId, protocolOwner);
    await validateNftOwnerhip(registry.chainNftAddress, services.poolServiceNftId, protocolOwner);
    
    await validateOwnership(instanceOwner, instance.instanceAddress);
    await validateNftOwnerhip(registry.chainNftAddress, instance.instanceNftId, instanceOwner);
    
    await validateNftOwnerhip(registry.chainNftAddress, poolNftId, poolOwner);
    await validateNftOwnerhip(registry.chainNftAddress, productNftId, productOwner);
    logger.info("ownerships verified");
}

function printAddresses(
    libraries: LibraryAddresses, 
    registry: RegistryAddresses, 
    services: ServiceAddresses,
    instance: InstanceAddresses,
    tokenAddress: AddressLike, tokenNftId: string,
    poolAddress: AddressLike, poolNftId: string,
    productAddress: AddressLike, productNftId: string,
) {
    let addresses = "\nAddresses of deployed smart contracts:\n==========\n";
    addresses += `nftIdLibAddress: ${libraries.nftIdLibAddress}\n`;
    addresses += `uFixedMathLibAddress: ${libraries.uFixedMathLibAddress}\n`;
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
    addresses += `--------\n`;
    addresses += `registryAddress: ${registry.registryAddress}\n`;
    addresses += `registryNftId: ${registry.registryNftId}\n`;
    addresses += `chainNftAddress: ${registry.chainNftAddress}\n`;
    addresses += `tokenAddress: ${tokenAddress}\n`;
    addresses += `tokenNftId: ${tokenNftId}\n`;
    addresses += `--------\n`;
    addresses += `componentOwnerServiceAddress: ${services.componentOwnerServiceAddress}\n`;
    addresses += `componentOwnerServiceNftId: ${services.componentOwnerServiceNftId}\n`;
    addresses += `productServiceAddress: ${services.productServiceAddress}\n`;
    addresses += `productServiceNftId: ${services.productServiceNftId}\n`;
    addresses += `poolServiceAddress: ${services.poolServiceAddress}\n`;
    addresses += `poolServiceNftId: ${services.poolServiceNftId}\n`;
    addresses += `--------\n`;
    addresses += `instanceAddress: ${instance.instanceAddress}\n`;
    addresses += `instanceNftId: ${instance.instanceNftId}\n`;
    addresses += `--------\n`;
    addresses += `poolAddress: ${poolAddress}\n`;
    addresses += `poolNftId: ${poolNftId}\n`;
    addresses += `productAddress: ${productAddress}\n`;
    addresses += `productNftId: ${productNftId}\n`;    
    
    logger.info(addresses);
}

async function deployToken(owner: Signer, registry: RegistryAddresses): Promise<{
    tokenAddress: AddressLike,
    tokenNftId: string
    }> {
    const { address: tokenAddress } = await deployContract(
        "USDC",
        owner);

    const tokenNftId = await registerContract(tokenAddress, "USDC", registry, owner);

    return {
        tokenAddress,
        tokenNftId
    }
}

async function deployProduct(
    owner: Signer, libraries: LibraryAddresses, 
    registry: RegistryAddresses, 
    instance: InstanceAddresses, 
    services: ServiceAddresses, 
    tokenAddress: AddressLike, 
    poolAddress: AddressLike
): Promise<{
    productAddress: AddressLike, productNftId: string,
}> {
    const { address: productAddress, contract: productContractBase } = await deployContract(
        "TestProduct",
        owner,
        [
            registry.registryAddress,
            instance.instanceNftId,
            tokenAddress,
            poolAddress,
        ],
        { libraries: {
            FeeLib: libraries.feeLibAddress
        }},
        "contracts/test/TestProduct.sol:TestProduct");
    
    const productNftId = await registerProduct(productContractBase as Registerable, productAddress, "TestProduct", services, registry, owner)
    logger.info(`product registered - productNftId: ${productNftId}`);
    
    return {
        productAddress,
        productNftId,
    };
}

async function deployPool(owner: Signer, libraries: LibraryAddresses, registry: RegistryAddresses, instance: InstanceAddresses, services: ServiceAddresses, tokenAddress: AddressLike): Promise<{
    poolAddress: AddressLike,
    poolNftId: string,
}> {
    const uFixedMathLib = UFixedMathLib__factory.connect(libraries.uFixedMathLibAddress.toString(), owner);
    const collateralizationLevel = await uFixedMathLib["toUFixed(uint256)"](POOL_COLLATERALIZATION_LEVEL);

    const { address: poolAddress, contract: poolContractBase } = await deployContract(
        "TestPool",
        owner,
        [
            registry.registryAddress,
            instance.instanceNftId,
            tokenAddress,
            POOL_IS_VERIFYING,
            collateralizationLevel,
        ],
        { libraries: {
            FeeLib: libraries.feeLibAddress
        }},
        "contracts/test/TestPool.sol:TestPool");

    const poolNftId = await registerPool(poolContractBase as Registerable, poolAddress, "TestPool", services, registry, owner);
    logger.info(`pool registered - poolNftId: ${poolNftId}`);
    
    return {
        poolAddress,
        poolNftId,
    };
}


main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});


