import { AddressLike, Signer, ethers } from "ethers";
import { Registry, Registry__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { executeTx, getFieldFromLogs } from "./transaction";
import { IERC721ABI } from "./erc721";

export async function isRegistered(signer: Signer, registryAddress: AddressLike, objectAddress: AddressLike): Promise<string|null> {
    const registryAsInstanceOwner = Registry__factory.connect(registryAddress.toString(), signer);
    const isRegistered = await registryAsInstanceOwner.isRegistered(objectAddress);

    if (! isRegistered) {
        return null;
    }
    
    const instanceNftId = await registryAsInstanceOwner.getNftId(objectAddress);
    logger.info(`Object ${objectAddress} is already registered with NFT ID: ${instanceNftId}`);
    return instanceNftId.toString();
}

export async function deployRegistry(owner: Signer, libraries: LibraryAddresses): Promise<{
    registryAddress: AddressLike,
    registryNftId: string,
    chainNftAddress: AddressLike,
}> {
    const { address: registryAddress, contract: registryBaseContract } = await deployContract(
        "Registry",
        owner,
        undefined,
        {
            libraries: {
                NftIdLib: libraries.nfIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
            }
        });
    const { address: chainNftAddress } = await deployContract(
        "ChainNft",
        owner,
        [registryAddress]);

    const registry = registryBaseContract as Registry;
    let registryNftId;

    // TODO: check if NFT is already initialized before intializing
    try {
        const tx = await executeTx(async () => await registry.initialize(chainNftAddress, owner));
        registryNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    } catch (error: any) {
        if (! error.message.includes("ERROR:REG-001:ALREADY_INITIALIZED")) {
            throw error;
        }
        // TODO: fetch existing RegistryNftId
    }

    logger.info(`Registry initialized with ChainNft @ ${chainNftAddress}. RegistryNftId: ${registryNftId}`);
    return {
        registryAddress,
        registryNftId,
        chainNftAddress,
    };
}