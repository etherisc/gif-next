import { AbiCoder, AddressLike, Signer } from "ethers";
import { ethers } from "hardhat";
import * as iProxyDeployerAbi from "../../artifacts/contracts/shared/Proxy.sol/ProxyDeployer.json";
import { ProxyDeployer, Registerable, RegistryUpgradeable, Registry__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { IERC1967ABI } from "./erc1967";
import { IERC721ABI } from "./erc721";
import { LibraryAddresses } from "./libraries";
import { executeTx, getFieldFromLogs } from "./transaction";

const PROXYDEPLOYERABI = new ethers.Interface(iProxyDeployerAbi.abi);


export type RegistryAddresses = {
    registryAdmin: AddressLike;
    registryAddress: AddressLike; //proxy
    registryImplementation: AddressLike; 
    registryNftId: string;
    chainNftAddress: AddressLike;
}

export async function deployAndInitializeRegistry(owner: Signer, libraries: LibraryAddresses): Promise<RegistryAddresses> {

    const { address: registryAdmin, contract: deployerBaseContract } = await deployContract(
        "ProxyDeployer",
        owner
        );
    const deployer = deployerBaseContract as ProxyDeployer;

    const { address: registryImplementation, contract: registryBaseContract } = await deployContract(
        "Registry",
        owner,
        undefined,
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
                VersionLib: libraries.versionLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress
            }
        });
    const registryImplementationContract = registryBaseContract as RegistryUpgradeable;

    const abi = AbiCoder.defaultAbiCoder();
    const ownerAddress = await owner.getAddress();
    const intializationData = abi.encode(["address"], [ownerAddress]);

    let registryNftIdFromLogs;
    let registryAddressFromLogs;
    let registryImplFromLogs;
    
    try {
        const tx = await executeTx(async () => await deployer.deploy(registryImplementation, intializationData))
        registryImplFromLogs = getFieldFromLogs(tx, IERC1967ABI, "Upgraded", "implementation")
        // get tx return value...the only possible way is to emit event with this value...or use ethers.js staticCall to execute as view function first?
        //const result = await proxy.staticCall.deploy(registryImplementation, intializationData);        
        registryAddressFromLogs = getFieldFromLogs(tx, PROXYDEPLOYERABI, "ProxyDeployed", "proxy");
        // tx executes with 3 "Transfer" events, using one with the lastest index
        registryNftIdFromLogs = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId") 
    } catch (error: unknown) {
        if (! (error as Error).message.includes("ERROR:REG-001:ALREADY_INITIALIZED")) {
            throw error;
        }
    }

    const registry = registryImplementationContract.attach(registryAddressFromLogs) as RegistryUpgradeable;

    const chainNftAddress = await registry.getChainNft();
    const registryOwner = await registry["getOwner()"]();

    logger.info(`Registry proxy deployed at ${registryAddressFromLogs}`);
    logger.info(`Registry proxy admin is ${registryAdmin}`);
    logger.info(`Registry implementation is ${registryImplFromLogs}`);
    logger.info(`Registry owner is ${registryOwner}`);
    logger.info(`Registry initialized with ChainNft: ${chainNftAddress}, RegistryNftId: ${registryNftIdFromLogs}`);
    return {
        registryAdmin,
        registryAddress: registryAddressFromLogs,
        registryImplementation: registryImplFromLogs,
        registryNftId: registryNftIdFromLogs,
        chainNftAddress
    };
}

export async function register(registrable: Registerable, address: AddressLike, name: string, registryAddresses: RegistryAddresses, signer: Signer): Promise<string> {
    const registry = Registry__factory.connect(registryAddresses.registryAddress.toString(), signer);
    if (await registry["isRegistered(address)"](address)) {
        const nftId = await registry["getNftId(address)"](address);
        logger.info(`already registered - nftId: ${nftId}`);
        return nftId.toString();
    }
    logger.debug("registering Registrable " + name);
    const tx = await executeTx(async () => await registrable.register());
    const nftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    logger.info(`registered - nftId: ${nftId}`);
    return nftId;
}
