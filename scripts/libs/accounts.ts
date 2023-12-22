import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { AddressLike, formatEther, resolveAddress } from "ethers";
import { ethers } from "hardhat";
import { IChainNft__factory, IOwnable__factory } from "../../typechain-types";
import { logger } from "../logger";

export async function getNamedAccounts(): Promise<{ 
    protocolOwner: HardhatEthersSigner;
    instanceOwner: HardhatEthersSigner; 
    productOwner: HardhatEthersSigner; 
    poolOwner: HardhatEthersSigner; 
    distributionOwner: HardhatEthersSigner; 
}> {
    const signers = await ethers.getSigners();
    const protocolOwner = signers[0];
    const instanceOwner = signers[1];
    const productOwner = signers[2];
    const poolOwner = signers[3];
    const distributionOwner = signers[4];
    await printBalance(
        ["protocolOwner", protocolOwner] ,
        ["instanceOwner", instanceOwner] , 
        ["productOwner", productOwner], 
        ["poolOwner", poolOwner],
        ["distributionOwner", distributionOwner]
    );
    return { protocolOwner, instanceOwner, productOwner, poolOwner, distributionOwner }; 
}

export async function printBalance(...signers: [string,HardhatEthersSigner][]) {
    for (const signer of signers) {
        const balance = await ethers.provider.getBalance(signer[1]);
        logger.info(`${signer[0]} ${signer[1].address}: ${formatEther(balance)}`);
    }
}

/**
 * Validate that the contract at the given address is owned by the given owner. This required the contract to implement the IOwnable interface.
 */
export async function validateOwnership(owner: AddressLike, address: AddressLike): Promise<void> {
    const contract = IOwnable__factory.connect(address.toString(), ethers.provider);
    const contractOwner = await contract.getOwner();
    if (contractOwner !== await resolveAddress(owner)) {
        throw new Error(`Contract owner is not ${owner}`);
    }
}

export async function validateNftOwnerhip(chainNftAddress: AddressLike, nftId: string, expectedOwner: AddressLike): Promise<void> {
    const chainNft = IChainNft__factory.connect(await resolveAddress(chainNftAddress), ethers.provider);

    const componentOwnerServiceNftOwer = await chainNft.ownerOf(nftId);
    if (componentOwnerServiceNftOwer !== await resolveAddress(expectedOwner)) {
        throw new Error(`Ownership mismatch - nftId: ${nftId} expected owner: ${expectedOwner} actual owner: ${componentOwnerServiceNftOwer}`);
    }
}

