import { Interface, TransactionReceipt, ethers } from "ethers";
import { ethers as hhEthers } from "hardhat";
import { logger } from "../logger";
import { GAS_PRICE } from "./constants";
import { deploymentState, isResumeableDeployment } from "./deployment_state";
import { ErrorDecoder } from "ethers-decode-error";

/**
 * Extract a field from the logs of a transaction. 
 */
export function getFieldFromTxRcptLogs(tx: TransactionReceipt, abiInterface: Interface, eventName: string, fieldName: string): unknown | null {
    const logs = tx?.logs;
    if (logs === undefined) {
        return null;
    }
    return getFieldFromLogs(logs, abiInterface, eventName, fieldName);
}

export function getFieldFromLogs(logs: readonly ethers.Log[], abiInterface: Interface, eventName: string, fieldName: string): unknown | null {
    let value: unknown | null = null;
    
    logs?.forEach(log => {
        const parsedLog = abiInterface.parseLog({ data: log.data, topics: log.topics as string[] });
        // logger.debug(`parsedLog.name: ${parsedLog?.name} ${parsedLog?.args}`);
        if (parsedLog?.name === eventName) {
            // destructuring assignment to fetch the value of the field `fieldName` from the object `p.args`
            const { [fieldName]: v } = parsedLog.args;
            value = v;
            // logger.debug(`${eventName}: ${value}`);
        }
    });

    return value;
}


/**
 * Execute a transaction and wait for it to be mined. Then check if the transaction was successful. 
 * @throws TransactionFailedException if the transaction failed
 */ 
export async function executeTx(
    txFunc: () => Promise<ethers.ContractTransactionResponse>, 
    txId: string|null = null,
    errorInterfaces?: Interface[]
): Promise<ethers.TransactionReceipt> {
    if (txId !== null) {
        logger.info(`executing tx with id: ${txId}`);
    }

    // if the deployment is resumable and the transaction id is not null, check if the transaction was already mined or if not, then wait for it to be mined
    if (isResumeableDeployment && txId !== null) {
        if (deploymentState.hasTransactionId(txId)) {
            const txHash = deploymentState.getTransactionHash(txId);
            const transaction = await hhEthers.provider.getTransaction(txHash)!;
            if (transaction === null) {
                throw new Error(`Transaction not found: ${txHash}`);
            }
            logger.info(`Resuming transaction: ${txHash}`);
            const tx = await transaction.wait();
            const rcpt = (await hhEthers.provider.getTransactionReceipt(transaction.hash))!;
            if (tx === null) {
                throw new TransactionFailedException(null);
            }
            logger.debug(`tx mined: ${tx.hash} status: ${tx.status}`)
            if (tx.status !== 1) {
                throw new TransactionFailedException(null);
            }
            return rcpt;
        }
    }

    // call the transaction function and wait for the tx to finish. then check if the tx was successful
    try {
        const txResp = await txFunc();
        if (isResumeableDeployment && txId !== null) {
            deploymentState.setTransactionId(txId!, txResp.hash);
        }
        const tx = await txResp.wait();
        logger.debug(`tx mined. hash: ${tx?.hash} status: ${tx?.status}`);
        if (tx === null) {
            throw new TransactionFailedException(null);
        }
        if (tx?.status !== 1) {
            throw new TransactionFailedException(tx);
        }
        return tx;
    } catch (err) {
        // if an error occurred, decode the error and log the reason and args
        if (errorInterfaces !== undefined && errorInterfaces.length > 0) {
            const errorDecoder = ErrorDecoder.create(errorInterfaces);
            const decodedError = await errorDecoder.decode(err);
            logger.error(`Decoded error reason: ${decodedError.reason}`);
            logger.error(`Decoded error args: ${decodedError.args}`);
        }
        throw err;
    }

}

/**
 * Exception thrown when a transaction fails. Contains the transaction receipt in field `transaction`.
 */
export class TransactionFailedException extends Error {
    transaction: ethers.ContractTransactionReceipt | null;

    constructor(tx: ethers.ContractTransactionReceipt| null) {
        super(`Transaction failed: ${tx?.hash}`);
        this.transaction = tx;
    }
}

export function getTxOpts() {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const opts = {} as any;
    if (GAS_PRICE !== undefined) {
        opts['gasPrice'] = GAS_PRICE;
    }

    return opts;
}