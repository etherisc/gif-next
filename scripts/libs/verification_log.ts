import hre from "hardhat";
import fs from "fs";
import { deploymentsBaseDirectory, mkdirDeploymentsBaseDirectory } from "./deployment_state";

const VERIFICATION_LOG = [] as string[];

const VERIFICATION_LOG_FILENAME = "verification_log";
const VERIFICATION_LOG_FILENAME_SUFFIX = ".json";

export function verificationQueueFilename(): string {
    return VERIFICATION_LOG_FILENAME + "_" + hre.network.config.chainId + VERIFICATION_LOG_FILENAME_SUFFIX;
}

export function persistLog() {
    mkdirDeploymentsBaseDirectory();
    const json = JSON.stringify(VERIFICATION_LOG);
    fs.writeFileSync(deploymentsBaseDirectory() + verificationQueueFilename(), json);
}

export function addVerifiedContract(address: string) {
    VERIFICATION_LOG.push(address);
    persistLog();
}

export function isContractVerified(address: string): boolean {
    return VERIFICATION_LOG.includes(address);
}

export function loadVerifiedContractsLogFromFile() {
    const filename = deploymentsBaseDirectory() + verificationQueueFilename();
    if (fs.existsSync(deploymentsBaseDirectory() + verificationQueueFilename())) {
        const json = fs.readFileSync(filename, 'utf8');
        const log = JSON.parse(json);
        VERIFICATION_LOG.push(...log);
    }
}
