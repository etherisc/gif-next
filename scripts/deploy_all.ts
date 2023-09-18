import { ethers } from "hardhat";
import { AddressLike, Signer, formatEther } from "ethers";
import { deployContract, verifyContract } from "./lib/deployment";
import { logger } from "./logger";
import { Registry } from "../typechain-types";
import { getNamedAccounts, printBalance } from "./lib/accounts";


async function main() {
    const { protocolOwner, instanceOwner, productOwner, poolOwner } = await getNamedAccounts();

    // deploy protocol contracts
    const { registryAddress, nfIdLibAddress, chainNftAddress } = await deployRegistry(protocolOwner);
    const { componentOwnerServiceAddress, productServiceAddress, uFixedMathLibAddress } = await deployServices(protocolOwner, registryAddress, nfIdLibAddress);

    // deploy instance contracts
    const instance = await deployInstance(
        instanceOwner, 
        nfIdLibAddress, uFixedMathLibAddress, 
        registryAddress, componentOwnerServiceAddress, productServiceAddress);

    // print final balance
    printBalance(
        ["protocolOwner", protocolOwner] ,
        ["instanceOwner", instanceOwner] , 
        ["productOwner", productOwner], 
        ["poolOwner", poolOwner]);
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




