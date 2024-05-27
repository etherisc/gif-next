import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Libraries", (m) => {
    const secondsLib = m.library("SecondsLib");
    const timestamplib = m.library("TimestampLib", {
        libraries: {
            SecondsLib: secondsLib
        }
    });
    const key32Lib = m.library("Key32Lib");
    const roleIdLib = m.library("RoleIdLib", {
        libraries: {
            Key32Lib: key32Lib
        },
    });
    const nftIdLib = m.library("NftIdLib", {
        libraries: {
            Key32Lib: key32Lib
        },
    });
    const objectTypeLib = m.library("ObjectTypeLib");
    const versionLib = m.library("VersionLib");
    const versionPartLib = m.library("VersionPartLib");
    const blocknumberLib = m.library("BlocknumberLib");
    const nftIdSetLib = m.library("LibNftIdSet");
    const stateIdLib = m.library("StateIdLib");
    const uFixedLib = m.library("UFixedLib");
    const amountLib = m.library("AmountLib", {
        libraries: {
            UFixedLib: uFixedLib
        }  
    });
    const targetManagerLib = m.library("TargetManagerLib", {
        libraries: {
            AmountLib: amountLib,
            NftIdLib: nftIdLib,
            SecondsLib: secondsLib,
            UFixedLib: uFixedLib
        }
    });
    const stakeManagerLib = m.library("StakeManagerLib", {
        libraries: {
            AmountLib: amountLib,
            SecondsLib: secondsLib,
            TimestampLib: timestamplib,
            UFixedLib: uFixedLib
        }
    
    });

    return { 
        amountLib,
        blocknumberLib,
        key32Lib, 
        nftIdLib,
        nftIdSetLib,
        objectTypeLib,
        stateIdLib,
        roleIdLib,
        secondsLib, 
        stakeManagerLib,
        targetManagerLib,
        timestamplib, 
        uFixedLib,
        versionLib,
        versionPartLib,
    };
});
