import { AddressLike, BaseContract, Signer, TransactionResponse, resolveAddress } from "ethers";
import hre, { ethers } from "hardhat";
import { logger } from "../logger";
import { deploymentState, isResumeableDeployment } from "./deployment_state";

type DeploymentResult = {
    address: AddressLike; 
    deploymentTransaction: TransactionResponse | null;
    contract: BaseContract | null;
}

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
export async function deployContract(contractName: string, signer: Signer, constructorArgs?: any[] | undefined, factoryOptions?: any): Promise<DeploymentResult> {
    if (! isResumeableDeployment ) {
        logger.info("Starting new deployment");
        return executeAllDeploymentSteps(contractName, signer, constructorArgs, factoryOptions);
    }

    logger.info(`Trying to resume deployment of ${contractName}`);

    if (deploymentState.getContractAddress(contractName) === undefined) {
        if (deploymentState.getDeploymentTransaction(contractName) === undefined) {
            // TODO: check if contract exists in registry and continue from there
            return executeAllDeploymentSteps(contractName, signer, constructorArgs, factoryOptions);
        } else {
            return awaitDeploymentTxAndVerify(contractName, signer, constructorArgs);
        }
    } else {
        // fetch persisted data
        const address = deploymentState.getContractAddress(contractName)!;
        const deploymentTransaction = await ethers.provider.getTransaction(deploymentState.getDeploymentTransaction(contractName)!)!;
        const contract = await ethers.getContractAt(contractName, address, signer);
        
        if (deploymentState.isDeployedAndVerified(contractName)) {
            logger.info(`Contract ${contractName} is already deployed at ${address} and verified`);
        } else {
            logger.info(`Contract ${contractName} is already deployed at ${address}`);
            if (deploymentTransaction !== null) {
                await verifyDeployedContract(contractName, address, deploymentTransaction, constructorArgs);
            }
        }

        return { address, deploymentTransaction, contract };
    }
}

export function delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function executeAllDeploymentSteps(contractName: string, signer: Signer, constructorArgs?: any[] | undefined, factoryOptions?: any): Promise<DeploymentResult> {
    logger.info(`Deploying ${contractName}...`);
        const factoryArgs = factoryOptions ? { ...factoryOptions, signer } : { signer };
        const contractFactory = await ethers.getContractFactory(contractName, factoryArgs);

        const deployTxResponse = constructorArgs !== undefined
            ? await contractFactory.deploy(...constructorArgs) 
            : await contractFactory.deploy();
        deploymentState.setDeploymentTransaction(contractName, deployTxResponse.deploymentTransaction()?.hash!);
        logger.info(`Waiting for deployment transaction ${deployTxResponse.deploymentTransaction()?.hash} to be mined...`);
        await deployTxResponse.deploymentTransaction()?.wait();
        logger.debug("... mined");
        
        const deployedContractAddress = deployTxResponse.target;
        deploymentState.setContractAddress(contractName, await resolveAddress(deployedContractAddress));
        logger.info(`${contractName} deployed to ${deployedContractAddress}`);
        
        await verifyDeployedContract(contractName, deployedContractAddress, deployTxResponse.deploymentTransaction()!, constructorArgs);

        return { 
            address: deployedContractAddress, 
            deploymentTransaction: deployTxResponse.deploymentTransaction(), 
            contract: deployTxResponse 
        };
}

async function verifyDeployedContract(contractName: string, address: AddressLike, tx: TransactionResponse, constructorArgs?: any[] | undefined) {
    if (process.env.SKIP_VERIFICATION?.toLowerCase() !== "true") {
        logger.debug("Waiting for 5 confirmations");
        await tx.wait(5); // TODO: make this configurable
        constructorArgs !== undefined
            ? await verifyContract(address, constructorArgs)
            : await verifyContract(address, []);
        deploymentState.setVerified(contractName, true);
    } else {
        logger.debug("Skipping verification");
    }
}

async function awaitDeploymentTxAndVerify(contractName: string, signer: Signer, constructorArgs?: any[] | undefined): Promise<DeploymentResult> {
    logger.info(`Waiting for deployment transaction ${deploymentState.getDeploymentTransaction(contractName)} to be mined...`);
    const deploymentTx = deploymentState.getDeploymentTransaction(contractName)!
    const deploymentTransaction = await ethers.provider.getTransaction(deploymentTx);
    if (deploymentTransaction === null) {
        throw new Error(`Deployment transaction ${deploymentState.getDeploymentTransaction(contractName)} not found`);
    }
    if (! deploymentTransaction.isMined()) {
        await deploymentTransaction.wait();
    }

    const receipt = await ethers.provider.getTransactionReceipt(deploymentTx);
    if (receipt === null) {
        throw new Error(`Deployment transaction receipt ${deploymentState.getDeploymentTransaction(contractName)} not found`);
    }

    const address = receipt.contractAddress!;
    const contract = await ethers.getContractAt(contractName, address, signer);

    deploymentState.setContractAddress(contractName, await resolveAddress(address));
    
    await verifyDeployedContract(contractName, address, deploymentTransaction, constructorArgs);

    return { address, deploymentTransaction, contract };
}