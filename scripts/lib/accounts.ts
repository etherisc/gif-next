import { ethers } from "hardhat";
import { logger } from "../logger";
import { Signer, formatEther } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

export async function getNamedAccounts(): Promise<{ instanceOwner: HardhatEthersSigner; productOwner: HardhatEthersSigner; poolOwner: HardhatEthersSigner; }> {
    const signers = await ethers.getSigners();
    const instanceOwner = signers[0];
    const productOwner = signers[1];
    const poolOwner = signers[2];
    printBalance(
        ["instanceOwner", instanceOwner] , 
        ["productOwner", productOwner], 
        ["poolOwner", poolOwner]);
    return { instanceOwner, productOwner, poolOwner }; 
}

export async function printBalance(...signers: [string,HardhatEthersSigner][]) {
    for (const signer of signers) {
        const balance = await ethers.provider.getBalance(signer[1]);
        logger.info(`${signer[0]} ${signer[1].address}: ${formatEther(balance)}`);
    }
}