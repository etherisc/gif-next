import { getNamedAccounts } from "./lib/accounts";
import { logger } from "./logger";

async function main() {
    await getNamedAccounts();
}

main().catch((error) => {
    logger.error(error.message);
    process.exitCode = 1;
});
