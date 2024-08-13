import { FirePool, FireProduct, FireProduct__factory, IInstance__factory, IInstanceService__factory } from "../typechain-types";
import { getNamedAccounts } from "./libs/accounts";
import { deployContract } from "./libs/deployment";
import { executeTx, getFieldFromLogs, getTxOpts } from "./libs/transaction";
import { loadVerificationQueueState } from './libs/verification_queue';
import { logger } from "./logger";

async function main() {
    logger.info("deploying components ...");
    loadVerificationQueueState();

    const { productOwner: fireOwner } = await getNamedAccounts();

    const amountLibAddress = process.env.AMOUNTLIB_ADDRESS;
    const feeLibAddress = process.env.FEELIB_ADDRESS;
    const nftIdLibAddress = process.env.NFTIDLIB_ADDRESS;
    const referralLibAddress = process.env.REFERRALLIB_ADDRESS;
    const riskIdLibAddress = process.env.RISKIDLIB_ADDRESS;
    const roleIdLibAddress = process.env.ROLEIDLIB_ADDRESS;
    const secondsLibAddress = process.env.SECONDSLIB_ADDRESS;
    const selectorLibAddress = process.env.SELECTORLIB_ADDRESS;
    const strLibAddress = process.env.STRLIB_ADDRESS;
    const timestampLibAddress = process.env.TIMESTAMPLIB_ADDRESS;
    const ufixedLibAddress = process.env.UFIXEDLIB_ADDRESS;
    const versionPartLibAddress = process.env.VERSIONPARTLIB_ADDRESS;
        
    const instanceServiceAddress = process.env.INSTANCE_SERVICE_ADDRESS;

    // logger.debug(`instanceServiceAddress: ${instanceServiceAddress}`);
    const instanceService = IInstanceService__factory.connect(instanceServiceAddress!, fireOwner);

    console.log("create new instance");
    const instanceCreateTx = await executeTx(async () => 
        await instanceService.createInstance(getTxOpts()),
        "fire ex - createInstance",
        [IInstanceService__factory.createInterface()]
    );

    const instanceAddress = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceCloned", "instance") as string;
    const instanceNftId = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceCloned", "instanceNftId") as string;
    const instance = IInstance__factory.connect(instanceAddress, fireOwner);
    logger.info(`Instance created at ${instanceAddress} with NFT ID ${instanceNftId}`);

    const { address: fireUsdAddress } = await deployContract(
        "FireUSD",
        fireOwner);
    
    const deploymentId = Math.random().toString(16).substring(7);
    const fireProductName = "FireProduct_" + deploymentId;
    const { address: fireProductAuthAddress } = await deployContract(
        "FireProductAuthorization",
        fireOwner,
        [fireProductName],
        {
            libraries: {
                RoleIdLib: roleIdLibAddress,
                SelectorLib: selectorLibAddress,
                StrLib: strLibAddress,
                TimestampLib: timestampLibAddress,
                VersionPartLib: versionPartLibAddress,
            }
        },
        "contracts/examples/fire/FireProductAuthorization.sol:FireProductAuthorization");

    const { address: fireProductAddress, contract: fireProductBaseContract } = await deployContract(
        "FireProduct",
        fireOwner,
        [
            await instance.getRegistry(),
            instanceNftId,
            fireProductName,
            fireUsdAddress,
            fireProductAuthAddress,
        ],
        {
            libraries: {
                AmountLib: amountLibAddress,
                FeeLib: feeLibAddress,
                NftIdLib: nftIdLibAddress,
                ReferralLib: referralLibAddress,
                RiskIdLib: riskIdLibAddress,
                SecondsLib: secondsLibAddress,
                TimestampLib: timestampLibAddress,
                UFixedLib: ufixedLibAddress,
                VersionPartLib: versionPartLibAddress,
            }
        });
    const fireProduct = fireProductBaseContract as FireProduct;

    logger.info(`registering FireProduct on Instance`);
    await executeTx(async () => 
        await instance.registerProduct(fireProductAddress, getTxOpts()),
        "fire ex - registerProduct",
        [IInstance__factory.createInterface()]
    );
    const fireProductNftId = await fireProduct.getNftId();

    const firePoolName = "FirePool_" + deploymentId;
    const { address: firePoolAuthAddress } = await deployContract(
        "FirePoolAuthorization",
        fireOwner,
        [firePoolName],
        {
            libraries: {
                RoleIdLib: roleIdLibAddress,
                SelectorLib: selectorLibAddress,
                StrLib: strLibAddress,
                TimestampLib: timestampLibAddress,
                VersionPartLib: versionPartLibAddress,
            }
        },
        "contracts/examples/fire/FirePoolAuthorization.sol:FirePoolAuthorization");

    const { address: firePoolAddress, contract: firePoolBaseContract } = await deployContract(
        "FirePool",
        fireOwner,
        [
            await instance.getRegistry(),
            fireProductNftId,
            firePoolName,
            fireUsdAddress,
            firePoolAuthAddress,
        ],
        {
            libraries: {
                AmountLib: amountLibAddress,
                NftIdLib: nftIdLibAddress,
                RoleIdLib: roleIdLibAddress,
                UFixedLib: ufixedLibAddress,
                VersionPartLib: versionPartLibAddress,
            }
        });
    const firePool = firePoolBaseContract as FirePool;
    
    logger.info(`registering FirePool on FireProduct`);
    await executeTx(async () => 
        await fireProduct.registerComponent(firePoolAddress, getTxOpts()),
        "fire ex - registerComponent",
        [FireProduct__factory.createInterface()]
    );
    const firePoolNftId = await firePool.getNftId();

    logger.info(`FireUSD deployed at ${fireUsdAddress}`);
    logger.info(`FirePool registered at ${firePoolAddress} with NFT ID ${firePoolNftId}`);
    logger.info(`FireProduct registered at ${fireProductAddress} with NFT ID ${fireProductNftId}`);
}


main().catch((error) => {
    logger.error(error.stack);
    logger.error(error.data);
    process.exit(1);
});