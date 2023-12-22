import { AddressLike, Signer } from "ethers";
import { Registerable, Registry, RegistryUpgradeable, Registry__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { IERC721ABI } from "./erc721";
import { LibraryAddresses } from "./libraries";
import { executeTx, getFieldFromLogs } from "./transaction";

export type RegistryAddresses = {
    registryAddress: AddressLike;
    registryNftId: string;
    chainNftAddress: AddressLike;
}

export async function deployAndInitializeRegistry(owner: Signer, libraries: LibraryAddresses): Promise<RegistryAddresses> {
    const { address: registryAddress, contract: registryBaseContract } = await deployContract(
        "RegistryUpgradeable",
        owner,
        undefined,
        {
            libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                ObjectTypeLib: libraries.objectTypeLibAddress,
            }
        });
    const { address: chainNftAddress } = await deployContract(
        "ChainNft",
        owner,
        [registryAddress]);

    const registry = registryBaseContract as Registry;
    let registryNftId;

    try {
        const tx = await executeTx(async () => await registry.initialize(chainNftAddress, owner));
        registryNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    } catch (error: unknown) {
        if (! (error as Error).message.includes("ERROR:REG-001:ALREADY_INITIALIZED")) {
            throw error;
        }
        registryNftId = await registry["getNftId(address)"](registryAddress);
    }

    logger.info(`Registry initialized with ChainNft @ ${chainNftAddress}. RegistryNftId: ${registryNftId}`);
    return {
        registryAddress,
        registryNftId,
        chainNftAddress,
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
