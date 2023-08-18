import { ethers } from "hardhat";

async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60;

  const lockedAmount = ethers.parseEther("0.001");
  const signer = process.env.WALLET_MNEMONIC ? ethers.Wallet.fromPhrase(process.env.WALLET_MNEMONIC as string).connect(ethers.provider) : undefined;
  console.log("signer: " + signer?.address);

  const lock = await ethers.deployContract("Lock", [unlockTime], {
    value: lockedAmount,
    signer,
  });

  await lock.waitForDeployment();

  console.log(
    `Lock with ${ethers.formatEther(
      lockedAmount
    )}ETH and unlock timestamp ${unlockTime} deployed to ${lock.target}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
