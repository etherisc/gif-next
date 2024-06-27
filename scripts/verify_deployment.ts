import fs from "fs";
import hre from "hardhat";
import { loadLibraryAddressesFromFile } from "./libs/libraries";
import { verifyContract } from "./libs/verification";
import { addVerifiedContract, isContractVerified, loadVerifiedContractsLogFromFile } from "./libs/verification_log";
import { verificationQueueFilename } from "./libs/verification_queue";
import { logger } from "./logger";
import { deploymentsBaseDirectory } from "./libs/deployment_state";

async function main() {
    const chainId = hre.network.config.chainId;
    logger.info(`Verifying deployment on chain ${chainId} ...`);

    // read the verification queue file
    const filename = deploymentsBaseDirectory() + verificationQueueFilename();
    const json = fs.readFileSync(filename, 'utf8');
    const verificationData = JSON.parse(json);
    loadLibraryAddressesFromFile();
    loadVerifiedContractsLogFromFile();
    
    for (const data of verificationData) {
        logger.info(`Verifying contract ${data.contractName} at address ${data.address} with constructor arguments ${data.constructorArguments} ...`);
        if (isContractVerified(data.address)) {
            logger.info(`Contract ${data.address} already verified`);
            continue;
        }
        await verifyContract(data.address, data.constructorArguments, data.contract);
        addVerifiedContract(data.address);
    }
}

main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});
