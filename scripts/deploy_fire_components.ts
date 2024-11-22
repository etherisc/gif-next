import { resolveAddress, Signer } from "ethers";
import { ethers } from "hardhat";
import { FirePool, FireProduct, FireProduct__factory, AccessAdmin__factory, IInstance__factory, IInstanceService__factory, IRegistry__factory, TokenRegistry__factory, FireUSD, IInstance } from "../typechain-types";
import { getNamedAccounts } from "./libs/accounts";
import { deployContract } from "./libs/deployment";
import { LibraryAddresses } from "./libs/libraries";
import { ServiceAddresses } from "./libs/services";
import { executeTx, getFieldFromLogs, getTxOpts } from "./libs/transaction";
import { loadVerificationQueueState } from './libs/verification_queue';
import { logger } from "./logger";
import { printBalances, printGasSpent, resetBalances, resetGasSpent, setBalanceAfter } from "./libs/gas_and_balance_tracker";

async function main() {
    loadVerificationQueueState();
    resetBalances();
    resetGasSpent();

    const { protocolOwner, productOwner: fireOwner } = await getNamedAccounts();

    await deployFireComponentContracts(
        {
            amountLibAddress: process.env.AMOUNTLIB_ADDRESS!,
            accessAdminLibAddress: process.env.ACCESSADMINLIB_ADDRESS!,
            blockNumberLibAddress: process.env.BLOCKNUMBERLIB_ADDRESS!,
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

    setBalanceAfter(await resolveAddress(protocolOwner), await ethers.provider.getBalance(protocolOwner));
    setBalanceAfter(await resolveAddress(fireOwner), await ethers.provider.getBalance(fireOwner));
    printBalances();
    printGasSpent();
}


export async function deployFireComponentContracts(libraries: LibraryAddresses, services: ServiceAddresses, fireOwner: Signer, registryOwner: Signer): Promise<{
    instance: IInstance,
    fireUsd: FireUSD,
    fireProduct: FireProduct,
    firePool: FirePool,
}> {
    logger.info("===== deploying fire insurance components ...");
    
    const accessAdminLibAddress = libraries.accessAdminLibAddress;
    const amountLibAddress = libraries.amountLibAddress;
    const blockNumberLibAddress = libraries.blockNumberLibAddress;
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

    const instanceAddress = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceServiceInstanceCreated", "instance") as string;
    const instanceNftId = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceServiceInstanceCreated", "instanceNftId") as string;
    logger.debug(`Instance created at ${instanceAddress} with NFT ID ${instanceNftId}`);
    const instance = IInstance__factory.connect(instanceAddress, fireOwner);

    logger.info(`===== deploying Fire contracts`);

    const { address: fireUsdAddress, contract: fireUSDBase } = await deployContract(
        "FireUSD",
        fireOwner);
    const fireUsd = fireUSDBase as FireUSD;
    
    const deploymentId = Math.random().toString(16).substring(7);
    const fireProductName = "FireProduct_" + deploymentId;
    const { address: fireProductAuthAddress } = await deployContract(
        "FireProductAuthorization",
        fireOwner,
        [fireProductName],
        {
            libraries: {
                AccessAdminLib: accessAdminLibAddress,
                BlocknumberLib: blockNumberLibAddress,
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
        await instance.registerProduct(fireProductAddress, fireUsdAddress, getTxOpts()),
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
                AccessAdminLib: accessAdminLibAddress,
                BlocknumberLib: blockNumberLibAddress,
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

    return {
        instance,
        fireUsd,
        fireProduct,
        firePool,
    };
}

if (require.main === module) {
    main().catch((error) => {
        logger.error(error.stack);
        logger.error(error.data);
        process.exit(1);
    });
}
