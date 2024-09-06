import { AddressLike, Signer, resolveAddress } from "ethers";
import { IRegistry__factory, InstanceService__factory } from "../typechain-types";
import { getNamedAccounts, printBalance } from "./libs/accounts";
import { InstanceAddresses } from "./libs/instance";
import { executeTx, getTxOpts, getFieldFromLogs } from "./libs/transaction";
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

export async function cloneInstanceFromRegistry(registryAddress: AddressLike, instanceOwner: Signer): Promise<InstanceAddresses> {
    const registry = IRegistry__factory.connect(await resolveAddress(registryAddress), instanceOwner);
    const instanceServiceAddress = await registry.getServiceAddress(10, 3); // ObjectType = Instance (10) and majorVersion = 3 
    const instanceServiceAsClonedInstanceOwner = InstanceService__factory.connect(await resolveAddress(instanceServiceAddress), instanceOwner);
    logger.info(`instanceServiceAddress: ${instanceServiceAddress}`);
    logger.info(`Creating new instance ...`);
    const cloneTx = await executeTx(
        async () => await instanceServiceAsClonedInstanceOwner.createInstance(getTxOpts())
    );
    const clonedInstanceAddress = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceServiceInstanceCreated", "instance");
    const clonedInstanceNftId = getFieldFromLogs(cloneTx.logs, instanceServiceAsClonedInstanceOwner.interface, "LogInstanceServiceInstanceCreated", "instanceNftId");
    
    logger.info(`instanceNftId: ${clonedInstanceNftId} instanceAddress: ${clonedInstanceAddress}`);
    
    return {
        instanceAddress: clonedInstanceAddress,
        instanceNftId: clonedInstanceNftId as string,
    } as InstanceAddresses;
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


