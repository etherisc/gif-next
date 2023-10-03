import { IncrementRevert } from "../../../typechain-types";
import { getNamedAccounts } from "../../libs/accounts";
import { deployContract } from "../../libs/deployment";
import { executeTx } from "../../libs/transaction";
import { logger } from "../../logger";

async function main() {
    const { protocolOwner: owner } = await getNamedAccounts();

    const { contract } = await deployContract(
        "IncrementRevert",
        owner,
        [5]);

    const inc = contract as IncrementRevert;
    const tx1 = await executeTx(async () => await inc["increment()"]())
    logger.info(`tx1: ${tx1.hash}`);
    
    const tx2  = await executeTx(async () => await inc["increment(uint256)"](3))
    logger.info(`tx2: ${tx2.hash}`);

    const tx3 = await executeTx(async () => await inc["increment()"]())
    logger.info(`tx3: ${tx3.hash}`);
}

main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});


