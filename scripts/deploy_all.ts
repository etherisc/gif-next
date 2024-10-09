import { deployFireComponentContracts } from "./deploy_fire_components";
import { deployFlightDelayComponentContracts } from "./deploy_flightdelay_components";
import { deployGifContracts } from "./deploy_gif";
import { createFireBundleAndPolicy } from "./deploy_gif_and_fire_and_create_policy";
import { getNamedAccounts } from "./libs/accounts";
import { loadVerificationQueueState } from "./libs/verification_queue";
import { logger } from "./logger";

/**
 * - Deploys all contracts for gif
 * - Deploys all contracts for fire 
 * - Creates a fire bundle and policy
 * - Deploys all contracts for flight delay
 */
async function main() {
    const { protocolOwner, masterInstanceOwner, instanceOwner, productOwner: fireOwner, investor, customer, tokenIssuer, libraryDeployer } = await getNamedAccounts();
    loadVerificationQueueState();
    
    const {services, libraries } = await deployGifContracts(protocolOwner, instanceOwner, tokenIssuer, libraryDeployer);

    const { fireUsd, fireProduct, firePool } = await deployFireComponentContracts(libraries, services, fireOwner, protocolOwner);
    await createFireBundleAndPolicy(fireOwner, investor, customer, fireUsd, fireProduct, firePool);

    await deployFlightDelayComponentContracts(libraries, services, fireOwner, protocolOwner);
}

if (require.main === module) {
    main().catch((error) => {
        logger.error(error.stack);
        process.exitCode = 1;
    });
}
