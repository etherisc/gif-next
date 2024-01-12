import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { AddressLike, formatEther, resolveAddress } from "ethers";
import { ethers } from "hardhat";
import { ChainNft__factory } from "../../typechain-types";
import { logger } from "../logger";

export async function getNamedAccounts(): Promise<{ 
    protocolOwner: HardhatEthersSigner;
    instanceServiceOwner: HardhatEthersSigner;
    masterInstanceOwner: HardhatEthersSigner; 
    productOwner: HardhatEthersSigner; 
    poolOwner: HardhatEthersSigner; 
    distributionOwner: HardhatEthersSigner; 
    instanceOwner: HardhatEthersSigner;
}> {
    const signers = await ethers.getSigners();
    const protocolOwner = signers[0];
    const masterInstanceOwner = signers[1];
    const productOwner = signers[2];
    const poolOwner = signers[3];
    const distributionOwner = signers[4];
    const instanceServiceOwner = signers[5];
    const instanceOwner = signers[10];
    await printBalance(
        ["protocolOwner", protocolOwner] ,
        ["masterInstanceOwner", masterInstanceOwner] , 
        ["productOwner", productOwner], 
        ["poolOwner", poolOwner],
        ["distributionOwner", distributionOwner],
        ["instanceServiceOwner", instanceServiceOwner],
        ["instanceOwner", instanceOwner],
    );
    return { protocolOwner, masterInstanceOwner, productOwner, poolOwner, distributionOwner, instanceServiceOwner, instanceOwner }; 
}

export async function printBalance(...signers: [string,HardhatEthersSigner][]) {
    for (const signer of signers) {
        const balance = await ethers.provider.getBalance(signer[1]);
        logger.info(`${signer[0]} ${signer[1].address}: ${formatEther(balance)}`);
    }
}


export async function validateNftOwnerhip(chainNftAddress: AddressLike, nftId: string, expectedOwner: AddressLike): Promise<void> {
    const chainNft = ChainNft__factory.connect(await resolveAddress(chainNftAddress), ethers.provider);

    const componentOwnerServiceNftOwer = await chainNft.ownerOf(nftId);
    if (componentOwnerServiceNftOwer !== await resolveAddress(expectedOwner)) {
        throw new Error(`Ownership mismatch - nftId: ${nftId} expected owner: ${expectedOwner} actual owner: ${componentOwnerServiceNftOwer}`);
    }
}

