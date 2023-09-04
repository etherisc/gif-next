import hre from "hardhat";
import { AddressLike } from "ethers";

export async function verifyContract(address: AddressLike, constructorArgs: any[]) {
    console.log("verifying contract @ address: " + address);
    // console.log("args: " + args);
    try {
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: constructorArgs,
        });
        console.log("Contract verified\n\n");
    } catch (err: any) {
        if (err.message.toLowerCase().includes("already verified")) {
            console.log("Contract is already verified! \n\n");
        } else {
            throw err;
        }
    }
};
