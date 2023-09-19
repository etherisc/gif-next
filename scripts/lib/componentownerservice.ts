import { AddressLike, Signer, ethers } from "ethers";
import { ComponentOwnerService__factory } from "../../typechain-types";
import { getFieldFromLogs } from "./transaction";
import { logger } from "../logger";
import * as iERC721Abi  from "../../artifacts/@openzeppelin/contracts/token/ERC721/IERC721.sol/IERC721.json";

const IERC721ABI = new ethers.Interface(iERC721Abi.abi);

export async function registerComponent(componentOwnerServiceAddress: AddressLike, signer: Signer, componentAddress: AddressLike): Promise<any> {
    logger.debug(`registering component ${componentAddress}`);

    // register component
    const componentOwnerService = ComponentOwnerService__factory.connect(componentOwnerServiceAddress.toString(), signer);
    const componentRegistrationTxResponse = await componentOwnerService.register(componentAddress);
    const tx = await componentRegistrationTxResponse.wait();
    
    if (tx === null) {
        throw new Error("component registration tx is null");

    }
    if (tx.status !== 1) {
        throw new Error("instance registration tx failed");
    }

    const componentNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    logger.info(`Component registered with NFT ID: ${componentNftId}`);
    return componentNftId;
}
