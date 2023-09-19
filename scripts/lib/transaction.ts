import { ContractTransactionReceipt, Interface, ethers } from "ethers";
import { logger } from "../logger";

/**
 * 
 * @param tx 
 */
export function getFieldFromLogs(tx: ContractTransactionReceipt, abiInterface: Interface, eventName: string, fieldName: string): any | null {
    const logs = tx?.logs;
    let value: any | null = null;
    
    logs?.forEach(log => {
        const parsedLog = abiInterface.parseLog({ data: log.data, topics: log.topics as string[] });
        // logger.debug(`parsedLog.name: ${parsedLog?.name}`);
        if (parsedLog?.name === eventName) {
            // destructuring assignment to fetch the value of the field `fieldName` from the object `p.args`
            const { [fieldName]: v } = parsedLog.args;
            value = v;
            // logger.debug(`${eventName}: ${value}`);
        }
    });

    return value;
}
