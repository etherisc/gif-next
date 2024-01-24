import { Interface, TransactionReceipt, ethers } from "ethers";

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
export async function executeTx(txFunc: () => Promise<ethers.ContractTransactionResponse>): Promise<ethers.ContractTransactionReceipt> {
    const txResp = await txFunc();
    const tx = await txResp.wait();
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

