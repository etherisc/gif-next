import { AddressLike, resolveAddress, Signer } from "ethers";
import { IInstance__factory, IInstanceService__factory, IRegistry__factory, TokenRegistry__factory, FlightProduct, FlightProduct__factory, FlightPool, FlightOracle, IInstance } from "../typechain-types";
import { getNamedAccounts } from "./libs/accounts";
import { deployContract } from "./libs/deployment";
import { LibraryAddresses } from "./libs/libraries";
import { ServiceAddresses } from "./libs/services";
import { executeTx, getFieldFromLogs, getTxOpts } from "./libs/transaction";
import { loadVerificationQueueState } from './libs/verification_queue';
import { logger } from "./logger";
import simpleGit from "simple-git";

async function main() {
    loadVerificationQueueState();

    const { protocolOwner, productOwner: flightOwner } = await getNamedAccounts();

    await deployFlightDelayComponentContracts(
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
        flightOwner,
        protocolOwner,
    );
}


export async function deployFlightDelayComponentContracts(libraries: LibraryAddresses, services: ServiceAddresses, flightOwner: Signer, registryOwner: Signer) {
    logger.info("===== deploying flight delay insurance components on a new instance ...");
    
    const accessAdminLibAddress = libraries.accessAdminLibAddress;
    const amountLibAddress = libraries.amountLibAddress;
    const blocknumberLibAddress = libraries.blockNumberLibAddress;
    const contractLibAddress = libraries.contractLibAddress;
    const feeLibAddress = libraries.feeLibAddress;
    const libRequestIdSetAddress = libraries.libRequestIdSetAddress;
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

    let instanceAddress: string;
    let instanceNftId: string;
    let instance: IInstance;

    if (process.env.SKIP_INSTANCE_CREATION) {
        logger.info(`===== using existing instance @ ${process.env.INSTANCE_ADDRESS}`);
        instanceAddress = process.env.INSTANCE_ADDRESS!;
        instance = IInstance__factory.connect(instanceAddress, flightOwner);
        instanceNftId = (await instance.getNftId()).toString();
    } else {
        logger.debug(`instanceServiceAddress: ${instanceServiceAddress}`);
        const instanceService = IInstanceService__factory.connect(await resolveAddress(instanceServiceAddress), flightOwner);

        logger.info("===== create new instance");
        const instanceCreateTx = await executeTx(async () => 
            await instanceService.createInstance(getTxOpts()),
            "fd - createInstance",
            [IInstanceService__factory.createInterface()]
        );

        instanceAddress = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceServiceInstanceCreated", "instance") as string;
        instanceNftId = getFieldFromLogs(instanceCreateTx.logs, instanceService.interface, "LogInstanceServiceInstanceCreated", "instanceNftId") as string;
        logger.info(`Instance created at ${instanceAddress} with NFT ID ${instanceNftId}`);
        instance = IInstance__factory.connect(instanceAddress, flightOwner);
    }

    logger.info(`===== deploying flight delay contracts`);

    logger.info(`----- FlightUSD -----`);
    let flightUsdAddress: AddressLike;
    if (process.env.FLIGHT_TOKEN_ADDRESS) {
        logger.info(`using existing Token at ${process.env.FLIGHT_TOKEN_ADDRESS}`);
        flightUsdAddress = process.env.FLIGHT_TOKEN_ADDRESS;
    } else {
        const { address: deployedFlightUsdAddress } = await deployContract(
            "FlightUSD",
            flightOwner);
        flightUsdAddress = deployedFlightUsdAddress;
        logger.info(`registering FlightUSD on TokenRegistry`);    

        const registry = IRegistry__factory.connect(await instance.getRegistry(), registryOwner);
        const tokenRegistry = TokenRegistry__factory.connect(await registry.getTokenRegistryAddress(), registryOwner);
        await executeTx(async () =>
            await tokenRegistry.registerToken(flightUsdAddress, getTxOpts()),
            "fd - registerToken",
            [TokenRegistry__factory.createInterface()]
        );
        await executeTx(async () =>
            await tokenRegistry.setActiveForVersion(
                (await tokenRegistry.runner?.provider?.getNetwork())?.chainId || 1, 
                flightUsdAddress, 
                3, 
                true,
                getTxOpts()),
            "fd - setActiveForVersion",
            [TokenRegistry__factory.createInterface()]
        ); 
    }
    
    logger.info(`----- FlightLib -----`);
    const { address: flightLibAddress } = await deployContract(
        "FlightLib",
        flightOwner,
        [],
        {
            libraries: {
                AmountLib: amountLibAddress,
                RiskIdLib: riskIdLibAddress,
                TimestampLib: timestampLibAddress,
            }
        });
        
    logger.info(`----- FlightProduct -----`);
    const deploymentId = Math.random().toString(16).substring(7);
    const productName = "FDProduct_" + deploymentId;
    const { address: flightProductAuthAddress } = await deployContract(
        "FlightProductAuthorization",
        flightOwner,
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
        // });
        },
        "contracts/examples/flight/FlightProductAuthorization.sol:FlightProductAuthorization");

    const { address: flightMessageVerifierAddress } = await deployContract(
        "FlightMessageVerifier",
        flightOwner,
        [],
        {
            libraries: {
            }
        });

    const { address: flightProductAddress, contract: flightProductBaseContract } = await deployContract(
        "FlightProduct",
        flightOwner,
        [
            await instance.getRegistry(),
            instanceNftId,
            productName,
            flightProductAuthAddress,
            flightMessageVerifierAddress,
        ],
        {
            libraries: {
                AmountLib: amountLibAddress,
                ContractLib: contractLibAddress,
                FeeLib: feeLibAddress,
                FlightLib: flightLibAddress,
                NftIdLib: nftIdLibAddress,
                ObjectTypeLib: objectTypeLibAddress,
                ReferralLib: referralLibAddress,
                SecondsLib: secondsLibAddress,
                TimestampLib: timestampLibAddress,
                VersionLib: versionLibAddress,
            }
        });
    const flightProduct = flightProductBaseContract as FlightProduct;

    logger.info(`registering FlightProduct on Instance`);
    await executeTx(async () => 
        await instance.registerProduct(flightProductAddress, flightUsdAddress, getTxOpts()),
        "fd - registerProduct",
        [IInstance__factory.createInterface()]
    );
    const flightProductNftId = await flightProduct.getNftId();

    logger.info(`----- FlightPool -----`);
    const poolName = "FDPool_" + deploymentId;
    const { address: flightPoolAuthAddress } = await deployContract(
        "FlightPoolAuthorization",
        flightOwner,
        [poolName],
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
        "contracts/examples/flight/FlightPoolAuthorization.sol:FlightPoolAuthorization");

    const { address: flightPoolAddress, contract: flightPoolBaseContract } = await deployContract(
        "FlightPool",
        flightOwner,
        [
            await instance.getRegistry(),
            flightProductNftId,
            poolName,
            flightPoolAuthAddress,
        ],
        {
            libraries: {
                AmountLib: amountLibAddress,
                ContractLib: contractLibAddress,
                FeeLib: feeLibAddress,
                NftIdLib: nftIdLibAddress,
                ObjectTypeLib: objectTypeLibAddress,
                SecondsLib: secondsLibAddress,
                UFixedLib: ufixedLibAddress,
                VersionLib: versionLibAddress,
            }
        });
    const flightPool = flightPoolBaseContract as FlightPool;
    
    logger.info(`registering FlightPool on FlightProduct`);
    await executeTx(async () => 
        await flightProduct.registerComponent(flightPoolAddress, getTxOpts()),
        "fd - registerComponent pool",
        [FlightProduct__factory.createInterface()]
    );
    const flightPoolNftId = await flightPool.getNftId();

    logger.info(`----- FlightOracle -----`);
    const oracleName = "FDOracle_" + deploymentId;
    const commitHash = await simpleGit().revparse(["HEAD"]);
    
    const { address: flightOracleAuthAddress } = await deployContract(
        "FlightOracleAuthorization",
        flightOwner,
        [
            oracleName,
            commitHash,
        ],
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
        "contracts/examples/flight/FlightOracleAuthorization.sol:FlightOracleAuthorization");

    const { address: flightOracleAddress, contract: flightOracleBaseContract } = await deployContract(
        "FlightOracle",
        flightOwner,
        [
            await instance.getRegistry(),
            flightProductNftId,
            oracleName,
            flightOracleAuthAddress,
        ],
        {
            libraries: {
                ContractLib: contractLibAddress,
                NftIdLib: nftIdLibAddress,
                LibRequestIdSet: libRequestIdSetAddress,
                VersionLib: versionLibAddress,
            }
        });
    const flightOracle = flightOracleBaseContract as FlightOracle;
    
    logger.info(`registering FlightOracle on FlightProduct`);
    await executeTx(async () => 
        await flightProduct.registerComponent(flightOracleAddress, getTxOpts()),
        "fd - registerComponent oracle",
        [FlightProduct__factory.createInterface()]
    );
    const flightOracleNftId = await flightOracle.getNftId();


    logger.info(`===== Instance created. address: ${instanceAddress}, NFT ID: ${instanceNftId}`);
    logger.info(`===== FlightUSD deployed at ${flightUsdAddress}`);
    logger.info(`===== FlightLib deployed at ${flightLibAddress}`);
    logger.info(`===== FlightProduct deployed at ${flightProductAddress} and registered with NFT ID ${flightProductNftId}`);
    logger.info(`===== FlightPool deployed at ${flightPoolAddress} and registered with NFT ID ${flightPoolNftId}`);
    logger.info(`===== FlightOracle deployed at ${flightOracleAddress} and registered with NFT ID ${flightOracleNftId}`);
}

if (require.main === module) {
    main().catch((error) => {
        logger.error(error.stack);
        logger.error(error.data);
        process.exit(1);
    });
}
