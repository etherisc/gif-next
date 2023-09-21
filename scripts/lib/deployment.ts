import { AddressLike, BaseContract, Signer, TransactionResponse, resolveAddress } from "ethers";
import hre, { ethers } from "hardhat";
import { logger } from "../logger";
import { deploymentState, isTrackDeploymentStateEnabled } from "./deployment_state";

/**
 * Verify a smart contract on Etherscan using hardhat-etherscan task "verify". 
 */
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

/**
 * Deploy a smart contract to the block chain.
 * 
 * @param contractName the name of the smart contract to deploy
 * @param signer the signer to use for the deployment
 * @param constructorArgs a list of constructor arguments to pass to the contract constructor
 * @param factoryOptions options to pass to the contract factory (libraries, ...)
 */
export async function deployContract(contractName: string, signer: Signer, constructorArgs?: any[] | undefined, factoryOptions?: any): Promise<{
    address: AddressLike; 
    deploymentTransaction: TransactionResponse | null;
    contract: BaseContract;
}> {
    // check if contract is already deployed 
    if (isTrackDeploymentStateEnabled && deploymentState.isDeployedAndVerified(contractName)) {    
        const addr = deploymentState.getContractAddress(contractName)!;
        return {
            address: addr,
            deploymentTransaction: await ethers.provider.getTransaction(deploymentState.getDeploymentTransaction(contractName)!)!,
            contract: await ethers.getContractAt(contractName, addr, signer),
        }
    }

    // TODO: should work when only contract name and address are given (not deployment tx)

    if (! isTrackDeploymentStateEnabled || deploymentState.getDeploymentTransaction(contractName) === undefined) {
        logger.info(`Deploying ${contractName}...`);
        const factoryArgs = factoryOptions ? { ...factoryOptions, signer } : { signer };
        const contractFactory = await ethers.getContractFactory(contractName, factoryArgs);

        const deployTxResponse = constructorArgs !== undefined
            ? await contractFactory.deploy(...constructorArgs) 
            : await contractFactory.deploy();
        logger.debug("Waiting for deployment transaction to be mined...");
        deploymentState.setDeploymentTransaction(contractName, deployTxResponse.deploymentTransaction()?.hash!);
        await deployTxResponse.waitForDeployment();
        
        const deployedContractAddress = deployTxResponse.target;
        deploymentState.setContractAddress(contractName, await resolveAddress(deployedContractAddress));
        logger.info(`${contractName} deployed to ${deployedContractAddress}`);
        
        if (process.env.SKIP_VERIFICATION?.toLowerCase() !== "true") {
            logger.debug("Waiting for 5 confirmations");
            await deployTxResponse!.deploymentTransaction()?.wait(5);
            constructorArgs !== undefined
                ? await verifyContract(deployedContractAddress, constructorArgs)
                : await verifyContract(deployedContractAddress, []);
            deploymentState.setVerified(contractName, true);
        } else {
            logger.debug("Skipping verification");
        }

        return { 
            address: deployedContractAddress, 
            deploymentTransaction: deployTxResponse.deploymentTransaction(), 
            contract: deployTxResponse 
        };
    } else if (deploymentState.getDeploymentTransaction(contractName) !== undefined && deploymentState.getContractAddress(contractName) === undefined) {
        logger.info(`Waiting for ${contractName} to be deployed...`);
        const receipt = await ethers.provider.getTransactionReceipt(deploymentState.getDeploymentTransaction(contractName)!);
        if (receipt === null || receipt.contractAddress === null) {
            throw new Error("Deployment transaction receipt not found");
        }
        const deployedContractAddress = receipt.contractAddress;
        deploymentState.setContractAddress(contractName, deployedContractAddress!);
        logger.info(`${contractName} deployed to ${deployedContractAddress}`);

        
        if (process.env.SKIP_VERIFICATION?.toLowerCase() !== "true") {
            // TODO: make this configurable
            // wait until tx has 5 confirmations 
            logger.debug("wait until tx has 5 confirmations");
            while (await receipt.confirmations() < 5) {
                delay(1000);
            }
            constructorArgs !== undefined
                ? await verifyContract(deployedContractAddress!, constructorArgs)
                : await verifyContract(deployedContractAddress!, []);
            deploymentState.setVerified(contractName, true);
        } else {
            logger.debug("Skipping verification");
        }

        return { 
            address: deployedContractAddress!, 
            deploymentTransaction: await receipt.getTransaction(), 
            contract: await ethers.getContractAt(contractName, deployedContractAddress!, signer)
        };
    } else {
        // TODO: check getCode = 0x
        logger.info(`Waiting for ${contractName} to be verified...`);
        const deployedContractAddress = deploymentState.getContractAddress(contractName);
        if (process.env.SKIP_VERIFICATION?.toLowerCase() !== "true") {
            constructorArgs !== undefined
                ? await verifyContract(deployedContractAddress!, constructorArgs)
                : await verifyContract(deployedContractAddress!, []);
            deploymentState.setVerified(contractName, true);
        } else {
            logger.debug("Skipping verification");
        }

        return { 
            address: deployedContractAddress!, 
            deploymentTransaction: await ethers.provider.getTransaction(deploymentState.getDeploymentTransaction(contractName)!), 
            contract: await ethers.getContractAt(contractName, deployedContractAddress!, signer)
        };
    }
}

export function delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
}
