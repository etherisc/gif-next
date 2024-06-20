import { AddressLike, resolveAddress } from "ethers";
import { logger } from "../logger";
import hre from "hardhat";
import { delay } from "./deployment";
import { LIBRARY_ADDRESSES } from "./libraries";
import { saveVerificationData } from "./verification_queue";

/**
 * Prepares the data required for verifying a contract on Etherscan and stores it to the verification queue file. 
 * @param sourceFileContract the contract name prefixed with file path (e.g. "contracts/types/ObjectType.sol:ObjectTypeLib")
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function prepareVerificationData(contractName: string, address: AddressLike, constructorArgs: any[], sourceFileContract: string | undefined) {
    const args = {
        contractName: contractName,
        address: address,
        constructorArguments: constructorArgs,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } as any;
    if (sourceFileContract !== undefined) {
        args['contract'] = sourceFileContract;
    }
    saveVerificationData(args);
}

/**
 * Verify a smart contract on Etherscan using hardhat-etherscan task "verify". 
 * In case of "does not have bytecode" error, retry after 5s for 3 times in a row. 
 * In case of "MissingLibrariesError", fetch library addresses from LIBRARY_ADDRESSES and retry.
 * @param sourceFileContract the contract name prefixed with file path (e.g. "contracts/types/ObjectType.sol:ObjectTypeLib")
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function verifyContract(address: AddressLike, constructorArgs: any[], sourceFileContract: string | undefined) {
    let verified = false;
    let retries = 3;
    const libraries: Record<string,string> = {};
    let error = undefined;
    while (! verified && retries > 0) {
        retries--;
        logger.debug("verifying contract @ address: " + address);
        try {
            const args = {
                address: address,
                constructorArguments: constructorArgs,
                libraries: libraries,
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            } as any;
            if (sourceFileContract !== undefined) {
                args['contract'] = sourceFileContract;
            }
            await hre.run("verify:verify", args);
            logger.info("Contract verified");
            verified = true;
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        } catch (err: any) {
            error = err;
            
            if (err.message.toLowerCase().includes("already verified")) {
                logger.info("Contract is already verified!");
                verified = true;
            } else if (err.message.toLowerCase().includes("does not have bytecode")) {
                logger.info("Bytecode not yet available on Etherscan, retrying in 5s...");
                await delay(5000);
            } else if (err.name === "MissingLibrariesError") { // ethers does not export error - match by name
                logger.debug("caught MissingLibrariesError - fetching library addresses and retry");
                if (retries > 0) retries = 1; // one more retry
                /* 
                 * Extract missing libraries from error message. Error message looks like:
                 *
                 * error: MissingLibrariesError: The contract contracts/instance/Instance.sol:Instance has one or more library addresses that cannot be detected from deployed bytecode.
                 * This can occur if the library is only called in the contract constructor. The missing libraries are:
                 *   * contracts/types/Key32.sol:Key32Lib
                 *   * contracts/types/ObjectType.sol:ObjectTypeLib
                 *   * contracts/types/StateId.sol:StateIdLib
                 */
                const missingLibraries: string[] = err.message.split("\n")
                    .filter((line: string) => line.startsWith("  * "))
                    .map((line: string) => line.split(":").pop()!);
                missingLibraries.forEach(async (lib: string) => {
                    const address = LIBRARY_ADDRESSES.get(lib);
                    if (address === undefined) {
                        throw new Error(`Library address for ${lib} not found`);
                    }
                    libraries[lib] = await resolveAddress(address);
                });
                logger.info("retrying verification with missing libraries: " + JSON.stringify(libraries));
            } else {
                retries = 0; // no retries
            }
        }
    }

    if (! verified && error !== undefined) {
        throw error;
    }
}
