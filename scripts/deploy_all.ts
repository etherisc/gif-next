import { deployFireComponentContracts } from "./deploy_fire_components";
import { deployFlightDelayComponentContracts } from "./deploy_flightdelay_components";
import { deployGifContracts } from "./deploy_gif";
import { getNamedAccounts } from "./libs/accounts";
import { loadVerificationQueueState } from "./libs/verification_queue";
import { logger } from "./logger";


async function main() {
    const { protocolOwner, masterInstanceOwner, instanceOwner, productOwner: fireOwner } = await getNamedAccounts();
    loadVerificationQueueState();
    
    const {services, libraries } = await deployGifContracts(protocolOwner, instanceOwner);
    await deployFireComponentContracts(libraries, services, fireOwner, protocolOwner);

    await deployFlightDelayComponentContracts(libraries, services, fireOwner, protocolOwner);
}

if (require.main === module) {
    main().catch((error) => {
        logger.error(error.stack);
        process.exitCode = 1;
    });
}
