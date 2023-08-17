import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Dip", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deploy() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const DIP = await ethers.getContractFactory("DIP");
    const dip = await DIP.deploy();

    return { dip, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should have 18 decimals", async function () {
      const { dip } = await loadFixture(deploy);

      expect(await dip.decimals()).to.equal(18);
    });
  });
});
