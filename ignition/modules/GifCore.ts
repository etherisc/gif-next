import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import LibraryModule from "./Libraries";

export default buildModule("GifCore", (m) => {
    const stakingOwner = m.getAccount(0);

    const { 
        amountLib,
        blocknumberLib,
        key32Lib,
        nftIdLib,
        nftIdSetLib, 
        objectTypeLib,
        roleIdLib, 
        secondsLib,
        stakeManagerLib,
        stateIdLib,
        targetManagerLib,
        timestamplib, 
        uFixedLib,
        versionLib,
        versionPartLib,
    } = m.useModule(LibraryModule);

    // 1) deploy dip token
    const dip = m.contract("Dip", []);
    
    // 2) deploy registry admin
    const registryAdmin = m.contract("RegistryAdmin", [], 
        {
            libraries: {
                TimestampLib: timestamplib,
                RoleIdLib: roleIdLib,
            },
        }
    );

    const registry = m.contract("Registry", 
        [registryAdmin],
        {
            libraries: {
                NftIdLib: nftIdLib,
                ObjectTypeLib: objectTypeLib,
            },
        }
    );

    const releaseManager = m.contract("ReleaseManager",
        [registry],
        {
            libraries: {
                NftIdLib: nftIdLib,
                RoleIdLib: roleIdLib,
                SecondsLib: secondsLib,
                TimestampLib: timestamplib,
                VersionLib: versionLib,
                VersionPartLib: versionPartLib,
            },
        }
    );

    const tokenRegistry = m.contract("TokenRegistry",
        [registry, dip],
        {
            libraries: {
                VersionPartLib: versionPartLib,
            },
        }
    );

    const stakingReader = m.contract("StakingReader",
        [registry],
        {
            libraries: {
                NftIdLib: nftIdLib,
            },
        }
    );

    const stakingStore = m.contract("StakingStore",
        [registry, stakingReader],
        {
            libraries: {
                AmountLib: amountLib,
                BlocknumberLib: blocknumberLib,
                Key32Lib: key32Lib,
                LibNftIdSet: nftIdSetLib,
                NftIdLib: nftIdLib,
                ObjectTypeLib: objectTypeLib,
                StateIdLib: stateIdLib,
                TimestampLib: timestamplib,
                UFixedLib: uFixedLib,
            },
        }
    );

    const stakingManager = m.contract("StakingManager",
        [registry, tokenRegistry, stakingStore, stakingOwner],
        {
            libraries: {
                AmountLib: amountLib,
                NftIdLib: nftIdLib,
                StakeManagerLib: stakeManagerLib,
                TargetManagerLib: targetManagerLib,
                TimestampLib: timestamplib,
                VersionLib: versionLib,
            },
        }
    );

    return { 
        dip, 
        registryAdmin, 
        registry,
        releaseManager,
        stakingManager,
        stakingStore,
        stakingReader,
        tokenRegistry,
    };
});
