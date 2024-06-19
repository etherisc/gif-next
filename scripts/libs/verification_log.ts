import hre from "hardhat";
import fs from "fs";

const VERIFICATION_LOG = [] as string[];

const VERIFICATION_LOG_FILENAME = "verification_log";
const VERIFICATION_LOG_FILENAME_SUFFIX = ".json";

export function verificationQueueFilename(): string {
    return VERIFICATION_LOG_FILENAME + "_" + hre.network.config.chainId + VERIFICATION_LOG_FILENAME_SUFFIX;
}

export function persistLog() {
    const json = JSON.stringify(VERIFICATION_LOG);
    fs.writeFileSync(verificationQueueFilename(), json);
}

export function addVerifiedContract(address: string) {
    VERIFICATION_LOG.push(address);
    persistLog();
}

export function isContractVerified(address: string): boolean {
    return VERIFICATION_LOG.includes(address);
}

export function loadVerifiedContractsLogFromFile() {
    const filename = verificationQueueFilename();
    if (fs.existsSync(verificationQueueFilename())) {
        const json = fs.readFileSync(filename, 'utf8');
        const log = JSON.parse(json);
        VERIFICATION_LOG.push(...log);
    }
}
