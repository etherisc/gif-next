import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Libraries", (m) => {
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

    return { secondsLib, tslib, key32Lib, roleIdLib };
});
