import { getNamedAccounts, printBalance } from "./libs/accounts";
import { InstanceAddresses, cloneInstanceFromRegistry } from "./libs/instance";
import { logger } from "./logger";


async function main() {
    logger.info("creating new instance ...")
    const { instanceOwner } = await getNamedAccounts();
    const registryAddress = process.env.REGISTRY_ADDRESS;
    logger.info(`registryAddress: ${registryAddress}`);
    
    // // deploy instance contracts
    const clonedInstance = await cloneInstanceFromRegistry(registryAddress!, instanceOwner);
    
    printInstanceAddress(clonedInstance);

    // print final balance
    await printBalance(
        ["instanceOwner", instanceOwner],
        );
}


function printInstanceAddress(
    clonedInstance: InstanceAddresses,
) {
    let addresses = "\nAddresses of new instance smart contracts:\n==========\n";
    
    addresses += `--------\n`;
    addresses += `clonedInstanceAddress: ${clonedInstance.instanceAddress}\n`;
    addresses += `clonedInstanceNftId: ${clonedInstance.instanceNftId}\n`;
    addresses += `--------\n`;  
    
    logger.info(addresses);
}


main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});


