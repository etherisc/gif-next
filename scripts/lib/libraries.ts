import { AddressLike, Signer } from "ethers";
import { deployContract } from "./deployment";

export type LibraryAddresses = {
    nfIdLibAddress: AddressLike;
    uFixedMathLibAddress: AddressLike;
    objectTypeLibAddress: AddressLike;
}

export async function deployLibraries(owner: Signer): Promise<LibraryAddresses> {
    const { address: nfIdLibAddress } = await deployContract(
        "NftIdLib",
        owner);
    const { address: uFixedMathLibAddress } = await deployContract(
        "UFixedMathLib",
        owner);
    const { address: objectTypeLibAddress } = await deployContract(
        "ObjectTypeLib",
        owner);

    return {
        nfIdLibAddress,
        uFixedMathLibAddress,
        objectTypeLibAddress,
    };
    
}