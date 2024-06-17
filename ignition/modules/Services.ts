// const { address: stakingServiceManagerAddress, contract: stakingServiceManagerBaseContract, } = await deployContract(
//     "StakingServiceManager",
//     owner,
//     [
//         release.accessManager,
//         registry.registryAddress,
//         release.salt
//     ],
//     { libraries: {
//         AmountLib: libraries.amountLibAddress,
//         NftIdLib: libraries.nftIdLibAddress,
//         TimestampLib: libraries.timestampLibAddress,
//         VersionLib: libraries.versionLibAddress, 
//         VersionPartLib: libraries.versionPartLibAddress,
//         TargetManagerLib: libraries.targetManagerLibAddress,
//     }});


import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Services", (m) => {
    const amountLib = m.contractAt("AmountLib", m.getParameter("amountLibAddress"));
    const nftIdLib = m.contractAt("NftIdLib", m.getParameter("nftIdLibAddress"));
    const timestampLib = m.contractAt("TimestampLib", m.getParameter("timestampLibAddress"));
    const versionLib = m.contractAt("VersionLib", m.getParameter("versionLibAddress"));
    const versionPartLib = m.contractAt("VersionPartLib", m.getParameter("versionPartLibAddress"));
    const targetManagerLib = m.contractAt("TargetManagerLib", m.getParameter("targetManagerLibAddress"));    

    const stakingServiceManagerFuture = m.contract("StakingServiceManager", [
        m.getParameter("accessManager"),
        m.getParameter("registryAddress"),
        m.getParameter("salt")
    ], 
    {
        libraries: {
            AmountLib: amountLib,
            NftIdLib: nftIdLib,
            TimestampLib: timestampLib,
            VersionLib: versionLib,
            VersionPartLib: versionPartLib,
            TargetManagerLib: targetManagerLib,
        },
        from: m.getAccount(0) // TODO: make this configurable
    });

    return { stakingServiceManagerFuture };
});
