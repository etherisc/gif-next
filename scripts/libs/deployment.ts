/* eslint-disable @typescript-eslint/no-explicit-any */

import { AddressLike, BaseContract, Signer, TransactionReceipt, TransactionResponse, resolveAddress } from "ethers";
import hre, { ethers, tenderly } from "hardhat";
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
// TODO verifyContract() and verifyDeployedContract() -> wrong naming
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
    // TODO get libraries from artifacts?
export async function deployContract(contractName: string, contractType: string, signer: Signer, constructorArgs?: any[] | undefined, factoryOptions?: any | undefined, sourceFileContract?: string): Promise<DeploymentResult> {
    // TODO use static variable as isResumeableDeployment -> set only at the first call in script run
    if (! isResumeableDeployment ) {
        logger.info("Starting new deployment");
        return executeAllDeploymentSteps(contractType, contractType, signer, constructorArgs, factoryOptions, sourceFileContract);
    }

    logger.info(`Trying to resume deployment of ${contractName}`);

    const isDeploying = deploymentState.isDeploying(contractName);
    if(isDeploying) {
        return awaitDeploymentTxAndVerify(contractName, contractType, signer, constructorArgs, sourceFileContract);
    }

    const isDeployed = deploymentState.isDeployed(contractName);
    if (!isDeployed) {
        return executeAllDeploymentSteps(contractName, contractType, signer, constructorArgs, factoryOptions, sourceFileContract);
    }

    // assume contract was deployed
    // fetch local persisted deployment state
    const deployedContractAddress = deploymentState.getContractAddress(contractName)!;
    const deploymentTransactionHash = deploymentState.getDeploymentTransaction(contractName)!;

    // fetch onchain state -> gives error on local chain
    const contract = await ethers.getContractAt(contractType, deployedContractAddress, signer) as BaseContract;
    const deploymentTransaction = await ethers.provider.getTransaction(deploymentTransactionHash);
    const deploymentTransactionReceipt = await ethers.provider.getTransactionReceipt(deploymentTransactionHash);
/*
    // check onchain state for existance -> gives error on local chain
    if(contract === null) {
        throw new Error(`Onchain state: ${contractName} not found at ${deployedContractAddress}`);
    }

    if(deploymentTransaction === null) {
        throw new Error(`Onchain state: ${contractName} deployment transaction ${deploymentTransactionHash} not found`);
    }

    if(deploymentTransactionReceipt === null) {
        throw new Error(`Onchain state: ${contractName} deployment transaction receipt ${deploymentTransactionHash} not found`);
    }
*/
    logger.info(`${contractName} already deployed at ${deployedContractAddress}`);

    const isVerified = deploymentState.isDeployedAndVerified(contractName);
    if(!isVerified) {
        await verifyDeployedContract(contractName, contractType, deployedContractAddress, deploymentTransaction, constructorArgs, sourceFileContract);
    } else {
        logger.info(`Contract ${contractName} already verified`);
    }

    return { 
        address: deployedContractAddress, 
        deploymentTransaction: deploymentTransaction, 
        deploymentReceipt: deploymentTransactionReceipt,
        contract: contract 
    }
}

// Use this function to add to deployment state (and verify) a deployed contract (e.g. contract deployed by other contract)
export async function addDeployedContract(contractName: string, contractType: string, deployedContractAddress: AddressLike, deploymentTransaction: TransactionResponse, constructorArgs?: any[] | undefined, factoryOptions?: any | undefined, sourceFileContract?: string) {
    const libraries = factoryOptions?.libraries ?? {};
    if(deploymentTransaction == undefined) {
        throw new Error(`Deployment transaction of ${contractName} is not provided`);
    }

    // fetch onchain state\
/* 
    const contract = await ethers.getContractAt(contractType, deployedContractAddress) as BaseContract;
    const actualDeploymentTransaction = await ethers.provider.getTransaction(deploymentTransaction.hash);
    const actualDeploymentTransactionReceipt = await ethers.provider.getTransactionReceipt(deploymentTransaction.hash);
    check given tx and oncahin tx are the same
    if(deploymentTransaction != actualDeploymentTransaction) {
        throw new Error(`Deployment transaction hash of ${contractName} is wrong, provided ${deploymentTransaction.hash}, actual ${actualDeploymentTransaction.hash}`);
    }

    if(contract === null) {
        throw new Error(`Onchain state: ${contractName} not found at ${deployedContractAddress}`);
    }

    if(actualDeploymentTransaction === null) {
        throw new Error(`Onchain state: ${contractName} deployment transaction ${deploymentTransaction.hash} not found`);
    }

    if(actualDeploymentTransactionReceipt === null) {
        throw new Error(`Onchain state: ${contractName} deployment transaction receipt ${deploymentTransaction.hash} not found`);
    }
*/
    if (! isResumeableDeployment ) {
        logger.info(`Adding new ${contractName} of type ${contractType} to deployment state...`);
        // create new / overwrite existing deployment state
        deploymentState.setDeploymentTransaction(contractName, contractType, deploymentTransaction?.hash || "0x", libraries);
        deploymentState.setContractAddress(contractName, deployedContractAddress);
        logger.info(`Contract ${contractName} set deployed at ${deployedContractAddress}`);
        await verifyDeployedContract(contractName, contractType, deployedContractAddress, deploymentTransaction, constructorArgs, sourceFileContract);
        return;
    }

    logger.info(`Checking ${contractName} deployment state...`);

    const isDeployed = deploymentState.isDeployed(contractName);
    if(!isDeployed) {
        logger.info(`Adding ${contractName} of type ${contractType} to deployment state...`);
        // deploymet state is not set yet
        deploymentState.setDeploymentTransaction(contractName, contractType, deploymentTransaction?.hash || "0x", libraries);
        deploymentState.setContractAddress(contractName, deployedContractAddress);
        logger.info(`${contractName} set deployed at ${deployedContractAddress}`);
        await verifyDeployedContract(contractName, contractType, deployedContractAddress, deploymentTransaction, constructorArgs, sourceFileContract);
        return;
    }

    logger.info(`${contractName} is already in deployment state`);
    logger.info(`${contractName} deployed at ${deployedContractAddress}`);
    //logger.info(`Checking ${contractName} verification...`);

    const isVerified = deploymentState.isDeployedAndVerified(contractName);
    if(!isVerified) {
        await verifyDeployedContract(contractName, contractType, deployedContractAddress, deploymentTransaction, constructorArgs, sourceFileContract);
        return;
    }

    logger.info(`${contractName} is already verified`);
}

export function delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function executeAllDeploymentSteps(contractName: string, contractType: string, signer: Signer, constructorArgs?: any[] | undefined, factoryOptions?: any | undefined, sourceFileContract?: string): Promise<DeploymentResult> {
    logger.info(`Deploying ${contractName} of type ${contractType}...`);
    const factoryArgs = factoryOptions != undefined ? { ...factoryOptions, signer } : { signer };
    const contractFactory = await ethers.getContractFactory(contractType, factoryArgs);

    const opts = {} as any;
    if (GAS_PRICE !== undefined) {
        opts['gasPrice'] = GAS_PRICE;
    }
    const deployTxResponse = constructorArgs !== undefined
        ? await contractFactory.deploy(...constructorArgs, opts) 
        : await contractFactory.deploy(opts);
    const libraries = factoryOptions?.libraries ?? {};
    deploymentState.setDeploymentTransaction(contractName, contractType, deployTxResponse.deploymentTransaction()?.hash || "0x", libraries);
    logger.info(`Waiting for deployment transaction ${deployTxResponse.deploymentTransaction()?.hash} to be mined...`);
    await deployTxResponse.deploymentTransaction()?.wait();
    logger.debug("... mined");
    
    const deployedContractAddress = deployTxResponse.target;
    const deploymentReceipt = await ethers.provider.getTransactionReceipt(deployTxResponse.deploymentTransaction()?.hash || "0x");
    deploymentState.setContractAddress(contractName, await resolveAddress(deployedContractAddress));
    logger.info(`${contractName} deployed to ${deployedContractAddress}`);
    
    await verifyDeployedContract(contractName, contractType, deployedContractAddress, deployTxResponse.deploymentTransaction()!, constructorArgs, sourceFileContract);

    return { 
        address: deployedContractAddress, 
        deploymentTransaction: deployTxResponse.deploymentTransaction(), 
        deploymentReceipt: deploymentReceipt,
        contract: deployTxResponse 
    };
}

async function verifyDeployedContract(contractName: string, contractType: string, address: AddressLike, tx: TransactionResponse, constructorArgs?: any[] | undefined, sourceFileContract?: string) {
        
    // Tenderly verification
    if (process.env.ENABLE_TENDERLY_VERIFICATION?.toLowerCase() === "true") {
        const libraries = deploymentState.getLibraries(contractName);
        logger.info(`Verifing ${contractName}`)
        await tenderly.verify({name: contractType, address: address, libraries: libraries});
        deploymentState.setVerified(contractName, true);
    } else {
        logger.debug("Skipping Tenderly verification");
    }

    // Etherscan verification
    if (process.env.ENABLE_ETHERSCAN_VERIFICATION?.toLowerCase() === "true") {
        logger.debug(`Waiting for ${NUMBER_OF_CONFIRMATIONS} confirmations`);
        await tx.wait(NUMBER_OF_CONFIRMATIONS); 
        constructorArgs !== undefined
            ? await verifyContract(address, constructorArgs, sourceFileContract)
            : await verifyContract(address, [], sourceFileContract);
        deploymentState.setVerified(contractName, true);
    } else {
        logger.debug("Skipping Etherscan verification");
    }
}

async function awaitDeploymentTxAndVerify(contractName: string, contractType: string, signer: Signer, constructorArgs?: any[] | undefined, sourceFileContract?: string): Promise<DeploymentResult> {
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
    
    await verifyDeployedContract(contractName, contractType, address, deploymentTransaction, constructorArgs, sourceFileContract);

    return { address, deploymentTransaction, contract };
}