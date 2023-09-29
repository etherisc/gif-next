import { AddressLike, Signer } from "ethers";
import { deployContract } from "./deployment";

export type LibraryAddresses = {
    nfIdLibAddress: AddressLike;
    uFixedMathLibAddress: AddressLike;
    objectTypeLibAddress: AddressLike;
    blockNumberLibAddress: AddressLike;
    versionLibAddress: AddressLike;
    versionPartLibAddress: AddressLike;
    timestampLibAddress: AddressLike;
    libNftIdSetAddress: AddressLike;
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
    const { address: blockNumberLibAddress } = await deployContract(
        "BlocknumberLib",
        owner);
    const { address: versionLibAddress } = await deployContract(
        "VersionLib",
        owner);
    const { address: versionPartLibAddress } = await deployContract(
        "VersionPartLib",
        owner);
    const { address: timestampLibAddress } = await deployContract(
        "TimestampLib",
        owner);
    const { address: libNftIdSetAddress } = await deployContract(
        "LibNftIdSet",
        owner);
        

    return {
        nfIdLibAddress,
        uFixedMathLibAddress,
        objectTypeLibAddress,
        blockNumberLibAddress,
        versionLibAddress,
        versionPartLibAddress,
        timestampLibAddress,
        libNftIdSetAddress,
    };
    
}