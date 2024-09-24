import { resolveAddress, Signer } from "ethers";
import { FirePool, FireProduct, FireProduct__factory, AccessAdmin__factory, IInstance__factory, IInstanceService__factory, IRegistry__factory, TokenRegistry__factory, Dip } from "../typechain-types";
import { getNamedAccounts } from "./libs/accounts";
import { deployContract } from "./libs/deployment";
import { LibraryAddresses } from "./libs/libraries";
import { ServiceAddresses } from "./libs/services";
import { executeTx, getFieldFromLogs, getTxOpts } from "./libs/transaction";
import { loadVerificationQueueState } from './libs/verification_queue';
import { logger } from "./logger";

async function main() {
    loadVerificationQueueState();
    const { protocolOwner } = await getNamedAccounts();

    const { address: dipAddress, contract: dipBaseContract } = await deployContract(
        "Dip",
        protocolOwner, // GIF_ADMIN_ROLE
        [], 
        {
            libraries: {
            }
        });

    const dip = dipBaseContract as Dip;

    logger.info(`===== DIP deployed at ${dipAddress}`);
}

if (require.main === module) {
    main().catch((error) => {
        logger.error(error.stack);
        logger.error(error.data);
        process.exit(1);
    });
}
