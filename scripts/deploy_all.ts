import { AddressLike, Signer, resolveAddress } from "ethers";
import { ethers } from "hardhat";
import { IChainNft__factory, IRegistry__factory, Registerable, UFixedMathLib__factory } from "../typechain-types";
import { getNamedAccounts, printBalance, validateOwnership } from "./lib/accounts";
import { registerComponent } from "./lib/componentownerservice";
import { deployContract } from "./lib/deployment";
import { InstanceAddresses, Role, deployAndRegisterInstance, grantRole } from "./lib/instance";
import { LibraryAddresses, deployLibraries } from "./lib/libraries";
import { RegistryAddresses, deployAndInitializeRegistry } from "./lib/registry";
import { deployAndRegisterServices } from "./lib/services";
import { logger } from "./logger";
import { POOL_COLLATERALIZATION_LEVEL, POOL_IS_VERIFYING } from "./lib/constants";
import { executeTx, getFieldFromLogs } from "./lib/transaction";
import { IERC721ABI } from "./lib/erc721";


async function main() {
    const { protocolOwner, instanceOwner, productOwner, poolOwner } = await getNamedAccounts();

    // deploy protocol contracts
    const libraries = await deployLibraries(protocolOwner);
    const registry = await deployAndInitializeRegistry(protocolOwner, libraries);
    const services = await deployAndRegisterServices(protocolOwner, registry, libraries);
    
    // deploy instance contracts
    const instance = await deployAndRegisterInstance(instanceOwner, libraries, registry, services);

    await grantRole(instanceOwner, libraries, instance, Role.POOL_OWNER_ROLE, poolOwner);
    await grantRole(instanceOwner, libraries, instance, Role.PRODUCT_OWNER_ROLE, productOwner);

    
    // deploy pool & product contracts
    const { poolAddress, poolNftId, tokenAddress } = await deployPool(poolOwner, libraries, registry, instance);
    const { productAddress } = await deployProduct(productOwner, libraries, registry, instance, tokenAddress, poolAddress);
    
    // TODO: fix
    // printAddresses(
    //     registryAddress, chainNftAddress,
    //     componentOwnerServiceAddress, productServiceAddress, 
    //     instanceAddress,
    //     tokenAddress, poolAddress, productAddress);

    // TODO: fix
    // await verifyOwnership(
    //     instanceOwner, productOwner, poolOwner,
    //     registryAddress,
    //     instanceAddress, 
    //     instanceNftId, poolNftId, productNftId,
    //     chainNftAddress);

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
    instanceOwner: AddressLike, productOwner: AddressLike, poolOwner: AddressLike,
    registryAddress: AddressLike, 
    instanceAddress: AddressLike, 
    instanceNftId: string, poolNftId: string, productNftId: string,
    chainNftAddress: AddressLike
) {
    const chainNft = IChainNft__factory.connect(chainNftAddress.toString(), ethers.provider);
    if (await chainNft.getRegistryAddress() !== registryAddress) {
        throw new Error("chainNft registry address mismatch");
    }
    const registry = IRegistry__factory.connect(registryAddress.toString(), ethers.provider);
    if (await registry.getNftAddress() !== chainNftAddress) {
        throw new Error("registry chainNft address mismatch");
    }

    await validateOwnership(instanceOwner, instanceAddress);

    const instanceNftOwner = await chainNft.ownerOf(instanceNftId);
    if (instanceNftOwner !== await resolveAddress(instanceOwner)) {
        throw new Error("instance nft owner mismatch");
    }

    const poolNftOwner = await chainNft.ownerOf(poolNftId);
    if (poolNftOwner !== await resolveAddress(poolOwner)) {
        throw new Error("pool nft owner mismatch");
    }

    const productNftOwner = await chainNft.ownerOf(productNftId);
    if (productNftOwner !== await resolveAddress(productOwner)) {
        throw new Error("product nft owner mismatch");
    }
}

function printAddresses(
    registryAddress: AddressLike, chainNftAddress: AddressLike,
    componentOwnerServiceAddress: AddressLike, productServiceAddress: AddressLike,
    instanceAddress: AddressLike,
    tokenAddress: AddressLike, poolAddress: AddressLike, productAddress: AddressLike
) {
    let addresses = "\nAddresses of deployed smart contracts:\n==========\n";
    addresses += `registryAddress: ${registryAddress}\n`;
    addresses += `chainNftAddress: ${chainNftAddress}\n`;
    addresses += `--------\n`;
    addresses += `componentOwnerServiceAddress: ${componentOwnerServiceAddress}\n`;
    addresses += `productServiceAddress: ${productServiceAddress}\n`;
    addresses += `--------\n`;
    addresses += `instanceAddress: ${instanceAddress}\n`;
    addresses += `--------\n`;
    addresses += `tokenAddress: ${tokenAddress}\n`;
    addresses += `poolAddress: ${poolAddress}\n`;
    addresses += `productAddress: ${productAddress}\n`;
    logger.info(addresses);
}

async function deployProduct(
    owner: Signer, libraries: LibraryAddresses, registry: RegistryAddresses, 
    instance: InstanceAddresses, tokenAddress: AddressLike, poolAddress: AddressLike
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
        { libraries: {  }});
    
    const testPool = productContractBase as Registerable;
    const tx = await executeTx(async () => await testPool.register());
    const productNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    
    return {
        productAddress,
        productNftId,
    };
}

async function deployPool(owner: Signer, libraries: LibraryAddresses, registry: RegistryAddresses, instance: InstanceAddresses): Promise<{
    tokenAddress: AddressLike,
    poolAddress: AddressLike,
    poolNftId: string,
}> {
    const { address: tokenAddress } = await deployContract(
        "USDC",
        owner);

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
        { libraries: {  }}
        );

    const testPool = poolContractBase as Registerable;
    const tx = await executeTx(async () => await testPool.register());
    const poolNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    
    return {
        tokenAddress,
        poolAddress,
        poolNftId,
    };
}


main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});


