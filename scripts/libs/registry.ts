import { AddressLike, Signer, AbiCoder } from "ethers";
import { Registerable, Registry, RegistryUpgradeable, Registry__factory, ProxyDeployer } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { IERC721ABI } from "./erc721";
import { IERC1967ABI } from "./erc1967";
import { LibraryAddresses } from "./libraries";
import { executeTx, getFieldFromLogs } from "./transaction";


export type RegistryAddresses = {
    registryAdmin: AddressLike;
    registryAddress: AddressLike; //proxy
    registryImplementation: AddressLike; 
    registryNftId: string;
    chainNftAddress: AddressLike;
}

export async function deployAndInitializeRegistry(owner: Signer, libraries: LibraryAddresses): Promise<RegistryAddresses> {

    const { address: registryAdmin, contract: proxyBaseContract } = await deployContract(
        "ProxyDeployer",
        owner
        );
    const proxy = proxyBaseContract as ProxyDeployer;

    logger.info(`Registry admin deployed at ${registryAdmin}`);

    const { address: registryImplementation, contract: registryBaseContract } = await deployContract(
        "RegistryUpgradeable",
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
    const registry = registryBaseContract as RegistryUpgradeable;

    const abi = AbiCoder.defaultAbiCoder();
    const ownerAddress = await owner.getAddress();// TODO without await
    const intializationData = abi.encode(["address"], [ownerAddress]);

    let registryAddress;
    let registryImplFromLogs;
    let registryNftId;
    
    try {
        const tx = await executeTx(async () => await proxy.deploy(registryImplementation, intializationData))
        registryImplFromLogs = getFieldFromLogs(tx, IERC1967ABI, "Upgraded", "implementation")
        // TODO get registryAddress from tx...only possible way is to emit event with it?
        //registryAddress = tx.getResult();// ContractTransactionResponse // read address from 
        registryNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId") 
        
    } catch (error: unknown) {
        if (! (error as Error).message.includes("ERROR:REG-001:ALREADY_INITIALIZED")) {
            throw error;
        }
        registryNftId = await registry["getNftId()"]();
    }

    // TODO returns all zeros...
    const chainNftAddress = await registry["getChainNft"]();

    if (registryImplementation !== registryImplFromLogs) {
        throw new Error("proxy implementation is different from expected");
    }

    logger.info(`Registry proxy deployed at ${registryAddress}`);
    logger.info(`ANNNNNNNNNNNND initialized with implementation ${registryImplementation}, ChainNft ${chainNftAddress}, RegistryNftId: ${registryNftId}`);
    //logger.info(`Registry implementation initialized with ChainNft @ ${chainNftAddress}. RegistryNftId: ${registryNftId}`);
    return {
        registryAdmin,
        registryAddress,
        registryImplementation: registryImplFromLogs,
        registryNftId,
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
