// eslint-disable-next-line @typescript-eslint/no-explicit-any
import * as fs from 'fs';
import hre from 'hardhat';
import { logger } from '../logger';

const VERIFICATION_QUEUE_FILENAME = "verification_queue";
const VERIFICATION_QUEUE_FILENAME_SUFFIX = ".json";


// eslint-disable-next-line @typescript-eslint/no-explicit-any
const VERIFICATION_DATA_STATE = [] as any[];

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function saveVerificationData(args: any) {
    VERIFICATION_DATA_STATE.push(args);
    persistState();
    logger.debug("Contract verification data saved");
}


function persistState() {
    const json = JSON.stringify(VERIFICATION_DATA_STATE);
    fs.writeFileSync(verificationQueueFilename(), json);
}

export function verificationQueueFilename(): string {
    return VERIFICATION_QUEUE_FILENAME + "_" + hre.network.config.chainId + VERIFICATION_QUEUE_FILENAME_SUFFIX;
}
