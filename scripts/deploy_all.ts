import { deployFireComponentContracts } from "./deploy_fire_components";
import { deployGifContracts } from "./deploy_gif";
import { getNamedAccounts } from "./libs/accounts";
import { loadVerificationQueueState } from "./libs/verification_queue";
import { logger } from "./logger";


async function main() {
    const { protocolOwner, masterInstanceOwner, instanceOwner, productOwner: fireOwner } = await getNamedAccounts();
    loadVerificationQueueState();
    
    const {services, libraries } = await deployGifContracts(protocolOwner, masterInstanceOwner, instanceOwner);
    await deployFireComponentContracts(libraries, services, fireOwner);
}

if (require.main === module) {
    main().catch((error) => {
        logger.error(error.stack);
        process.exitCode = 1;
    });
}
