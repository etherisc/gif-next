import hre from "hardhat";
import TokenModule from "../ignition/modules/Token";

async function main() {
    const { dip } = await hre.ignition.deploy(TokenModule, {
        strategy: "create2",
        strategyConfig: {
            salt: "0x0000000000000000000000000000000000000000000000000000000000000002"
        }
    });

    console.log(`Dip deployed to: ${await dip.getAddress()}`);
}

main().catch(console.error);