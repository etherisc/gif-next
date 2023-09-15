import hre, { ethers } from "hardhat";
import { AddressLike, Signer, ContractTransactionResponse, BaseContract } from "ethers";
import { logger } from "../logger";

export async function verifyContract(address: AddressLike, constructorArgs: any[]) {
    logger.debug("verifying contract @ address: " + address);
    try {
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: constructorArgs,
        });
        logger.info("Contract verified");
    } catch (err: any) {
        if (err.message.toLowerCase().includes("already verified")) {
            logger.info("Contract is already verified!");
        } else {
            throw err;
        }
    }
};

export async function deployContract(contractName: string, owner: Signer, constructorArgs?: any[] | undefined, factoryOptions?: any): Promise<{
    address: AddressLike; 
    deploymentTransaction: ContractTransactionResponse | null;
    contract: BaseContract;
}> {
    logger.info(`Deploying ${contractName}...`);
    const factoryArgs = factoryOptions ? { ...factoryOptions, owner } : { owner };
    const contractFactory = await ethers.getContractFactory(contractName, factoryArgs);

    // TODO: make this two-stepped so that we can wait for the deployment transaction to be mined 
    // and have access to tx already in between
    const deployTxResponse = constructorArgs !== undefined
        ? await contractFactory.deploy(...constructorArgs) 
        : await contractFactory.deploy();
    
    const deployedContractAddress = deployTxResponse.target;
    logger.info(`${contractName} deployed to ${deployedContractAddress}`);

    if (process.env.SKIP_VERIFICATION?.toLowerCase() !== "true") {
        logger.debug("Waiting for 5 confirmations");
        await deployTxResponse.deploymentTransaction()?.wait(5);
        constructorArgs !== undefined
            ? await verifyContract(deployedContractAddress, constructorArgs)
            : await verifyContract(deployedContractAddress, []);
    } else {
        logger.debug("Skipping verification");
    }

    return { 
        address: deployedContractAddress, 
        deploymentTransaction: deployTxResponse.deploymentTransaction(), 
        contract: deployTxResponse 
    };
}
