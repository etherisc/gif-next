import { ethers } from "hardhat";
import { AddressLike, Signer, formatEther } from "ethers";
import { deployContract, verifyContract } from "./lib/deployment";
import { logger } from "./logger";
import { Registry } from "../typechain-types";
import { getNamedAccounts, printBalance } from "./lib/accounts";


async function main() {
    const { instanceOwner, productOwner, poolOwner } = await getNamedAccounts();
    const { registryAddress, nfIdLibAddress, chainNftAddress } = await deployRegistry(instanceOwner);
    const instance = await deployInstance(instanceOwner, registryAddress, nfIdLibAddress);
    printBalance(
        ["instanceOwner", instanceOwner] , 
        ["productOwner", productOwner], 
        ["poolOwner", poolOwner]);
}

async function deployInstance(owner: Signer, registryAddress: AddressLike, nfIdLibAddress: AddressLike): Promise<{
    instanceAddress: AddressLike,
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

    const { address: instanceAddress } = await deployContract(
        "Instance",
        owner,
        [registryAddress, componentOwnerServiceAddress, productServiceAddress],
        { libraries: { NftIdLib: nfIdLibAddress, UFixedMathLib: uFixedMathLibAddress }});
    return {
        instanceAddress,
        componentOwnerServiceAddress,
        productServiceAddress,
        uFixedMathLibAddress
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




