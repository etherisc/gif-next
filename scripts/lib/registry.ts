import { AddressLike, Signer } from "ethers";
import { Registry__factory } from "../../typechain-types";
import { logger } from "../logger";

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