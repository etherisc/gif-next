import { Signer } from "ethers";
import { FirePool, FireProduct, FireUSD, IApplicationService__factory, IBundleService__factory } from "../typechain-types";
import { deployFireComponentContracts } from "./deploy_fire_components";
import { deployFlightDelayComponentContracts } from "./deploy_flightdelay_components";
import { deployGifContracts } from "./deploy_gif";
import { getNamedAccounts } from "./libs/accounts";
import { executeTx, getFieldFromLogs } from "./libs/transaction";
import { loadVerificationQueueState } from "./libs/verification_queue";
import { logger } from "./logger";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";


async function main() {
    const { protocolOwner, instanceOwner, productOwner: fireOwner, investor, customer } = await getNamedAccounts();
    loadVerificationQueueState();
    
    const {services, libraries } = await deployGifContracts(protocolOwner, instanceOwner);
    const { instance, fireUsd, fireProduct, firePool } = await deployFireComponentContracts(libraries, services, fireOwner, protocolOwner);

    await createBundleAndPolicy(fireOwner, investor, customer, fireUsd, fireProduct, firePool);
}

async function createBundleAndPolicy(fireOwner: Signer, investor: Signer, customer: Signer, fireUsd: FireUSD, fireProduct: FireProduct, firePool: FirePool): Promise<void> {
    const bundleAmount = 10000 * 10 ** 6;
    const sumInsured = 1000 * 10 ** 6;
    const cityName = "London";

    const fireUSDI = fireUsd.connect(investor);
    const firePoolI = firePool.connect(investor);
    const fireProductC = fireProduct.connect(customer);
    
    // 0. Prepare accounts
    await executeTx(async () => 
        await fireUsd.transfer(investor, bundleAmount), 
        "o - transfer bundle amount to investor");
    await executeTx(async () =>
        await fireUsd.transfer(customer, sumInsured),
        "o - transfer sum insured to customer");

    // 1. investor approves bundle amount to firePool tokenhandler
    const firePoolTokenHandler = await firePoolI.getTokenHandler();
    await executeTx(async () => 
        await fireUSDI.approve(firePoolTokenHandler, bundleAmount),
        "i - approve firePool token handler");
    logger.info("Approved firePool token handler");

    // 2. investor creates bundle
    const createBundleTx = await executeTx(async () => 
        await firePoolI.createBundle({ fixedFee: 0, fractionalFee: 0}, bundleAmount, 60 * 24 * 60 * 60), 
    "i - create bundle");

    const bundleNFtId = getFieldFromLogs(createBundleTx.logs, IBundleService__factory.createInterface(), "LogBundleServiceBundleCreated", "bundleNftId") as string;
    logger.info(`Bundle created. NFT ID: ${bundleNFtId}`);

    // 3. fireOwner creates city
    await executeTx(async () =>
        await fireProduct.initializeCity(cityName),
        "o - initialize city");

    // 4. customer approves policy amount to fireProduct token handler
    const fireProductTokenHandler = await fireProductC.getTokenHandler();
    await executeTx(async () =>
        // approve full sum insured for simplicity
        await fireUSDI.approve(fireProductTokenHandler, sumInsured),
        "c - approve fireProduct token handler");

    // 5. customer creates policy
    const createPolicyTx = await executeTx(async () =>
        await fireProductC.createApplication(cityName, sumInsured, 30 * 24 * 60 * 60, bundleNFtId),
        "c - create policy");
    const policyNftId = getFieldFromLogs(createPolicyTx.logs, IApplicationService__factory.createInterface(), "LogApplicationServiceApplicationCreated", "applicationNftId") as string;
    logger.info(`Application created. NFT ID: ${policyNftId}`);

    // 6. fireOwner underwrites policy
    await executeTx(async () =>
        await fireProduct.createPolicy(policyNftId, Math.round((Date.now() / 1000) + 60 * 60)),
        "o - create policy");

    // TODO: 7. report fire

    // TODO: 8. customer claims
}

if (require.main === module) {
    main().catch((error) => {
        logger.error(error.stack);
        process.exitCode = 1;
    });
}
