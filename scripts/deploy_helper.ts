import hre, { ethers } from "hardhat";
import { AddressLike, Signer, ContractTransactionResponse } from "ethers";
import { logger } from "./logger";

export async function verifyContract(address: AddressLike, constructorArgs: any[]) {
    logger.debug("verifying contract @ address: " + address);
    try {
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: constructorArgs,
        });
        logger.info("Contract verified\n\n");
    } catch (err: any) {
        if (err.message.toLowerCase().includes("already verified")) {
            logger.info("Contract is already verified! \n\n");
        } else {
            throw err;
        }
    }
};

export async function deployContract(contractName: string, signer: Signer, factoryOptions?: any): Promise<{
    address: AddressLike; 
    deploymentTransaction: ContractTransactionResponse | null;
}> {
    const factoryArgs = factoryOptions ? { ...factoryOptions, signer } : { signer };
    const contractFactory = await ethers.getContractFactory(contractName, factoryArgs);
    const deployTxResponse = await contractFactory.deploy();
    const deployedContractAddress = deployTxResponse.target;
    logger.info(`${contractName} deployed to ${deployedContractAddress}`);

    if (process.env.SKIP_VERIFICATION?.toLowerCase() !== "true") {
        await deployTxResponse.deploymentTransaction()?.wait(5);
        await verifyContract(deployedContractAddress, []);
    } else {
        logger.debug("Skipping verification");
    }

    return { address: deployedContractAddress, deploymentTransaction: deployTxResponse.deploymentTransaction() };
}
