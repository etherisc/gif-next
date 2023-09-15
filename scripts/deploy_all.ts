import { ethers } from "hardhat";
import { Signer } from "ethers";
import { deployContract, verifyContract } from "./deploy_helper";
import { logger } from "./logger";


async function main() {
//   const signer = process.env.WALLET_MNEMONIC ? ethers.Wallet.fromPhrase(process.env.WALLET_MNEMONIC as string).connect(ethers.provider) : undefined;
//   console.log("signer: " + signer?.address);

    const { instanceOwner, productOwner, poolOwner } = await getNamedAccounts();
    
    const { address: nfIdLibAddress } = await deployContract(
        "NftIdLib", 
        instanceOwner);
    const { address: registryAddress } = await deployContract(
        "Registry", 
        instanceOwner, 
        { 
            libraries: {
                NftIdLib: nfIdLibAddress,
            }
        });





//   // deploy ChainNft
//   const chainNftFactory = await ethers.getContractFactory("ChainNft", signer);
//   const chainNftDeployed = await chainNftFactory.deploy(registryAdr);
//   const chainNftAdr = chainNftDeployed.target;
//   console.log(
//     `ChainNft deployed to ${chainNftAdr}`
//   );

//   // wait for 5 confirmations
//   console.log("waiting for 5 confirmations");
//   await chainNftDeployed.deploymentTransaction()?.wait(5);

//   await verifyContract(chainNftAdr, [registryAdr]);

//   const registryContract = await ethers.getContractAt("Registry", registryAdr, signer);
//   await registryContract.initialize(chainNftAdr);
//   console.log(`Registry initialized with ChainNft @ ${chainNftAdr}`);
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




