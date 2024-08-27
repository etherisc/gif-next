import { resolveAddress, Signer } from "ethers";
import { FirePool, FireProduct, FireProduct__factory, IInstance__factory, IInstanceService__factory, IRegistry__factory, TokenRegistry__factory } from "../typechain-types";
import { getNamedAccounts } from "./libs/accounts";
import { deployContract } from "./libs/deployment";
import { LibraryAddresses } from "./libs/libraries";
import { ServiceAddresses } from "./libs/services";
import { executeTx, getFieldFromLogs, getTxOpts } from "./libs/transaction";
import { loadVerificationQueueState } from './libs/verification_queue';
import { logger } from "./logger";

async function main() {
    loadVerificationQueueState();

    const { protocolOwner, productOwner: fireOwner } = await getNamedAccounts();

    await deployFireComponentContracts(
        {
            amountLibAddress: process.env.AMOUNTLIB_ADDRESS!,
            contractLibAddress: process.env.CONTRACTLIB_ADDRESS!,
            feeLibAddress: process.env.FEELIB_ADDRESS!,
            nftIdLibAddress: process.env.NFTIDLIB_ADDRESS!,
            objectTypeLibAddress: process.env.OBJECTTYPELIB_ADDRESS!,
            referralLibAddress: process.env.REFERRALLIB_ADDRESS!,
            riskIdLibAddress: process.env.RISKIDLIB_ADDRESS!,
            roleIdLibAddress: process.env.ROLEIDLIB_ADDRESS!,
            secondsLibAddress: process.env.SECONDSLIB_ADDRESS!,
            selectorLibAddress: process.env.SELECTORLIB_ADDRESS!,
            strLibAddress: process.env.STRLIB_ADDRESS!,
            timestampLibAddress: process.env.TIMESTAMPLIB_ADDRESS!,
            uFixedLibAddress: process.env.UFIXEDLIB_ADDRESS!,
            versionLibAddress: process.env.VERSIONLIB_ADDRESS!,
            versionPartLibAddress: process.env.VERSIONPARTLIB_ADDRESS!,
        } as LibraryAddresses,
        {
            instanceServiceAddress: process.env.INSTANCE_SERVICE_ADDRESS!,
        } as ServiceAddresses,
        fireOwner,
        protocolOwner,
    );
}


export async function deployFireComponentContracts(libraries: LibraryAddresses, services: ServiceAddresses, fireOwner: Signer, registryOwner: Signer) {
    logger.info("===== deploying fire insurance components ...");
    
    const amountLibAddress = libraries.amountLibAddress;
    const contractLibAddress = libraries.contractLibAddress;
    const feeLibAddress = libraries.feeLibAddress;
    const nftIdLibAddress = libraries.nftIdLibAddress;
    const objectTypeLibAddress = libraries.objectTypeLibAddress;
    const referralLibAddress = libraries.referralLibAddress;
    const riskIdLibAddress = libraries.riskIdLibAddress;
    const roleIdLibAddress = libraries.roleIdLibAddress;
    const secondsLibAddress = libraries.secondsLibAddress;
    const selectorLibAddress = libraries.selectorLibAddress;
    const strLibAddress = libraries.strLibAddress;
    const timestampLibAddress = libraries.timestampLibAddress;
    const ufixedLibAddress = libraries.uFixedLibAddress;
    const versionLibAddress = libraries.versionLibAddress;
    const versionPartLibAddress = libraries.versionPartLibAddress;
        
    const instanceServiceAddress = services.instanceServiceAddress;

    logger.debug(`instanceServiceAddress: ${instanceServiceAddress}`);
    const instanceService = IInstanceService__factory.connect(await resolveAddress(instanceServiceAddress), fireOwner);

    logger.info("===== create new instance");
    const instanceCreateTx = await executeTx(async () => 
        await instanceService.createInstance(getTxOpts()),
        "fire ex - createInstance",
        [IInstanceService__factory.createInterface()]
    );

    const instanceAddress = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceCloned", "instance") as string;
    const instanceNftId = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceCloned", "instanceNftId") as string;
    logger.debug(`Instance created at ${instanceAddress} with NFT ID ${instanceNftId}`);
    const instance = IInstance__factory.connect(instanceAddress, fireOwner);

    logger.info(`===== deploying Fire contracts`);

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
                ObjectTypeLib: objectTypeLibAddress,
                RoleIdLib: roleIdLibAddress,
                SelectorLib: selectorLibAddress,
                StrLib: strLibAddress,
                TimestampLib: timestampLibAddress,
                VersionPartLib: versionPartLibAddress,
            }
        },
        "contracts/examples/fire/FireProductAuthorization.sol:FireProductAuthorization");

    logger.info(`registering FireUSD on TokenRegistry`);    

    const registry = IRegistry__factory.connect(await instance.getRegistry(), registryOwner);
    const tokenRegistry = TokenRegistry__factory.connect(await registry.getTokenRegistryAddress(), registryOwner);
    await executeTx(async () =>
        await tokenRegistry.registerToken(fireUsdAddress, getTxOpts()),
        "fire ex - registerToken",
        [TokenRegistry__factory.createInterface()]
    );

    await executeTx(async () =>
        await tokenRegistry.setActiveForVersion(
            (await tokenRegistry.runner?.provider?.getNetwork())?.chainId || 1, 
            fireUsdAddress, 
            3, 
            true,
            getTxOpts()),
        "fire ex - setActiveForVersion",
        [TokenRegistry__factory.createInterface()]
    );

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
                ContractLib: contractLibAddress,
                FeeLib: feeLibAddress,
                NftIdLib: nftIdLibAddress,
                ReferralLib: referralLibAddress,
                RiskIdLib: riskIdLibAddress,
                SecondsLib: secondsLibAddress,
                TimestampLib: timestampLibAddress,
                UFixedLib: ufixedLibAddress,
                VersionLib: versionLibAddress,
                ObjectTypeLib: objectTypeLibAddress,
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
                ObjectTypeLib: objectTypeLibAddress,
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
                ContractLib: contractLibAddress,
                NftIdLib: nftIdLibAddress,
                UFixedLib: ufixedLibAddress,
                VersionLib: versionLibAddress,
                ObjectTypeLib: objectTypeLibAddress,
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

    logger.info(`===== Instance created. address: ${instanceAddress}, NFT ID: ${instanceNftId}`);
    logger.info(`===== FireUSD deployed at ${fireUsdAddress}`);
    logger.info(`===== FireProduct deployed at ${fireProductAddress} and registered with NFT ID ${fireProductNftId}`);
    logger.info(`===== FirePool deployed at ${firePoolAddress} and registered with NFT ID ${firePoolNftId}`);
}

if (require.main === module) {
    main().catch((error) => {
        logger.error(error.stack);
        logger.error(error.data);
        process.exit(1);
    });
}
