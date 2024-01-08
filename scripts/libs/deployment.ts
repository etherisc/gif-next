/* eslint-disable @typescript-eslint/no-explicit-any */

import { AddressLike, BaseContract, Signer, TransactionReceipt, TransactionResponse, resolveAddress } from "ethers";
import hre, { ethers } from "hardhat";
import { logger } from "../logger";
import { deploymentState, isResumeableDeployment } from "./deployment_state";
import { GAS_PRICE, NUMBER_OF_CONFIRMATIONS } from "./constants";
import { LIBRARY_ADDRESSES } from "./libraries";
import { util } from "chai";

type DeploymentResult = {
    address: AddressLike; 
    deploymentTransaction: TransactionResponse | null;
    deploymentReceipt: TransactionReceipt | null;
    contract: BaseContract | null;
}

/**
 * Verify a smart contract on Etherscan using hardhat-etherscan task "verify". 
 * In case of "does not have bytecode" error, retry after 5s for 3 times in a row. 
 * In case of "MissingLibrariesError", fetch library addresses from LIBRARY_ADDRESSES and retry.
 * @param sourceFileContract the contract name prefixed with file path (e.g. "contracts/types/ObjectType.sol:ObjectTypeLib")
 */
export async function verifyContract(address: AddressLike, constructorArgs: any[], sourceFileContract: string | undefined) {
    let verified = false;
    let retries = 3;
    const libraries: Record<string,string> = {};
    let error = undefined;
    while (! verified && retries > 0) {
        retries--;
        logger.debug("verifying contract @ address: " + address);
        try {
            const args = {
                address: address,
                constructorArguments: constructorArgs,
                libraries: libraries,
            } as any;
            if (sourceFileContract !== undefined) {
                args['contract'] = sourceFileContract;
            }
            await hre.run("verify:verify", args);
            logger.info("Contract verified");
            verified = true;
        } catch (err: any) {
            error = err;
            
            if (err.message.toLowerCase().includes("already verified")) {
                logger.info("Contract is already verified!");
                verified = true;
            } else if (err.message.toLowerCase().includes("does not have bytecode")) {
                logger.info("Bytecode not yet available on Etherscan, retrying in 5s...");
                await delay(5000);
            } else if (err.name === "MissingLibrariesError") { // ethers does not export error - match by name
                logger.debug("caught MissingLibrariesError - fetching library addresses and retry");
                if (retries > 0) retries = 1; // one more retry
                /* 
                 * Extract missing libraries from error message. Error message looks like:
                 *
                 * error: MissingLibrariesError: The contract contracts/instance/Instance.sol:Instance has one or more library addresses that cannot be detected from deployed bytecode.
                 * This can occur if the library is only called in the contract constructor. The missing libraries are:
                 *   * contracts/types/Key32.sol:Key32Lib
                 *   * contracts/types/ObjectType.sol:ObjectTypeLib
                 *   * contracts/types/StateId.sol:StateIdLib
                 */
                const missingLibraries: string[] = err.message.split("\n")
                    .filter((line: string) => line.startsWith("  * "))
                    .map((line: string) => line.split(":").pop()!);
                missingLibraries.forEach(async (lib: string) => {
                    const address = LIBRARY_ADDRESSES.get(lib);
                    if (address === undefined) {
                        throw new Error(`Library address for ${lib} not found`);
                    }
                    libraries[lib] = await resolveAddress(address);
                });
                logger.info("retrying verification with missing libraries: " + util.inspect(libraries));
            } else {
                retries = 0; // no retries
            }
        }
    }

    if (! verified && error !== undefined) {
        throw error;
    }
}

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

        const opts = {} as any;
        if (GAS_PRICE !== undefined) {
            opts['gasPrice'] = GAS_PRICE;
        }
        const deployTxResponse = constructorArgs !== undefined
            ? await contractFactory.deploy(...constructorArgs, opts) 
            : await contractFactory.deploy(opts);
        deploymentState.setDeploymentTransaction(contractName, deployTxResponse.deploymentTransaction()?.hash || "0x");
        logger.info(`Waiting for deployment transaction ${deployTxResponse.deploymentTransaction()?.hash} to be mined...`);
        await deployTxResponse.deploymentTransaction()?.wait();
        logger.debug("... mined");
        
        const deployedContractAddress = deployTxResponse.target;
        const deploymentReceipt = await ethers.provider.getTransactionReceipt(deployTxResponse.deploymentTransaction()?.hash || "0x");
        deploymentState.setContractAddress(contractName, await resolveAddress(deployedContractAddress));
        logger.info(`${contractName} deployed to ${deployedContractAddress}`);
        
        await verifyDeployedContract(contractName, deployedContractAddress, deployTxResponse.deploymentTransaction()!, constructorArgs, sourceFileContract);

        return { 
            address: deployedContractAddress, 
            deploymentTransaction: deployTxResponse.deploymentTransaction(), 
            deploymentReceipt: deploymentReceipt,
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