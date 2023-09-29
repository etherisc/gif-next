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

    // TODO: enable this 
    // await grantRole(instanceOwner, instance.instanceAddress, Role.POOL_OWNER_ROLE, poolOwner);
    // await grantRole(instanceOwner, instance.instanceAddress, Role.PRODUCT_OWNER_ROLE, productOwner);

    
    // deploy pool & product contracts
    const { poolAddress, tokenAddress } = await deployPool(poolOwner, libraries, registry, instance);
    throw Error("works up to here"); // TODO: implement the rest
    const { productAddress } = await deployProduct(productOwner, uFixedMathLibAddress, nfIdLibAddress, registryAddress, instanceAddress, poolAddress, tokenAddress);


    // TODO: probably not needed any more
    const { instanceNftId, poolNftId, productNftId } = await registerInstanceAndComponents(
        instanceOwner, productOwner, poolOwner,
        componentOwnerServiceAddress,
        registryAddress, instanceAddress, productAddress, poolAddress);

    printAddresses(
        registryAddress, chainNftAddress,
        componentOwnerServiceAddress, productServiceAddress, 
        instanceAddress,
        tokenAddress, poolAddress, productAddress);

    await verifyOwnership(
        instanceOwner, productOwner, poolOwner,
        registryAddress,
        instanceAddress, 
        instanceNftId, poolNftId, productNftId,
        chainNftAddress);

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

async function registerInstanceAndComponents(
    instanceOwner: Signer, productOwner: Signer, poolOwner: Signer,
    componentOwnerServiceAddress: AddressLike,
    registryAddress: AddressLike, instanceAddress: AddressLike, productAddress: AddressLike, poolAddress: AddressLike
): Promise<{
    instanceNftId: string,
    poolNftId: string,
    productNftId: string,
}> {
    // register instance
    const instanceNftId = await registerInstance(instanceOwner, instanceAddress, registryAddress);
    
    // grant pool role and register pool
    const poolNftId = await registerComponent(componentOwnerServiceAddress, poolOwner, poolAddress, registryAddress);
    
    // grant product role and register product
    const productNftId = await registerComponent(componentOwnerServiceAddress, productOwner, productAddress, registryAddress);

    return { instanceNftId, poolNftId, productNftId };
}

async function deployProduct(
    owner: Signer, uFixedMathLibAddress: AddressLike, nftIdLibAddress: AddressLike, 
    registryAddress: AddressLike, instanceAddress: AddressLike, poolAddress: AddressLike, tokenAddress: AddressLike
): Promise<{
    productAddress: AddressLike,
}> {
    const uFixedMathLib = UFixedMathLib__factory.connect(uFixedMathLibAddress.toString(), owner);
    const fractionalFee = await uFixedMathLib["itof(uint256,int8)"](1, -1);
    const { address: productAddress } = await deployContract(
        "TestProduct",
        owner,
        [
            registryAddress,
            instanceAddress,
            tokenAddress,
            poolAddress,
            {
                fractionalFee,
                fixedFee: 0
            }
        ],
        { libraries: { NftIdLib: nftIdLibAddress }});
    return {
        productAddress,
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

    // TODO: enable this when role is accessible
    // const testPool = poolContractBase as Registerable;
    // const tx = await executeTx(async () => await testPool.register());
    // const poolNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    const poolNftId = "0";

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


