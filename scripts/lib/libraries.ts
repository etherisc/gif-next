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

export async function deployLibraries(owner: Signer): Promise<LibraryAddresses> {
    const { address: key32LibAddress } = await deployContract(
        "Key32Lib",
        owner);
    const { address: nftIdLibAddress } = await deployContract(
        "NftIdLib",
        owner,
        undefined, 
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    const { address: uFixedMathLibAddress } = await deployContract(
        "UFixedMathLib",
        owner);
    const { address: objectTypeLibAddress } = await deployContract(
        "ObjectTypeLib",
        owner,
        undefined,
        undefined,
        "contracts/types/ObjectType.sol:ObjectTypeLib");
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
    const { address: stateIdLibAddress } = await deployContract(
        "StateIdLib",
        owner, 
        undefined,
        undefined,
        "contracts/types/StateId.sol:StateIdLib");
    const { address: libNftIdSetAddress } = await deployContract(
        "LibNftIdSet",
        owner);
    const { address: roleIdLibAddress } = await deployContract(
        "RoleIdLib",
        owner);
    const { address: feeLibAddress } = await deployContract(
        "FeeLib",
        owner,
        undefined,
        {
            libraries: {
                UFixedMathLib: uFixedMathLibAddress,
            }
        });

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