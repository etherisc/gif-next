import { expect } from "chai";
import hre, { ignition } from "hardhat";
import GifCore from "../ignition/modules/GifCore";
import { Registry, StakingManager, StakingReader, TokenRegistry } from "../typechain-types";

describe("Ignition deployment", function () {
    it("deploys all contracts", async function () {
        const {         
            dipContract, 
            registryAdminContract, 
            registryContract,
            releaseManagerContract,
            stakingManagerContract,
            stakingStoreContract,
            stakingReaderContract,
            tokenRegistryContract, 
        } = await ignition.deploy(GifCore);

        expect(await dipContract.getAddress()).to.be.properAddress;
        expect(await registryAdminContract.getAddress()).to.be.properAddress;
        expect(await registryContract.getAddress()).to.be.properAddress;
        expect(await releaseManagerContract.getAddress()).to.be.properAddress;
        expect(await stakingManagerContract.getAddress()).to.be.properAddress;
        expect(await stakingStoreContract.getAddress()).to.be.properAddress;
        expect(await stakingReaderContract.getAddress()).to.be.properAddress;
        expect(await tokenRegistryContract.getAddress()).to.be.properAddress;

        // check that the dip token address is set correctly in the token registry
        const tokenRegistry = tokenRegistryContract as unknown as TokenRegistry;
        expect(await tokenRegistry.getDipTokenAddress()).to.equal(await dipContract.getAddress());

        const stakingManager = stakingManagerContract as unknown as StakingManager;
        const stakingAddress = await stakingManager.getStaking();

        // check that staking reader has the correct addresses of registry and staking
        const stakingReader = stakingReaderContract as unknown as StakingReader;
        expect(await stakingReader.getRegistry()).to.equal(await registryContract.getAddress());
        expect(await stakingReader.getStaking()).to.equal(stakingAddress);

        // check that the registry has the correct number of objects (4 - protocol, global registry, registry, staking)
        const registry = registryContract as unknown as Registry;
        expect(await registry.getObjectCount()).to.equal(4, "registry should have 4 objects");


        const protocolNftId = "1101";
        const globalRegistryNftId = "2101";
        
        // check that the registry has the correct nftid (2nd nft)
        const registryNftId = calculateNftID(2);
        expect(await registry["getNftId()"]()).to.equal(registryNftId, "registry nftid invalid");
        expect(await registry.getProtocolNftId()).to.equal(protocolNftId, "protocol nftid invalid");
        await expectParentNftId(registry, registryNftId, globalRegistryNftId);

        // check that the staking contract has the correct registry and nftid (3rd nft)        
        const staking = await hre.ethers.getContractAt("Staking", stakingAddress);
        expect(await staking.getRegistry()).to.equal(await registryContract.getAddress());
        const stakingNftId = calculateNftID(3);
        expect(await staking.getNftId()).to.equal(stakingNftId, "staking nftid invalid");
        expectParentNftId(registry, stakingNftId, registryNftId);
        
        // check that the registry contains an entry for the global registry (nft id 2101) with address 0x and its parent is the protocol nft id
        const { objectAddress, parentNftId } = await registry["getObjectInfo(uint96)"](globalRegistryNftId);
        expect(objectAddress).to.equal("0x0000000000000000000000000000000000000000");
        expect(parentNftId).to.equal(protocolNftId);

        // check that the parent nft id of the protocol nft id is 0
        await expectParentNftId(registry, protocolNftId, "0");
    });
});

function calculateNftID(nftNum: number): string {
    const chainId = hre.network.config.chainId || 1;
    const chainIdLength = chainId.toString().length.toString().padStart(2, "0");
    return `${nftNum}${chainId}${chainIdLength}`;
}

async function expectParentNftId(registry: Registry, nftId: string, expectedParentNftId: string) {
    const { parentNftId: registryParentNftId } = await registry["getObjectInfo(uint96)"](nftId);
    expect(registryParentNftId).to.equal(expectedParentNftId, "parent nftid invalid");
}