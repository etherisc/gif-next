import { DecodedError, ErrorDecoder } from 'ethers-decode-error';
import { AccessManaged__factory, AccessManagedUpgradeable__factory, BasicPool__factory, FirePool, FirePool__factory, FireProduct, FireProduct__factory, IAccessManaged__factory, IComponent__factory, IComponentService__factory, IInstance__factory, IInstanceLinkedComponent__factory, IInstanceService__factory, INftOwnable__factory, InstanceAdmin__factory, IPoolComponent__factory, IRegisterable__factory, IRegistry__factory, IRegistryService__factory, Pool__factory, RegistryAdmin__factory } from "../typechain-types";
import { getNamedAccounts } from "./libs/accounts";
import { deployContract } from "./libs/deployment";
import { executeTx, getFieldFromLogs } from "./libs/transaction";
import { logger } from "./logger";

async function main() {
    logger.info("deploying components ...");
    const errorDecoder = ErrorDecoder.create([
        FirePool__factory.createInterface(),
        FireProduct__factory.createInterface(),
        BasicPool__factory.createInterface(),
        Pool__factory.createInterface(),
        IPoolComponent__factory.createInterface(),
        IInstanceLinkedComponent__factory.createInterface(),
        IComponentService__factory.createInterface(),
        IComponent__factory.createInterface(),
        IRegistry__factory.createInterface(),
        IRegistryService__factory.createInterface(),
        IRegisterable__factory.createInterface(),
        INftOwnable__factory.createInterface(),
        AccessManaged__factory.createInterface(),
        IAccessManaged__factory.createInterface(),
        AccessManagedUpgradeable__factory.createInterface(),
        InstanceAdmin__factory.createInterface(),
        RegistryAdmin__factory.createInterface(),
    ]);

    const { instanceOwner } = await getNamedAccounts();

    const amountLibAddress = process.env.AMOUNTLIB_ADDRESS;
    const feeLibAddress = process.env.FEELIB_ADDRESS;
    const nftIdLibAddress = process.env.NFTIDLIB_ADDRESS;
    const referralLibAddress = process.env.REFERRALLIB_ADDRESS;
    const objectTypeLibAddress = process.env.OBJECTTYPELIB_ADDRESS;
    const riskIdLibAddress = process.env.RISKIDLIB_ADDRESS;
    const roleIdLibAddress = process.env.ROLEIDLIB_ADDRESS;
    const secondsLibAddress = process.env.SECONDSLIB_ADDRESS;
    const selectorLibAddress = process.env.SELECTORLIB_ADDRESS;
    const strLibAddress = process.env.STRLIB_ADDRESS;
    const timestampLibAddress = process.env.TIMESTAMPLIB_ADDRESS;
    const ufixedLibAddress = process.env.UFIXEDLIB_ADDRESS;
    const versionPartLibAddress = process.env.VERSIONPARTLIB_ADDRESS
        
    const instanceServiceAddress = process.env.INSTANCE_SERVICE_ADDRESS;

    // logger.debug(`instanceServiceAddress: ${instanceServiceAddress}`);
    const instanceService = IInstanceService__factory.connect(instanceServiceAddress!, instanceOwner);

    console.log("create new instance");
    const instanceCreateTx = await executeTx(async () => 
        await instanceService.createInstance()
    );

    const instanceAddress = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceCloned", "instance") as string;
    const instanceNftId = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceCloned", "instanceNftId") as string;
    const instance = IInstance__factory.connect(instanceAddress, instanceOwner);
    logger.info(`Instance created at ${instanceAddress} with NFT ID ${instanceNftId}`);

    const { address: fireUsdAddress } = await deployContract(
        "FireUSD",
        instanceOwner);
    
    const firePoolName = "FirePool_" + Math.random().toString(16).substring(7);
    const { address: firePoolAuthAddress } = await deployContract(
        "FirePoolAuthorization",
        instanceOwner,
        [firePoolName],
        {
            libraries: {
                RoleIdLib: roleIdLibAddress,
                SelectorLib: selectorLibAddress,
                StrLib: strLibAddress,
                TimestampLib: timestampLibAddress,
                VersionPartLib: versionPartLibAddress,
            }
        });

    const { address: firePoolAddress, contract: firePoolBaseContract } = await deployContract(
        "FirePool",
        instanceOwner,
        [
            await instance.getRegistry(),
            instanceNftId,
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
            }
        });
    const firePool = firePoolBaseContract as FirePool;
    try {
        await executeTx(async () => await firePool.register());
    } catch (err) {
        const decodedError: DecodedError = await errorDecoder.decode(err)
        logger.error(decodedError.reason);
        logger.error(decodedError.args);
        throw err;
    }
    const firePoolNftId = await firePool.getNftId();

    const fireProductName = "FireProduct_" + Math.random().toString(16).substring(7);
    const { address: fireProductAuthAddress } = await deployContract(
        "FireProductAuthorization",
        instanceOwner,
        [fireProductName],
        {
            libraries: {
                RoleIdLib: roleIdLibAddress,
                SelectorLib: selectorLibAddress,
                StrLib: strLibAddress,
                TimestampLib: timestampLibAddress,
                VersionPartLib: versionPartLibAddress,
            }
        });

    const { address: fireProductAddress, contract: fireProductBaseContract } = await deployContract(
        "FireProduct",
        instanceOwner,
        [
            await instance.getRegistry(),
            instanceNftId,
            fireProductName,
            fireUsdAddress,
            firePoolAddress,
            fireProductAuthAddress,
        ],
        {
            libraries: {
                AmountLib: amountLibAddress,
                FeeLib: feeLibAddress,
                NftIdLib: nftIdLibAddress,
                ObjectTypeLib: objectTypeLibAddress,
                ReferralLib: referralLibAddress,
                RiskIdLib: riskIdLibAddress,
                SecondsLib: secondsLibAddress,
                TimestampLib: timestampLibAddress,
                UFixedLib: ufixedLibAddress,
            }
        });
    const fireProduct = fireProductBaseContract as FireProduct;
    try {
        await executeTx(async () => await fireProduct.register());
    } catch (err) {
        const decodedError: DecodedError = await errorDecoder.decode(err)
        logger.error(decodedError.reason);
        logger.error(decodedError.args);
        throw err;
    }
    const fireProductNftId = await fireProduct.getNftId();

    logger.info(`FirePool registered at ${firePoolAddress} with NFT ID ${firePoolNftId}`);
    logger.info(`FireProduct registered at ${fireProductAddress} with NFT ID ${fireProductNftId}`);
}


main().catch((error) => {
    logger.error(error.stack);
    logger.error(error.data);
    process.exit(1);
});