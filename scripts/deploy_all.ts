import { ethers } from "hardhat";
import { AddressLike, BaseContract, FeeData, Interface, Signer, decodeBytes32String, formatEther, resolveAddress } from "ethers";
import { deployContract, verifyContract } from "./lib/deployment";
import { logger } from "./logger";
import { ComponentOwnerService__factory, IChainNft__factory, IERC721Enumerable, IERC721Enumerable__factory, IOwnable__factory, IRegistry__factory, Instance__factory, Registry, UFixedMathLib__factory } from "../typechain-types";
import { getNamedAccounts, printBalance, validateOwnership } from "./lib/accounts";
import * as iERC721Abi  from "../artifacts/@openzeppelin/contracts/token/ERC721/IERC721.sol/IERC721.json";
import { Coder } from "abi-coder";
import { getFieldFromLogs } from "./lib/transaction";
import { Role, grantRole, registerInstance } from "./lib/instance";
import { registerComponent } from "./lib/componentownerservice";


async function main() {
    const { protocolOwner, instanceOwner, productOwner, poolOwner } = await getNamedAccounts();

    // deploy protocol contracts
    const { registryAddress, nfIdLibAddress, chainNftAddress } = await deployRegistry(protocolOwner);
    const { componentOwnerServiceAddress, productServiceAddress, uFixedMathLibAddress } = await deployServices(protocolOwner, registryAddress, nfIdLibAddress);

    // deploy instance contracts
    const { instanceAddress } = await deployInstance(
        instanceOwner, 
        nfIdLibAddress, uFixedMathLibAddress, 
        registryAddress, componentOwnerServiceAddress, productServiceAddress);

    // deploy pool & product contracts
    const { poolAddress, tokenAddress } = await deployPool(poolOwner, nfIdLibAddress, registryAddress, instanceAddress);
    const { productAddress } = await deployProduct(productOwner, uFixedMathLibAddress, nfIdLibAddress, registryAddress, instanceAddress, poolAddress, tokenAddress);

    const { instanceNftId, poolNftId, productNftId } = await registerInstanceAndComponents(
        instanceOwner, productOwner, poolOwner,
        componentOwnerServiceAddress,
        instanceAddress, productAddress, poolAddress);

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
    instanceAddress: AddressLike, productAddress: AddressLike, poolAddress: AddressLike
): Promise<{
    instanceNftId: string,
    poolNftId: string,
    productNftId: string,
}> {
    // register instance
    const instanceNftId = await registerInstance(instanceOwner, instanceAddress);
    
    // grant pool role and register pool
    await grantRole(instanceOwner, instanceAddress, Role.POOL_OWNER_ROLE, poolOwner);
    const poolNftId = await registerComponent(componentOwnerServiceAddress, poolOwner, poolAddress);
    
    // grant product role and register product
    await grantRole(instanceOwner, instanceAddress, Role.PRODUCT_OWNER_ROLE, productOwner);
    const productNftId = await registerComponent(componentOwnerServiceAddress, productOwner, productAddress);

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

async function deployPool(owner: Signer, nftIdLibAddress: AddressLike, registryAddress: AddressLike, instanceAddress: AddressLike): Promise<{
    tokenAddress: AddressLike,
    poolAddress: AddressLike,
}> {
    const { address: tokenAddress } = await deployContract(
        "USDC",
        owner);
    const { address: poolAddress } = await deployContract(
        "TestPool",
        owner,
        [
            registryAddress,
            instanceAddress,
            tokenAddress,
        ],
        { libraries: { NftIdLib: nftIdLibAddress }}
        );
    return {
        tokenAddress,
        poolAddress,
    };
}

async function deployServices(owner: Signer, registryAddress: AddressLike, nfIdLibAddress: AddressLike): Promise<{
    componentOwnerServiceAddress: AddressLike,
    productServiceAddress: AddressLike,
    uFixedMathLibAddress: AddressLike,
}> {
    const { address: componentOwnerServiceAddress } = await deployContract(
        "ComponentOwnerService",
        owner,
        [registryAddress],
        { libraries: { NftIdLib: nfIdLibAddress }});
    const { address: productServiceAddress } = await deployContract(
        "ProductService",
        owner,
        [registryAddress],
        { libraries: { NftIdLib: nfIdLibAddress }});

    const { address: uFixedMathLibAddress } = await deployContract(
        "UFixedMathLib",
        owner);

    return {
        componentOwnerServiceAddress,
        productServiceAddress,
        uFixedMathLibAddress
    };
}

async function deployInstance(
    owner: Signer, 
    nfIdLibAddress: AddressLike,
    uFixedMathLibAddress: AddressLike,
    registryAddress: AddressLike,
    componentOwnerServiceAddress: AddressLike,
    productServiceAddress: AddressLike,
): Promise<{
    instanceAddress: AddressLike,
}> {
    const { address: instanceAddress } = await deployContract(
        "Instance",
        owner,
        [registryAddress, componentOwnerServiceAddress, productServiceAddress],
        { libraries: { NftIdLib: nfIdLibAddress, UFixedMathLib: uFixedMathLibAddress }});
    return {
        instanceAddress,
    };
}

async function deployRegistry(owner: Signer): Promise<{
    registryAddress: AddressLike,
    chainNftAddress: AddressLike,
    nfIdLibAddress: AddressLike,
}> {
    const { address: nfIdLibAddress } = await deployContract(
        "NftIdLib",
        owner);
    const { address: registryAddress, contract: registryBaseContract } = await deployContract(
        "Registry",
        owner,
        undefined,
        {
            libraries: {
                NftIdLib: nfIdLibAddress,
            }
        });
    const { address: chainNftAddress } = await deployContract(
        "ChainNft",
        owner,
        [registryAddress]);

    const registry = registryBaseContract as Registry;
    await registry.initialize(chainNftAddress);
    logger.info(`Registry initialized with ChainNft @ ${chainNftAddress}`);

    return {
        registryAddress,
        chainNftAddress,
        nfIdLibAddress,
    };
}


main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});


