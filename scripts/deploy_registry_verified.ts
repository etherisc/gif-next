import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {
  const signer = process.env.WALLET_MNEMONIC ? ethers.Wallet.fromPhrase(process.env.WALLET_MNEMONIC as string).connect(ethers.provider) : undefined;
  console.log("signer: " + signer?.address);

  // deploy nftIdLib
  const nftIdLib = await ethers.getContractFactory("NftIdLib", signer);
  const nftIdLibDeployed = await nftIdLib.deploy();
  const nftIdLibAdr = nftIdLibDeployed.target;
  console.log(
    `NftIdLib deployed to ${nftIdLibAdr}`
  );

  // wait for 5 confirmations
  console.log("waiting for 5 confirmations");
  await nftIdLibDeployed.deploymentTransaction()?.wait(5);
  
  // verify
  try {
    await hre.run("verify:verify", {
      address: nftIdLibAdr,
      constructorArguments: [
      ],
    });
    console.log("NftIdLib verified\n\n");
  } catch (err: any) {
    if (err.message.toLowerCase().includes("already verified")) {
      console.log("Contract is already verified!");
    } else {
      throw err;
    }
  }
  

  // deploy registry
  const registry = await ethers.deployContract("Registry", [], {
    signer,
    libraries: {
      NftIdLib: nftIdLibAdr,
    },
  });
  await registry.waitForDeployment();
  const registryAdr = registry.target;
  console.log(
    `Registry deployed to ${registryAdr}`
  );

  // wait for 5 confirmations
  console.log("waiting for 5 confirmations");
  await registry.deploymentTransaction()?.wait(5);

  // verify 
  try {
    await hre.run("verify:verify", {
      address: registryAdr,
      constructorArguments: [
      ],
    });
    console.log("Registry verified\n\n");
  } catch (err: any) {
    if (err.message.toLowerCase().includes("already verified")) {
      console.log("Contract is already verified!");
    } else {
      throw err;
    }
  }

  // deploy ChainNft
  const chainNftFactory = await ethers.getContractFactory("ChainNft", signer);
  const chainNftDeployed = await chainNftFactory.deploy(registryAdr);
  const chainNftAdr = chainNftDeployed.target;
  console.log(
    `ChainNft deployed to ${chainNftAdr}`
  );

  // wait for 5 confirmations
  console.log("waiting for 5 confirmations");
  await chainNftDeployed.deploymentTransaction()?.wait(5);

  // verify
  try {
    await hre.run("verify:verify", {
      address: chainNftAdr,
      constructorArguments: [
        registryAdr
      ],
    });
    console.log("ChainNft verified\n\n");
  } catch (err: any) {
    if (err.message.toLowerCase().includes("already verified")) {
      console.log("Contract is already verified!");
    } else {
      throw err;
    }
  }

  const registryContract = await ethers.getContractAt("Registry", registryAdr, signer);
  await registryContract.initialize(chainNftAdr);
  console.log(`Registry initialized with ChainNft @ ${chainNftAdr}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
