import { ethers } from "hardhat";
import { AddressLike, FeeData, Interface, Signer, decodeBytes32String, formatEther } from "ethers";
import { deployContract, verifyContract } from "./lib/deployment";
import { logger } from "./logger";
import { ComponentOwnerService__factory, IERC721Enumerable, IERC721Enumerable__factory, Instance__factory, Registry, UFixedMathLib__factory } from "../typechain-types";
import { getNamedAccounts, printBalance } from "./lib/accounts";
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

    // print final balance
    await printBalance(
        ["protocolOwner", protocolOwner] ,
        ["instanceOwner", instanceOwner] , 
        ["productOwner", productOwner], 
        ["poolOwner", poolOwner]);
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
    logger.error(error.message);
    process.exitCode = 1;
});


