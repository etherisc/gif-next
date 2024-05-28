import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import LibraryModule from "./Libraries";

export default buildModule("GifCore", (m) => {
    const gifAdmin = m.getAccount(0);
    const gifManager = m.getAccount(0);
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
    const registryAdmin = m.contract("RegistryAdmin", [stakingOwner], 
        {
            libraries: {
                TimestampLib: timestamplib,
                RoleIdLib: roleIdLib,
            },
        }
    );

    // 3) deploy registry
    const registry = m.contract("Registry", 
        [registryAdmin, stakingOwner],
        {
            libraries: {
                NftIdLib: nftIdLib,
                ObjectTypeLib: objectTypeLib,
            },
        }
    );

    // 4) deploy release manager
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

    // 5) deploy token registry
    const tokenRegistry = m.contract("TokenRegistry",
        [registry, dip],
        {
            libraries: {
                VersionPartLib: versionPartLib,
            },
        }
    );

    // 6) deploy staking reader
    const stakingReader = m.contract("StakingReader",
        [registry, stakingOwner],
        {
            libraries: {
                NftIdLib: nftIdLib,
            },
        }
    );

    // 7) deploy staking store
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

    // 8) deploy staking manager and staking component
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

    const stakingAddress = m.staticCall(stakingManager, "getStaking");
    const staking = m.contractAt("Staking", stakingAddress);

    // 9) initialize instance reader
    const stakingReaderInitialize = m.call(stakingReader, "initialize", [staking, stakingStore], {
        after: [staking],
    });

    // 10) intialize registry and register staking component
    const registryInitialize = m.call(registry, "initialize", [releaseManager, tokenRegistry, staking], {
        after: [stakingReaderInitialize],
    });
    const stakingLinkToRegisteredNftId = m.call(staking, "linkToRegisteredNftId", [], {
        after: [registryInitialize],
    });

    // 11) initialize registry admin
    m.call(registryAdmin, "initialize", [registry, gifAdmin, gifManager], {
        after: [stakingLinkToRegisteredNftId]
    });

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
