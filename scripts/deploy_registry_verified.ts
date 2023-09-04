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
  await hre.run("verify:verify", {
    address: nftIdLibAdr,
    constructorArguments: [
    ],
  });
  console.log("NftIdLib verified\n\n");
  

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
  await hre.run("verify:verify", {
    address: registryAdr,
    constructorArguments: [
    ],
  });
  console.log("Registry verified\n\n");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
