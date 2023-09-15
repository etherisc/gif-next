import { ethers } from "hardhat";
import { Signer, formatEther } from "ethers";
import { deployContract, verifyContract } from "./lib/deployment";
import { logger } from "./logger";
import { Registry } from "../typechain-types";
import { getNamedAccounts, printBalance } from "./lib/accounts";


async function main() {
    const { instanceOwner, productOwner, poolOwner } = await getNamedAccounts();
    const registry = await deployRegistry(instanceOwner);
    printBalance(
        ["instanceOwner", instanceOwner] , 
        ["productOwner", productOwner], 
        ["poolOwner", poolOwner]);
    }

async function deployRegistry(owner: Signer): Promise<Registry> {
    const { address: nfIdLibAddress } = await deployContract(
        "NftIdLib",
        owner);
    const { address: registryAddress, contract: registryBaseContract } = await deployContract(
        "Registry",
        owner,
        undefined,
        {
            libraries: {
                NftIdLib: nfIdLibAddress,
            }
        });
    const { address: chainNftAddress } = await deployContract(
        "ChainNft",
        owner,
        [registryAddress]);

    const registry = registryBaseContract as Registry;
    await registry.initialize(chainNftAddress);
    logger.info(`Registry initialized with ChainNft @ ${chainNftAddress}`);

    return registry;
}


main().catch((error) => {
    logger.error(error.message);
    process.exitCode = 1;
});




