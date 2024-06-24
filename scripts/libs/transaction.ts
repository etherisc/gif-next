import { Interface, TransactionReceipt, ethers } from "ethers";
import { ethers as hhEthers } from "hardhat";
import { logger } from "../logger";
import { GAS_PRICE } from "./constants";
import { deploymentState, isResumeableDeployment } from "./deployment_state";

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
): Promise<ethers.TransactionReceipt> {
    if (txId !== null) {
        logger.info(`executing tx with id: ${txId}`);
    }

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

    const txResp = await txFunc();
    if (txId !== null) {
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