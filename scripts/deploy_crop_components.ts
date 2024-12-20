import { AddressLike, resolveAddress, Signer } from "ethers";
import { IInstance__factory, IInstanceService__factory, IRegistry__factory, TokenRegistry__factory, FlightProduct, FlightProduct__factory, FlightPool, FlightOracle, IInstance, CropProduct, InstanceReader__factory, AccountingToken, AccountingToken__factory, CropProduct__factory } from "../typechain-types";
import { getNamedAccounts } from "./libs/accounts";
import { deployContract } from "./libs/deployment";
import { LibraryAddresses } from "./libs/libraries";
import { ServiceAddresses } from "./libs/services";
import { executeTx, getFieldFromLogs, getTxOpts } from "./libs/transaction";
import { loadVerificationQueueState } from './libs/verification_queue';
import { logger } from "./logger";
import simpleGit from "simple-git";
import { printBalances, printGasSpent, resetBalances, resetGasSpent, setBalanceAfter } from "./libs/gas_and_balance_tracker";
import { ethers } from "hardhat";
import { instance } from "../typechain-types/contracts";
import { crop } from "../typechain-types/contracts/examples";

async function main() {
    loadVerificationQueueState();

    const { protocolOwner, productOwner: cropOwner, instanceOwner, productOperator } = await getNamedAccounts();

    await deployCropComponentContracts(
        {
            accessAdminLibAddress: process.env.ACCESSADMINLIB_ADDRESS!,
            amountLibAddress: process.env.AMOUNTLIB_ADDRESS!,
            blockNumberLibAddress: process.env.BLOCKNUMBERLIB_ADDRESS!,
            contractLibAddress: process.env.CONTRACTLIB_ADDRESS!,
            feeLibAddress: process.env.FEELIB_ADDRESS!,
            libRequestIdSetAddress: process.env.LIBREQUESTIDSET_ADDRESS!,
            nftIdLibAddress: process.env.NFTIDLIB_ADDRESS!,
            objectTypeLibAddress: process.env.OBJECTTYPELIB_ADDRESS!,
            referralLibAddress: process.env.REFERRALLIB_ADDRESS!,
            requestIdLibAddress: process.env.REQUESTIDLIB_ADDRESS!,
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
        cropOwner,
        productOperator,
        protocolOwner,
    );
}


export async function deployCropComponentContracts(
    libraries: LibraryAddresses, services: ServiceAddresses, cropOwner: Signer, productOperator: Signer, registryOwner: Signer) {
    resetBalances();
    resetGasSpent();
    
    logger.info("===== deploying crop insurance components on a new instance ...");
    
    const accessAdminLibAddress = libraries.accessAdminLibAddress;
    const amountLibAddress = libraries.amountLibAddress;
    const blocknumberLibAddress = libraries.blockNumberLibAddress;
    const contractLibAddress = libraries.contractLibAddress;
    const feeLibAddress = libraries.feeLibAddress;
    const nftIdLibAddress = libraries.nftIdLibAddress;
    const objectTypeLibAddress = libraries.objectTypeLibAddress;
    const referralLibAddress = libraries.referralLibAddress;
    const requestIdLibAddress = libraries.requestIdLibAddress;
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

    let instanceAddress: string;
    let instanceNftId: string;
    let instance: IInstance;

    if (process.env.INSTANCE_ADDRESS !== undefined && process.env.INSTANCE_ADDRESS !== '') {
        logger.info(`===== using existing instance @ ${process.env.INSTANCE_ADDRESS}`);
        instanceAddress = process.env.INSTANCE_ADDRESS!;
        instance = IInstance__factory.connect(instanceAddress, cropOwner);
        instanceNftId = (await instance.getNftId()).toString();
    } else {
        logger.debug(`instanceServiceAddress: ${instanceServiceAddress}`);
        const instanceService = IInstanceService__factory.connect(await resolveAddress(instanceServiceAddress), cropOwner);

        logger.info("===== create new instance");
        const instanceCreateTx = await executeTx(async () => 
            await instanceService.createInstance(getTxOpts()),
            "crop - createInstance",
            [IInstanceService__factory.createInterface()]
        );

        instanceAddress = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceServiceInstanceCreated", "instance") as string;
        instanceNftId = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceServiceInstanceCreated", "instanceNftId") as string;
        logger.info(`Instance created at ${instanceAddress} with NFT ID ${instanceNftId}`);
        instance = IInstance__factory.connect(instanceAddress, cropOwner);
    }

    logger.info(`----- AccountingToken -----`);
    let accountingTokenAddress: AddressLike;
    let accountingToken: AccountingToken;
    if (process.env.ACCOUNTING_TOKEN_ADDRESS !== undefined && process.env.ACCOUNTING_TOKEN_ADDRESS !== '') {
        logger.info(`using existing Token at ${process.env.ACCOUNTING_TOKEN_ADDRESS}`);
        accountingTokenAddress = process.env.ACCOUNTING_TOKEN_ADDRESS;
        accountingToken = AccountingToken__factory.connect(accountingTokenAddress, registryOwner);
    } else {
        const { address: deployedAccountingTokenAddress, contract: accountingTokenBaseContract } = await deployContract(
            "AccountingToken",
            registryOwner);
        accountingTokenAddress = deployedAccountingTokenAddress;
        accountingToken = accountingTokenBaseContract as AccountingToken;
        logger.info(`registering AccountingToken on TokenRegistry`);    

        const registry = IRegistry__factory.connect(await instance.getRegistry(), registryOwner);
        const tokenRegistry = TokenRegistry__factory.connect(await registry.getTokenRegistryAddress(), registryOwner);
        await executeTx(async () =>
            await tokenRegistry.registerToken(accountingTokenAddress, getTxOpts()),
            "crop - registerToken",
            [TokenRegistry__factory.createInterface()]
        );
        await executeTx(async () =>
            await tokenRegistry.setActiveForVersion(
                (await tokenRegistry.runner?.provider?.getNetwork())?.chainId || 1, 
                accountingTokenAddress, 
                3, 
                true,
                getTxOpts()),
            "crop - setActiveForVersion",
            [TokenRegistry__factory.createInterface()]
        ); 
    }

    logger.info(`===== deploying crop contracts`);
        
    logger.info(`----- LocationLib -----`);
    const { address: locationLibAddress } = await deployContract(
        "LocationLib",
        cropOwner,
        [],
        {
            libraries: {

            }
        });

    logger.info(`----- CropProduct -----`);
    const deploymentId = Math.random().toString(16).substring(7);
    const productName = "CropProduct_" + deploymentId;
    const { address: cropProductAuthAddress } = await deployContract(
        "CropProductAuthorization",
        cropOwner,
        [productName],
        {
            libraries: {
                AccessAdminLib: accessAdminLibAddress,
                BlocknumberLib: blocknumberLibAddress,
                ObjectTypeLib: objectTypeLibAddress,
                RoleIdLib: roleIdLibAddress,
                SelectorLib: selectorLibAddress,
                StrLib: strLibAddress,
                TimestampLib: timestampLibAddress,
                VersionPartLib: versionPartLibAddress,
            }
        },
        "contracts/examples/crop/CropProductAuthorization.sol:CropProductAuthorization");

    const { address: cropProductAddress, contract: cropProductBaseContract } = await deployContract(
        "CropProduct",
        cropOwner,
        [
            await instance.getRegistry(),
            instanceNftId,
            productName,
            cropProductAuthAddress,
        ],
        {
            libraries: {
                LocationLib: locationLibAddress,
                AmountLib: amountLibAddress,
                ContractLib: contractLibAddress,
                FeeLib: feeLibAddress,
                NftIdLib: nftIdLibAddress,
                ObjectTypeLib: objectTypeLibAddress,
                ReferralLib: referralLibAddress,
                SecondsLib: secondsLibAddress,
                StrLib: strLibAddress,
                TimestampLib: timestampLibAddress,
                UFixedLib: ufixedLibAddress,
                VersionLib: versionLibAddress,
            }
        });
    const cropProduct = cropProductBaseContract as CropProduct;

    logger.info(`registering CropProduct on Instance`);
    await executeTx(async () => 
        await instance.registerProduct(cropProductAddress, accountingTokenAddress, getTxOpts()),
        "crop - registerProduct",
        [IInstance__factory.createInterface()]
    );
    const cropProductNftId = await cropProduct.getNftId();

    const instanceReaderAddress = await instance.getInstanceReader();
    const instanceReader = InstanceReader__factory.connect(instanceReaderAddress, cropOwner);
    const { roleId } = await instanceReader.getRoleForName("ProductOperatorRole");

    await executeTx(async () =>
        await instance.grantRole(
            roleId, 
            await productOperator.getAddress(), 
            getTxOpts()),
        "crop - grantProductOperator",
        [IInstance__factory.createInterface()]
    );

    const accountingTokenDecimals = await accountingToken.decimals();

    await executeTx(async () =>
        await cropProduct.setConstants(
            10 * Math.pow(10, Number(accountingTokenDecimals)), // 10 min premium
            99 * Math.pow(10, Number(accountingTokenDecimals)), // 99 max premium
            200 * Math.pow(10, Number(accountingTokenDecimals)), // 200 min sum insured
            1000 * Math.pow(10, Number(accountingTokenDecimals)), // 1000 max sum insured
            5,
            getTxOpts()
        ),
        "crop - setConstants",
        [CropProduct__factory.createInterface()]
    );

    // logger.info(`----- FlightPool -----`);
    // const poolName = "FDPool_" + deploymentId;
    // const { address: flightPoolAuthAddress } = await deployContract(
    //     "FlightPoolAuthorization",
    //     flightOwner,
    //     [poolName],
    //     {
    //         libraries: {
    //             AccessAdminLib: accessAdminLibAddress,
    //             BlocknumberLib: blocknumberLibAddress,
    //             ObjectTypeLib: objectTypeLibAddress,
    //             RoleIdLib: roleIdLibAddress,
    //             SelectorLib: selectorLibAddress,
    //             StrLib: strLibAddress,
    //             TimestampLib: timestampLibAddress,
    //             VersionPartLib: versionPartLibAddress,
    //         }
    //     },
    //     "contracts/examples/flight/FlightPoolAuthorization.sol:FlightPoolAuthorization");

    // const { address: flightPoolAddress, contract: flightPoolBaseContract } = await deployContract(
    //     "FlightPool",
    //     flightOwner,
    //     [
    //         await instance.getRegistry(),
    //         flightProductNftId,
    //         poolName,
    //         flightPoolAuthAddress,
    //     ],
    //     {
    //         libraries: {
    //             AmountLib: amountLibAddress,
    //             ContractLib: contractLibAddress,
    //             FeeLib: feeLibAddress,
    //             NftIdLib: nftIdLibAddress,
    //             ObjectTypeLib: objectTypeLibAddress,
    //             SecondsLib: secondsLibAddress,
    //             UFixedLib: ufixedLibAddress,
    //             VersionLib: versionLibAddress,
    //         }
    //     });
    // const flightPool = flightPoolBaseContract as FlightPool;
    
    // logger.info(`registering FlightPool on FlightProduct`);
    // await executeTx(async () => 
    //     await flightProduct.registerComponent(flightPoolAddress, getTxOpts()),
    //     "fd - registerComponent pool",
    //     [FlightProduct__factory.createInterface()]
    // );
    // const flightPoolNftId = await flightPool.getNftId();

    // logger.info(`----- FlightOracle -----`);
    // const oracleName = "FDOracle_" + deploymentId;
    // const commitHash = await simpleGit().revparse(["HEAD"]);
    
    // const { address: flightOracleAuthAddress } = await deployContract(
    //     "FlightOracleAuthorization",
    //     flightOwner,
    //     [
    //         oracleName,
    //         commitHash,
    //     ],
    //     {
    //         libraries: {
    //             AccessAdminLib: accessAdminLibAddress,
    //             BlocknumberLib: blocknumberLibAddress,
    //             ObjectTypeLib: objectTypeLibAddress,
    //             RoleIdLib: roleIdLibAddress,
    //             SelectorLib: selectorLibAddress,
    //             StrLib: strLibAddress,
    //             TimestampLib: timestampLibAddress,
    //             VersionPartLib: versionPartLibAddress,
    //         }
    //     },
    //     "contracts/examples/flight/FlightOracleAuthorization.sol:FlightOracleAuthorization");

    // const { address: flightOracleAddress, contract: flightOracleBaseContract } = await deployContract(
    //     "FlightOracle",
    //     flightOwner,
    //     [
    //         await instance.getRegistry(),
    //         flightProductNftId,
    //         oracleName,
    //         flightOracleAuthAddress,
    //     ],
    //     {
    //         libraries: {
    //             ContractLib: contractLibAddress,
    //             NftIdLib: nftIdLibAddress,
    //             StrLib: strLibAddress,
    //             TimestampLib: timestampLibAddress,
    //             VersionLib: versionLibAddress,
    //         }
    //     });
    // const flightOracle = flightOracleBaseContract as FlightOracle;
    
    // logger.info(`registering FlightOracle on FlightProduct`);
    // await executeTx(async () => 
    //     await flightProduct.registerComponent(flightOracleAddress, getTxOpts()),
    //     "fd - registerComponent oracle",
    //     [FlightProduct__factory.createInterface()]
    // );
    // const flightOracleNftId = await flightOracle.getNftId();

    // await executeTx(async () =>
    //     await flightProduct.setOracleNftId(getTxOpts()),
    //     "fd - setOracleNftId",
    //     [FlightProduct__factory.createInterface()]
    // );

    setBalanceAfter(await resolveAddress(registryOwner), await ethers.provider.getBalance(registryOwner));
    setBalanceAfter(await resolveAddress(cropOwner), await ethers.provider.getBalance(cropOwner));
    printBalances();
    printGasSpent();

    logger.info(`===== Instance created. address: ${instanceAddress}, NFT ID: ${instanceNftId}`);
    logger.info(`===== AccountingToken deployed at ${accountingTokenAddress}`);
    logger.info(`===== LocationLib deployed at ${locationLibAddress}`);
    logger.info(`===== CropProduct deployed at ${cropProductAddress} and registered with NFT ID ${cropProductNftId}`);
    // logger.info(`===== FlightPool deployed at ${flightPoolAddress} and registered with NFT ID ${flightPoolNftId}`);
}

if (require.main === module) {
    main().catch((error) => {
        logger.error(error.stack);
        logger.error(error.data);
        process.exit(1);
    });
}
