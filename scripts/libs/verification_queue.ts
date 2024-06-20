// eslint-disable-next-line @typescript-eslint/no-explicit-any
import * as fs from 'fs';
import hre from 'hardhat';
import { logger } from '../logger';

const VERIFICATION_QUEUE_FILENAME = "verification_queue";
const VERIFICATION_QUEUE_FILENAME_SUFFIX = ".json";


// eslint-disable-next-line @typescript-eslint/no-explicit-any
let VERIFICATION_DATA_STATE = [] as any[];

/** Saves the verification data for a contract in the queue and persists the queue to the file system */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function saveVerificationData(args: any) {
    if (args.contractName !== undefined) {
        // check if not in data
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        if (VERIFICATION_DATA_STATE.find((e: any) => e.contractName === args.contractName) !== undefined) {
            logger.debug(`Contract ${args.contractName} already in verification queue`);
            return;
        }
    }
    VERIFICATION_DATA_STATE.push(args);
    persistState();
    logger.debug("Contract verification data saved");
}

function persistState() {
    const json = JSON.stringify(VERIFICATION_DATA_STATE);
    fs.writeFileSync(verificationQueueFilename(), json);
}

export function loadVerificationQueueState() {
    if (! fs.existsSync(verificationQueueFilename())) {
        return;
    }
    const filename = verificationQueueFilename();
    const json = fs.readFileSync(filename, 'utf8');
    VERIFICATION_DATA_STATE = JSON.parse(json);
}

export function verificationQueueFilename(): string {
    return VERIFICATION_QUEUE_FILENAME + "_" + hre.network.config.chainId + VERIFICATION_QUEUE_FILENAME_SUFFIX;
}
