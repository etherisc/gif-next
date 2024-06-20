/* eslint-disable @typescript-eslint/no-explicit-any */

import { AddressLike, BaseContract, Signer, TransactionReceipt, TransactionResponse, resolveAddress } from "ethers";
import { ethers } from "hardhat";
import { logger } from "../logger";
import { GAS_PRICE } from "./constants";
import { deploymentState, isResumeableDeployment } from "./deployment_state";
import { prepareVerificationData } from "./verification";

type DeploymentResult = {
    address: AddressLike; 
    deploymentTransaction: TransactionResponse | null;
    deploymentReceipt: TransactionReceipt | null;
    contract: BaseContract | null;
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

        return { address, deploymentTransaction, contract, deploymentReceipt: null };
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
    constructorArgs !== undefined
        ? await prepareVerificationData(contractName, address, constructorArgs, sourceFileContract)
        : await prepareVerificationData(contractName, address, [], sourceFileContract);
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

    return { address, deploymentTransaction, contract, deploymentReceipt: receipt };
}