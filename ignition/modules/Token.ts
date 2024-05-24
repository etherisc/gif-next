import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Token", (m) => {
    const dip = m.contract("Dip", []);

    const secondsLib = m.library("SecondsLib");
    const tslib = m.library("TimestampLib", {
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
    //   m.call(apollo, "launch", []);
    const ra = m.contract("RegistryAdmin", [], 
        {
            libraries: {
                TimestampLib: tslib,
                RoleIdLib: roleIdLib
            },
        }
    );

    return { dip, ra };
});
