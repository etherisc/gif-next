import { AddressLike, BaseContract, Signer, TransactionResponse, resolveAddress } from "ethers";
import hre, { ethers } from "hardhat";
import { logger } from "../logger";
import { deploymentState, isResumeableDeployment } from "./deployment_state";
import { NUMBER_OF_CONFIRMATIONS } from "./constants";

type DeploymentResult = {
    address: AddressLike; 
    deploymentTransaction: TransactionResponse | null;
    contract: BaseContract | null;
}

/**
 * Verify a smart contract on Etherscan using hardhat-etherscan task "verify". 
 * In case of "does not have bytecode" error, retry after 5s for 3 times in a row. 
 * @param sourceFileContract the contract name prefixed with file path (e.g. "contracts/types/ObjectType.sol:ObjectTypeLib")
 */
export async function verifyContract(address: AddressLike, constructorArgs: any[], sourceFileContract: string | undefined) {
    let retry;
    let n = 0
    do {
        retry = false;
        n += 1;
        logger.debug("verifying contract @ address: " + address);
        try {
            const args = {
                address: address,
                constructorArguments: constructorArgs,
            } as any;
            if (sourceFileContract !== undefined) {
                args['contract'] = sourceFileContract;
            }
            await hre.run("verify:verify", args);
            logger.info("Contract verified");
        } catch (err: any) {
            if (err.message.toLowerCase().includes("already verified")) {
                logger.info("Contract is already verified!");
            } else if (err.message.toLowerCase().includes("does not have bytecode")) {
                logger.info("Bytecode not yet available on Etherscan, retrying in 5s...");
                await delay(5000);
                retry = true;
                if (n > 3) {
                    throw err;
                }
            } else {
                throw err;
            }
        }
    } while (retry);
};

/**
 * Deploy a smart contract to the block chain.
 * 
 * @param contractName the name of the smart contract to deploy
 * @param signer the signer to use for the deployment
 * @param constructorArgs a list of constructor arguments to pass to the contract constructor
 * @param factoryOptions options to pass to the contract factory (libraries, ...)
 */
export async function deployContract(contractName: string, signer: Signer, constructorArgs?: any[] | undefined, factoryOptions?: any | undefined, sourceFileContract?: string): Promise<DeploymentResult> {
    if (! isResumeableDeployment ) {
        logger.info("Starting new deployment");
        return executeAllDeploymentSteps(contractName, signer, constructorArgs, factoryOptions, sourceFileContract);
    }

    logger.info(`Trying to resume deployment of ${contractName}`);

    if (deploymentState.getContractAddress(contractName) === undefined) {
        if (deploymentState.getDeploymentTransaction(contractName) === undefined) {
            // TODO: check if contract exists in registry and continue from there
            return executeAllDeploymentSteps(contractName, signer, constructorArgs, factoryOptions, sourceFileContract);
        } else {
            return awaitDeploymentTxAndVerify(contractName, signer, constructorArgs, sourceFileContract);
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
                await verifyDeployedContract(contractName, address, deploymentTransaction, constructorArgs, sourceFileContract);
            }
        }

        return { address, deploymentTransaction, contract };
    }
}

export function delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function executeAllDeploymentSteps(contractName: string, signer: Signer, constructorArgs?: any[] | undefined, factoryOptions?: any | undefined, sourceFileContract?: string): Promise<DeploymentResult> {
    logger.info(`Deploying ${contractName}...`);
        const factoryArgs = factoryOptions != undefined ? { ...factoryOptions, signer } : { signer };
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
        
        await verifyDeployedContract(contractName, deployedContractAddress, deployTxResponse.deploymentTransaction()!, constructorArgs, sourceFileContract);

        return { 
            address: deployedContractAddress, 
            deploymentTransaction: deployTxResponse.deploymentTransaction(), 
            contract: deployTxResponse 
        };
}

async function verifyDeployedContract(contractName: string, address: AddressLike, tx: TransactionResponse, constructorArgs?: any[] | undefined, sourceFileContract?: string) {
    if (process.env.SKIP_VERIFICATION?.toLowerCase() !== "true") {
        logger.debug(`Waiting for ${NUMBER_OF_CONFIRMATIONS} confirmations`);
        await tx.wait(NUMBER_OF_CONFIRMATIONS); 
        constructorArgs !== undefined
            ? await verifyContract(address, constructorArgs, sourceFileContract)
            : await verifyContract(address, [], sourceFileContract);
        deploymentState.setVerified(contractName, true);
    } else {
        logger.debug("Skipping verification");
    }
}

async function awaitDeploymentTxAndVerify(contractName: string, signer: Signer, constructorArgs?: any[] | undefined, sourceFileContract?: string): Promise<DeploymentResult> {
    const deploymentTx = deploymentState.getDeploymentTransaction(contractName)!
    logger.info(`Deployment transaction ${deploymentTx} exists, waiting for it to be mined...`);
    const deploymentTransaction = await ethers.provider.getTransaction(deploymentTx);
    if (deploymentTransaction === null) {
        throw new Error(`Deployment transaction ${deploymentState.getDeploymentTransaction(contractName)} not found`);
    }
    if (! deploymentTransaction.isMined()) {
        await deploymentTransaction.wait();
    }
    logger.info("...mined");

    const receipt = await ethers.provider.getTransactionReceipt(deploymentTx);
    if (receipt === null) {
        throw new Error(`Deployment transaction receipt ${deploymentState.getDeploymentTransaction(contractName)} not found`);
    }

    const address = receipt.contractAddress!;
    const contract = await ethers.getContractAt(contractName, address, signer);

    deploymentState.setContractAddress(contractName, await resolveAddress(address));
    
    await verifyDeployedContract(contractName, address, deploymentTransaction, constructorArgs, sourceFileContract);

    return { address, deploymentTransaction, contract };
}