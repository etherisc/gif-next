import { AddressLike, Signer, ethers, getAddress, resolveAddress } from "ethers";
import * as iERC721Abi  from "../../artifacts/@openzeppelin/contracts/token/ERC721/IERC721.sol/IERC721.json";
import { Instance__factory } from "../../typechain-types";
import { getFieldFromLogs } from "./transaction";
import { logger } from "../logger";

const IERC721ABI = new ethers.Interface(iERC721Abi.abi);

export async function registerInstance(instanceOwner: Signer, instanceAddress: AddressLike): Promise<any> {    
    logger.debug(`registering instance ${instanceAddress}`);
    // register instance
    const instanceAsInstanceOwner = Instance__factory.connect(instanceAddress.toString(), instanceOwner);
    const instanceRestrationTxResponse = await instanceAsInstanceOwner.register();
    const tx = await instanceRestrationTxResponse.wait();
    
    if (tx === null) {
        throw new Error("instance registration tx is null");
    }
    if (tx.status !== 1) {
        throw new Error("instance registration tx failed");
    }

    const instanceNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    logger.info(`Instance registered with NFT ID: ${instanceNftId}`);
    return instanceNftId;
}

export enum Role { POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE }

export async function grantRole(instanceOwner: Signer, instanceAddress: AddressLike, role: Role, beneficiary: AddressLike): Promise<any> {
    const beneficiaryAddress = await resolveAddress(beneficiary);
    logger.debug(`granting role ${Role[role]} to ${beneficiaryAddress}`);
    const instanceAsInstanceOwner = Instance__factory.connect(instanceAddress.toString(), instanceOwner);
    
    let roleValue;
    if (role === Role.POOL_OWNER_ROLE) {
        roleValue = await instanceAsInstanceOwner.POOL_OWNER_ROLE();
    } else if (role === Role.PRODUCT_OWNER_ROLE) {
        roleValue = await instanceAsInstanceOwner.PRODUCT_OWNER_ROLE();
    } else {
        throw new Error("unknown role");
    }

    const tx2Resp = await instanceAsInstanceOwner.grantRole(roleValue, beneficiaryAddress);
    const tx2 = await tx2Resp.wait();
    if (tx2?.status !== 1) {
        throw new Error("grant role failed");
    }
    logger.info(`Granted role ${roleValue} to ${beneficiaryAddress}`);
}