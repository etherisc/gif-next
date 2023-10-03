import { AddressLike, Signer } from "ethers";
import { deployContract } from "./deployment";

export type LibraryAddresses = {
    nftIdLibAddress: AddressLike;
    uFixedMathLibAddress: AddressLike;
    objectTypeLibAddress: AddressLike;
    blockNumberLibAddress: AddressLike;
    versionLibAddress: AddressLike;
    versionPartLibAddress: AddressLike;
    timestampLibAddress: AddressLike;
    libNftIdSetAddress: AddressLike;
    key32LibAddress: AddressLike;
    feeLibAddress: AddressLike;
    stateIdLibAddress: AddressLike;
    roleIdLibAddress: AddressLike;
}

export const LIBRARY_ADDRESSES: Map<string, AddressLike> = new Map<string, AddressLike>();

export async function deployLibraries(owner: Signer): Promise<LibraryAddresses> {
    const { address: key32LibAddress } = await deployContract(
        "Key32Lib",
        owner);
    LIBRARY_ADDRESSES.set("Key32Lib", key32LibAddress);

    const { address: nftIdLibAddress } = await deployContract(
        "NftIdLib",
        owner,
        undefined, 
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("NftIdLib", nftIdLibAddress);

    const { address: uFixedMathLibAddress } = await deployContract(
        "UFixedMathLib",
        owner);
    LIBRARY_ADDRESSES.set("UFixedMathLib", uFixedMathLibAddress);

    const { address: objectTypeLibAddress } = await deployContract(
        "ObjectTypeLib",
        owner,
        undefined,
        undefined,
        "contracts/types/ObjectType.sol:ObjectTypeLib");
    LIBRARY_ADDRESSES.set("ObjectTypeLib", objectTypeLibAddress);

    const { address: blockNumberLibAddress } = await deployContract(
        "BlocknumberLib",
        owner);
    LIBRARY_ADDRESSES.set("BlocknumberLib", blockNumberLibAddress);

    const { address: versionLibAddress } = await deployContract(
        "VersionLib",
        owner);
    LIBRARY_ADDRESSES.set("VersionLib", versionLibAddress);

    const { address: versionPartLibAddress } = await deployContract(
        "VersionPartLib",
        owner);
    LIBRARY_ADDRESSES.set("VersionPartLib", versionPartLibAddress);

    const { address: timestampLibAddress } = await deployContract(
        "TimestampLib",
        owner);
    LIBRARY_ADDRESSES.set("TimestampLib", timestampLibAddress);

    const { address: stateIdLibAddress } = await deployContract(
        "StateIdLib",
        owner, 
        undefined,
        undefined,
        "contracts/types/StateId.sol:StateIdLib");
    LIBRARY_ADDRESSES.set("StateIdLib", stateIdLibAddress);

    const { address: libNftIdSetAddress } = await deployContract(
        "LibNftIdSet",
        owner);
    LIBRARY_ADDRESSES.set("LibNftIdSet", libNftIdSetAddress);

    const { address: roleIdLibAddress } = await deployContract(
        "RoleIdLib",
        owner);
    LIBRARY_ADDRESSES.set("RoleIdLib", roleIdLibAddress);

    const { address: feeLibAddress } = await deployContract(
        "FeeLib",
        owner,
        undefined,
        {
            libraries: {
                UFixedMathLib: uFixedMathLibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("FeeLib", feeLibAddress);

    return {
        nftIdLibAddress,
        uFixedMathLibAddress,
        objectTypeLibAddress,
        blockNumberLibAddress,
        versionLibAddress,
        versionPartLibAddress,
        timestampLibAddress,
        libNftIdSetAddress,
        key32LibAddress,
        feeLibAddress,
        stateIdLibAddress,
        roleIdLibAddress,
    };
    
}