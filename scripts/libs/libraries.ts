import { AddressLike, Signer } from "ethers";
import { deployContract } from "./deployment";
import { logger } from "../logger";

export type LibraryAddresses = {
    nftIdLibAddress: AddressLike;
    mathLibAddress: AddressLike;
    uFixedLibAddress: AddressLike;
    amountLibAddress: AddressLike;
    claimIdLibAddress: AddressLike;
    payoutIdLibAddress: AddressLike;
    objectTypeLibAddress: AddressLike;
    blockNumberLibAddress: AddressLike;
    versionLibAddress: AddressLike;
    versionPartLibAddress: AddressLike;
    timestampLibAddress: AddressLike;
    secondsLibAddress: AddressLike;
    libNftIdSetAddress: AddressLike;
    key32LibAddress: AddressLike;
    feeLibAddress: AddressLike;
    stateIdLibAddress: AddressLike;
    roleIdLibAddress: AddressLike;
    riskIdLibAddress: AddressLike;
    distributorTypeLibAddress: AddressLike;
    referralLibAddress: AddressLike;
    instanceAuthorizationsLibAddress: AddressLike;
    serviceAuthorizationsLibAddress: AddressLike;
    targetManagerLibAddress: AddressLike;
    stakeManagerLibAddress: AddressLike;
}

export const LIBRARY_ADDRESSES: Map<string, AddressLike> = new Map<string, AddressLike>();

export async function deployLibraries(owner: Signer): Promise<LibraryAddresses> {
    logger.info("======== Starting deployment of libraries ========");
    const { address: key32LibAddress } = await deployContract(
        "Key32Lib",
        "Key32Lib",
        owner);
    LIBRARY_ADDRESSES.set("Key32Lib", key32LibAddress);

    const { address: nftIdLibAddress } = await deployContract(
        "NftIdLib",
        "NftIdLib",
        owner,
        undefined, 
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("NftIdLib", nftIdLibAddress);

    const { address: uFixedLibAddress } = await deployContract(
        "UFixedLib",
        "UFixedLib",
        owner);
    LIBRARY_ADDRESSES.set("UFixedLib", uFixedLibAddress);

    const { address: amountLibAddress } = await deployContract(
        "AmountLib",
        "AmountLib",
        owner, 
        undefined,
        {
            libraries: {
                UFixedLib: uFixedLibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("AmountLib", amountLibAddress);

    const { address: claimIdLibAddress } = await deployContract(
        "ClaimIdLib",
        "ClaimIdLib",
        owner, 
        undefined,
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("ClaimIdLib", claimIdLibAddress);

    const { address: payoutIdLibAddress } = await deployContract(
        "PayoutIdLib",
        "PayoutIdLib",
        owner, 
        undefined,
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("PayoutIdLib", payoutIdLibAddress);

    const { address: mathLibAddress } = await deployContract(
        "MathLib",
        "MathLib",
        owner);
    LIBRARY_ADDRESSES.set("MathLib", mathLibAddress);

    const { address: objectTypeLibAddress } = await deployContract(
        "ObjectTypeLib",
        "ObjectTypeLib",
        owner,
        undefined,
        undefined,
        "contracts/types/ObjectType.sol:ObjectTypeLib");
    LIBRARY_ADDRESSES.set("ObjectTypeLib", objectTypeLibAddress);

    const { address: blockNumberLibAddress } = await deployContract(
        "BlocknumberLib",
        "BlocknumberLib",
        owner);
    LIBRARY_ADDRESSES.set("BlocknumberLib", blockNumberLibAddress);

    const { address: versionLibAddress } = await deployContract(
        "VersionLib",
        "VersionLib",
        owner);
    LIBRARY_ADDRESSES.set("VersionLib", versionLibAddress);

    const { address: versionPartLibAddress } = await deployContract(
        "VersionPartLib",
        "VersionPartLib",
        owner);
    LIBRARY_ADDRESSES.set("VersionPartLib", versionPartLibAddress);

    const { address: secondsLibAddress } = await deployContract(
        "SecondsLib",
        "SecondsLib",
        owner);
    LIBRARY_ADDRESSES.set("SecondsLib", secondsLibAddress);

    const { address: timestampLibAddress } = await deployContract(
        "TimestampLib",
        "TimestampLib",
        owner, 
        undefined,
        {
            libraries: {
                SecondsLib: secondsLibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("TimestampLib", timestampLibAddress);

    const { address: targetManagerLibAddress } = await deployContract(
        "TargetManagerLib",
        "TargetManagerLib",
        owner, 
        undefined,
        {
            libraries: {
                AmountLib: amountLibAddress,
                NftIdLib: nftIdLibAddress,
                SecondsLib: secondsLibAddress,
                UFixedLib: uFixedLibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("TargetManagerLib", targetManagerLibAddress);

    const { address: stakeManagerLibAddress } = await deployContract(
        "StakeManagerLib",
        "StakeManagerLib",
        owner, 
        undefined,
        {
            libraries: {
                AmountLib: amountLibAddress,
                SecondsLib: secondsLibAddress,
                TimestampLib: timestampLibAddress,
                UFixedLib: uFixedLibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("StaketManagerLib", stakeManagerLibAddress);

    const { address: stateIdLibAddress } = await deployContract(
        "StateIdLib",
        "StateIdLib",
        owner, 
        undefined,
        undefined,
        "contracts/types/StateId.sol:StateIdLib");
    LIBRARY_ADDRESSES.set("StateIdLib", stateIdLibAddress);

    const { address: libNftIdSetAddress } = await deployContract(
        "LibNftIdSet",
        "LibNftIdSet",
        owner);
    LIBRARY_ADDRESSES.set("LibNftIdSet", libNftIdSetAddress);

    const { address: roleIdLibAddress } = await deployContract(
        "RoleIdLib",
        "RoleIdLib",
        owner,
        undefined,
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("RoleIdLib", roleIdLibAddress);

    const { address: riskIdLibAddress } = await deployContract(
        "RiskIdLib",
        "RiskIdLib",
        owner,
        undefined, 
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("RiskIdLib", riskIdLibAddress);

    const { address: feeLibAddress } = await deployContract(
        "FeeLib",
        "FeeLib",
        owner,
        undefined,
        {
            libraries: {
                AmountLib: amountLibAddress,
                UFixedLib: uFixedLibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("FeeLib", feeLibAddress);

    const { address: distributorTypeLibAddress } = await deployContract(
        "DistributorTypeLib",
        "DistributorTypeLib",
        owner,
        undefined,
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("DistributorTypeLib", distributorTypeLibAddress);

    // ReferralLib
    const { address: referralLibAddress } = await deployContract(
        "ReferralLib",
        "ReferralLib",
        owner,
        undefined,
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("ReferralLib", referralLibAddress);

    const { address: instanceAuthorizationsLibAddress } = await deployContract(
        "InstanceAuthorizationsLib",
        "InstanceAuthorizationsLib",
        owner,
        undefined,
        {
            libraries: {
                RoleIdLib: roleIdLibAddress
            }
        });
    LIBRARY_ADDRESSES.set("InstanceAuthorizationsLib", instanceAuthorizationsLibAddress);

    const { address: serviceAuthorizationsLibAddress } = await deployContract(
        "ServiceAuthorizationsLib",
        "ServiceAuthorizationsLib",
        owner,
        undefined,
        {
            libraries: {
                RoleIdLib: roleIdLibAddress
            }
        });
    LIBRARY_ADDRESSES.set("ServiceAuthorizationsLib", serviceAuthorizationsLibAddress);
        
    logger.info("======== Finished deployment of libraries ========");
        
    return {
        nftIdLibAddress,
        mathLibAddress,
        uFixedLibAddress,
        amountLibAddress,
        claimIdLibAddress,
        payoutIdLibAddress,
        objectTypeLibAddress,
        blockNumberLibAddress,
        versionLibAddress,
        versionPartLibAddress,
        timestampLibAddress,
        secondsLibAddress,
        libNftIdSetAddress,
        key32LibAddress,
        feeLibAddress,
        stateIdLibAddress,
        roleIdLibAddress,
        riskIdLibAddress,
        distributorTypeLibAddress,
        referralLibAddress,
        instanceAuthorizationsLibAddress,
        serviceAuthorizationsLibAddress,
        targetManagerLibAddress,
        stakeManagerLibAddress,
    } as LibraryAddresses;
    
}