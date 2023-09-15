import { ethers } from "hardhat";
import { Signer } from "ethers";
import { deployContract, verifyContract } from "./deploy_helper";
import { logger } from "./logger";
import { Registry } from "../typechain-types";


async function main() {
//   const signer = process.env.WALLET_MNEMONIC ? ethers.Wallet.fromPhrase(process.env.WALLET_MNEMONIC as string).connect(ethers.provider) : undefined;
//   console.log("signer: " + signer?.address);

    const { instanceOwner, productOwner, poolOwner } = await getNamedAccounts();
    const registry = await deployRegistry(instanceOwner);
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

async function getNamedAccounts(): Promise<{ instanceOwner: Signer; productOwner: Signer; poolOwner: Signer; }> {
    const signers = await ethers.getSigners();
    const instanceOwner = signers[0];
    const productOwner = signers[1];
    const poolOwner = signers[2];
    logger.info(`instanceOwner: ${instanceOwner.address},\n productOwner: ${productOwner.address},\n poolOwner: ${poolOwner.address}`);
    return { instanceOwner, productOwner, poolOwner }; 
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    logger.error(error.message);
    process.exitCode = 1;
});




