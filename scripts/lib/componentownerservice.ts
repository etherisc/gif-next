import { AddressLike, Signer, ethers } from "ethers";
import * as iERC721Abi from "../../artifacts/@openzeppelin/contracts/token/ERC721/IERC721.sol/IERC721.json";
import { ComponentOwnerService__factory } from "../../typechain-types";
import { logger } from "../logger";
import { executeTx, getFieldFromLogs } from "./transaction";
import { isRegistered } from "./registry";

const IERC721ABI = new ethers.Interface(iERC721Abi.abi);

export async function registerComponent(componentOwnerServiceAddress: AddressLike, signer: Signer, componentAddress: AddressLike, registryAddress: AddressLike): Promise<any> {
    logger.debug(`registering component ${componentAddress}`);

    let componentNftId = await isRegistered(signer, registryAddress, componentAddress);

    if (componentNftId !== null) {
        return componentNftId;
    }

    // register component
    const componentOwnerService = ComponentOwnerService__factory.connect(componentOwnerServiceAddress.toString(), signer);
    const tx = await executeTx(async () => await componentOwnerService.register(componentAddress));
    componentNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    logger.info(`Component registered with NFT ID: ${componentNftId}`);
    return componentNftId;
}
