import { AddressLike, Signer } from "ethers";
import fs from 'fs';
import hre from 'hardhat';
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { deploymentsBaseDirectory, isTestChain } from "./deployment_state";

export type LibraryAddresses = {
    nftIdLibAddress: AddressLike;
    uFixedLibAddress: AddressLike;
    amountLibAddress: AddressLike;
    claimIdLibAddress: AddressLike;
    payoutIdLibAddress: AddressLike;
    objectTypeLibAddress: AddressLike;
    blockNumberLibAddress: AddressLike;
    contractLibAddress: AddressLike;
    versionLibAddress: AddressLike;
    versionPartLibAddress: AddressLike;
    timestampLibAddress: AddressLike;
    secondsLibAddress: AddressLike;
    libNftIdSetAddress: AddressLike;
    key32LibAddress: AddressLike;
    libKey32SetAddress: AddressLike;
    feeLibAddress: AddressLike;
    stateIdLibAddress: AddressLike;
    roleIdLibAddress: AddressLike;
    riskIdLibAddress: AddressLike;
    distributorTypeLibAddress: AddressLike;
    referralLibAddress: AddressLike;
    requestIdLibAddress: AddressLike;
    targetManagerLibAddress: AddressLike;
    stakeManagerLibAddress: AddressLike;
    selectorLibAddress: AddressLike;
    selectorSetLibAddress: AddressLike;
    strLibAddress: AddressLike;
    tokenHandlerDeployerLibAddress: AddressLike;
    objectSetHelperLibAddress: AddressLike;
}

export const LIBRARY_ADDRESSES: Map<string, AddressLike> = new Map<string, AddressLike>();

export async function deployLibraries(owner: Signer): Promise<LibraryAddresses> {
    logger.info("======== Starting deployment of libraries ========");

    const { address: versionLibAddress } = await deployContract(
        "VersionLib",
        owner);
    LIBRARY_ADDRESSES.set("VersionLib", versionLibAddress);

    const { address: versionPartLibAddress } = await deployContract(
        "VersionPartLib",
        owner);
    LIBRARY_ADDRESSES.set("VersionPartLib", versionPartLibAddress);

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

    const { address: uFixedLibAddress } = await deployContract(
        "UFixedLib",
        owner);
    LIBRARY_ADDRESSES.set("UFixedLib", uFixedLibAddress);

    const { address: amountLibAddress } = await deployContract(
        "AmountLib",
        owner, 
        undefined,
        {
            libraries: {
                UFixedLib: uFixedLibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("AmountLib", amountLibAddress);

    const { address: objectTypeLibAddress } = await deployContract(
        "ObjectTypeLib",
        owner,
        undefined,
        undefined);
    LIBRARY_ADDRESSES.set("ObjectTypeLib", objectTypeLibAddress);

    const { address: roleIdLibAddress } = await deployContract(
        "RoleIdLib",
        owner,
        undefined,
        {
            libraries: {
                ObjectTypeLib: objectTypeLibAddress,
                Key32Lib: key32LibAddress,
                VersionPartLib: versionPartLibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("RoleIdLib", roleIdLibAddress);

    const { address: claimIdLibAddress } = await deployContract(
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
        owner, 
        undefined,
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("PayoutIdLib", payoutIdLibAddress);

    const { address: blockNumberLibAddress } = await deployContract(
        "BlocknumberLib",
        owner);
    LIBRARY_ADDRESSES.set("BlocknumberLib", blockNumberLibAddress);

    const { address: contractLibAddress } = await deployContract(
        "ContractLib",
        owner,
        undefined,
        {
            libraries: {
                NftIdLib: nftIdLibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("ContractLib", contractLibAddress);

    const { address: secondsLibAddress } = await deployContract(
        "SecondsLib",
        owner);
    LIBRARY_ADDRESSES.set("SecondsLib", secondsLibAddress);

    const { address: timestampLibAddress } = await deployContract(
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
    LIBRARY_ADDRESSES.set("StakeManagerLib", stakeManagerLibAddress);

    const { address: stateIdLibAddress } = await deployContract(
        "StateIdLib",
        owner, 
        undefined,
        undefined,
        "contracts/type/StateId.sol:StateIdLib");
    LIBRARY_ADDRESSES.set("StateIdLib", stateIdLibAddress);

    const { address: libNftIdSetAddress } = await deployContract(
        "LibNftIdSet",
        owner);
    LIBRARY_ADDRESSES.set("LibNftIdSet", libNftIdSetAddress);

    const { address: libKey32SetAddress } = await deployContract(
        "LibKey32Set",
        owner);
    LIBRARY_ADDRESSES.set("LibKey32Set", libKey32SetAddress);

    const { address: riskIdLibAddress } = await deployContract(
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
        owner,
        undefined,
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("ReferralLib", referralLibAddress);

    // RequestId
    const { address: requestIdLibAddress } = await deployContract(
        "RequestIdLib",
        owner,
        undefined,
        {
            libraries: {
                Key32Lib: key32LibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("RequestIdLib", requestIdLibAddress);

    const { address: selectorLibAddress } = await deployContract(
        "SelectorLib",
        owner,
        undefined,
        {
            libraries: {
                // ObjectTypeLib: objectTypeLibAddress,
                // RoleIdLib: roleIdLibAddress
            }
        });
    LIBRARY_ADDRESSES.set("SelectorLib", selectorLibAddress);

    const { address: selectorSetLibAddress } = await deployContract(
        "SelectorSetLib",
        owner,
        undefined,
        {
            libraries: {
                // ObjectTypeLib: objectTypeLibAddress,
                // RoleIdLib: roleIdLibAddress
            }
        });
    LIBRARY_ADDRESSES.set("SelectorSetLib", selectorSetLibAddress);

    const { address: strLibAddress } = await deployContract(
        "StrLib",
        owner,
        undefined,
        {
            libraries: {
                // ObjectTypeLib: objectTypeLibAddress,
                // RoleIdLib: roleIdLibAddress
            }
        });
    LIBRARY_ADDRESSES.set("StrLib", strLibAddress);

    const { address: tokenHandlerDeployerLibAddress } = await deployContract(
        "TokenHandlerDeployerLib",
        owner,
        undefined,
        {
            libraries: {
                AmountLib: amountLibAddress,
                ContractLib: contractLibAddress,
                NftIdLib: nftIdLibAddress,
            }
        });
    LIBRARY_ADDRESSES.set("TokenHandlerDeployerLib", tokenHandlerDeployerLibAddress);

    const { address: objectSetHelperLibAddress } = await deployContract(
        "ObjectSetHelperLib",
        owner);
    LIBRARY_ADDRESSES.set("ObjectSetHelperLib", objectSetHelperLibAddress);
        
    logger.info("======== Finished deployment of libraries ========");

    dumpLibraryAddressesToFile(LIBRARY_ADDRESSES);
        
    return {
        nftIdLibAddress,
        uFixedLibAddress,
        amountLibAddress,
        contractLibAddress,
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
        libKey32SetAddress,
        feeLibAddress,
        stateIdLibAddress,
        roleIdLibAddress,
        riskIdLibAddress,
        distributorTypeLibAddress,
        referralLibAddress,
        requestIdLibAddress,
        targetManagerLibAddress,
        stakeManagerLibAddress,
        selectorLibAddress,
        selectorSetLibAddress,
        strLibAddress,
        tokenHandlerDeployerLibAddress,
        objectSetHelperLibAddress,
    };
    
}

function dumpLibraryAddressesToFile(addresses: Map<string, AddressLike>): void {
    if (isTestChain()) {
        return;
    }
    const data = JSON.stringify(Object.fromEntries(addresses), null, 2);
    fs.writeFileSync(deploymentsBaseDirectory() + `libraries_${hre.network.config.chainId}.json`, data);
}

export function loadLibraryAddressesFromFile() {
    const json = fs.readFileSync(deploymentsBaseDirectory() + `libraries_${hre.network.config.chainId}.json`);
    // logger.info(`Loaded libraries from file: ${json}`);
    const libraries = JSON.parse(json.toString());
    for (const key in libraries) {
        // logger.debug(`Loaded library ${key} at ${libraries[key]}`);
        LIBRARY_ADDRESSES.set(key, libraries[key]);
    }
}

