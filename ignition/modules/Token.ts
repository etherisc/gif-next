import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import LibraryModule from "./Libraries";

export default buildModule("Token", (m) => {
    const { roleIdLib, timestamplib } = m.useModule(LibraryModule);

    const dip = m.contract("Dip", []);

    //   m.call(apollo, "launch", []);
    const ra = m.contract("RegistryAdmin", [], 
        {
            libraries: {
                TimestampLib: timestamplib,
                RoleIdLib: roleIdLib
            },
        }
    );

    return { dip, ra };
});
