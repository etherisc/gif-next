import { AddressLike, Signer, BigNumberish, encodeBytes32String } from "ethers";
import { Registerable, Registry, IRegistry, Registry__factory } from "../../typechain-types";
import { ContractMethodArgs } from "../../typechain-types/common";
//import { IRegistry } from "../../typechain-types/contracts/registry/Registry";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { IERC721ABI, IRegistryABI } from "./erc721";
import { LibraryAddresses } from "./libraries";
import { executeTx, getFieldFromLogs } from "./transaction";
import { A } from "../../typechain-types";

export type RegistryAddresses = {
    registryAddress: AddressLike;
    registryNftId: string;
    chainNftAddress: AddressLike;
}

export async function deployAndInitializeRegistry(owner: Signer, libraries: LibraryAddresses): Promise<RegistryAddresses> {
    const { address: registryAddress, contract: registryBaseContract } = await deployContract(
        "Registry",
        owner,
        undefined,
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
            }
        });

    const registry = registryBaseContract as Registry;
    let registryNftId;

    try {
        const tx = await executeTx(async () => await registry.initialize(owner));
        registryNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    } catch (error: unknown) {
        if (! (error as Error).message.includes("ERROR:REG-001:ALREADY_INITIALIZED")) {
            throw error;
        }
        registryNftId = await registry["getNftId(address)"](registryAddress);
    }

    const chainNftAddress = await registry.getChainNft();


    logger.info(`Registry ${registryAddress} initialized with ChainNft @ ${chainNftAddress}. RegistryNftId: ${registryNftId}`);
    return {
        registryAddress,
        registryNftId,
        chainNftAddress,
    };
}

export async function registerContract(contractAddress: AddressLike, name: string, registryAddresses: RegistryAddresses, signer: Signer): Promise<string> {
    const registry = Registry__factory.connect(registryAddresses.registryAddress.toString(), signer);
    if (await registry["isRegistered(address)"](contractAddress)) {
        const nftId = await registry["getNftId(address)"](contractAddress);
        logger.info(`already registered - nftId: ${nftId}`);
        return nftId.toString();
    }
    logger.debug("registering " + name + " contract");

    const contractInfo /*IRegistry.ObjectInfoStructOutput*/ = {
        nftId: 0n,
        parentNftId: BigInt(registryAddresses.registryNftId),
        objectType: 30n, // TOKEN
        objectAddress: contractAddress.toString(), 
        initialOwner: (await signer.getAddress()).toString(), 
        data: encodeBytes32String("") 
    };

    const tx = await executeTx(async () => await registry.register(contractInfo));

    const nftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    logger.info(`registered - nftId: ${nftId}`);
    return nftId;
}

export async function register(registrable: Registerable, address: AddressLike, name: string, registryAddresses: RegistryAddresses, signer: Signer): Promise<string> {
    const registry = Registry__factory.connect(registryAddresses.registryAddress.toString(), signer);
    if (await registry["isRegistered(address)"](address)) {
        const nftId = await registry["getNftId(address)"](address);
        logger.info(`already registered - nftId: ${nftId}`);
        return nftId.toString();
    }
    logger.debug("registering Registrable " + name);

    const info = await registrable["getInitialInfo"]();
    // see: https://github.com/ethers-io/ethers.js/issues/3953
    const newInfo = info.map(x => x);

    const tx = await executeTx(async () => await registry.register(newInfo));

    const nftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    logger.info(`registered - nftId: ${nftId}`);
    return nftId;
}

export async function approve(nftId: BigNumberish, objectType: BigNumberish, parentType: BigNumberish, name: string, registryAddresses: RegistryAddresses, signer: Signer) {
    const registry = Registry__factory.connect(registryAddresses.registryAddress.toString(), signer); 
    if (!await registry["isRegistered(uint96)"](nftId)) {
        logger.info(`Registrable ${name} is not registred with nftId ${nftId}`);
        return nftId.toString();
    }
    logger.debug("approving Registrable " + name);

    const tx = await executeTx(async () => await registry.approve(nftId, objectType, parentType));

    const approvedNftId = getFieldFromLogs(tx, IRegistryABI, "Approval", "nftId");
    const approvedObjectType = getFieldFromLogs(tx, IRegistryABI, "Approval", "objectType");
    const approvedParentType = getFieldFromLogs(tx, IRegistryABI, "Approval", "parentType");

    logger.info("Registrable " + name + ` with nftId ${approvedNftId}` + " is approved to register object of type " + approvedObjectType + " for parent of type " + approvedParentType);
}
