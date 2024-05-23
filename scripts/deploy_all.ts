import { AddressLike, resolveAddress } from "ethers";
import { ethers } from "hardhat";
import { ChainNft__factory, IRegistry__factory } from "../typechain-types";
import { getNamedAccounts, printBalance, validateNftOwnerhip } from "./libs/accounts";
import { LibraryAddresses, deployLibraries } from "./libs/libraries";
import { CoreAddresses, deployCore } from "./libs/registry";
import { logger } from "./logger";
import { InstanceAddresses, MASTER_INSTANCE_OWNER, cloneInstance, deployAndRegisterMasterInstance, verifyInstance } from "./libs/instance";
import { ServiceAddresses, authorizeServices, deployRelease } from "./libs/services";
import { deploymentState, isResumeableDeployment } from "./libs/deployment_state";


async function main() {
    console.info("Resumeable deployment?", isResumeableDeployment);

    logger.info("deploying new GIF instance...");
    const { protocolOwner, masterInstanceOwner, instanceOwner } = await getNamedAccounts();

    // deploy protocol contracts
    const libraries = await deployLibraries(protocolOwner);
    const core = await deployCore(protocolOwner, libraries);
    const services = await deployRelease(protocolOwner, core, libraries);
    
    // deploy instance contracts
    const masterInstance = await deployAndRegisterMasterInstance(protocolOwner, libraries, core, services);
    const clonedInstance = await cloneInstance(instanceOwner, services);
    await verifyInstance(clonedInstance, libraries);

    // await grantRole(instanceOwner, libraries, instance, Role.POOL_OWNER_ROLE, poolOwner);
    // await grantRole(instanceOwner, libraries, instance, Role.DISTRIBUTION_OWNER_ROLE, distributionOwner);
    // await grantRole(instanceOwner, libraries, instance, Role.PRODUCT_OWNER_ROLE, productOwner);

    
    // // deploy pool & product contracts
    // const { poolAddress, poolNftId, tokenAddress } = await deployPool(poolOwner, libraries, registry, instance);
    // const { distributionAddress, distributionNftId } = await deployDistribution(distributionOwner, libraries, registry, instance, tokenAddress);
    // const { productAddress, productNftId } = await deployProduct(productOwner, libraries, registry, instance, tokenAddress, poolAddress, distributionAddress);
    
    printAddresses(libraries, core, services, masterInstance, clonedInstance);

    await verifyOwnership(
        protocolOwner, masterInstanceOwner,
        //, productOwner, poolOwner, distributionOwner,
        libraries, core, //services,
        masterInstance, 
        // tokenAddress, 
        // poolAddress, poolNftId,
        // distributionAddress, distributionNftId,
        // productAddress, productNftId);
    );

    // print final balance
    await printBalance(
        ["protocolOwner", protocolOwner],
        ["masterInstanceOwner", masterInstanceOwner] , 
        // ["instanceServiceOwner", instanceServiceOwner],
        ["instanceOwner", instanceOwner],
        // ["productOwner", productOwner], 
        // ["distributionOwner", distributionOwner], 
        // ["poolOwner", poolOwner]
        );
    logger.info("GIF instance deployed successfully");
}

/**
 * Verifies the smart contract deployment has correct ownerships. 
 * Check that NFT and registry are linked correctly.
 * Check that the instance, instance NFT, pool NFT and product NFTs are owned by their respective owners.
 */
async function verifyOwnership(
    protocolOwner: AddressLike, masterInstanceOwner: AddressLike,
    // productOwner: AddressLike, poolOwner: AddressLike, distributionOwner: AddressLike,
    libraries: LibraryAddresses, core: CoreAddresses, //services: ServiceAddresses,
    masterInstance: InstanceAddresses,
    // tokenAddress: AddressLike, 
    // poolAddress: AddressLike, poolNftId: string,
    // distributionAddress: AddressLike, distributionNftId: string,
    // productAddress: AddressLike, productNftId: string,
) {
    logger.debug("validating ownerships ...");
    //const chainNft = ChainNft__factory.connect(await resolveAddress(core.chainNftAddress), ethers.provider);
    if (await core.chainNft.getRegistryAddress() !== resolveAddress(core.registryAddress)) {
        throw new Error("chainNft registry address mismatch");
    }
    //const registry = IRegistry__factory.connect(await resolveAddress(core.registryAddress), ethers.provider);
    if (await core.registry.getChainNftAddress() !== core.chainNftAddress) {
        throw new Error("registry chainNft address mismatch");
    }

    // await validateOwnership(protocolOwner, services.componentOwnerServiceAddress);
    // await validateOwnership(protocolOwner, services.productServiceAddress);
    // await validateOwnership(protocolOwner, services.poolServiceAddress);

    // await validateNftOwnerhip(core.chainNftAddress, core.registryNftId, protocolOwner);
    // await validateNftOwnerhip(core.chainNftAddress, services.componentOwnerServiceNftId, protocolOwner);
    // await validateNftOwnerhip(core.chainNftAddress, services.distributionServiceNftId, protocolOwner);
    // await validateNftOwnerhip(core.chainNftAddress, services.productServiceNftId, protocolOwner);
    // await validateNftOwnerhip(core.chainNftAddress, services.poolServiceNftId, protocolOwner);
    
    if (masterInstance.instanceNftId === undefined) {
        throw new Error("instance masterInstanceNftId undefined");
    }
    const masterInstanceNftIdFromReg = await core.registry["getNftId(address)"](masterInstance.instanceAddress);
    if (BigInt(masterInstance.instanceNftId) !== masterInstanceNftIdFromReg) {
        throw new Error(`instance masterInstanceNftId (${masterInstance.instanceNftId}) mismatch: ${masterInstanceNftIdFromReg}`);
    }
    await validateNftOwnerhip(core.chainNftAddress, masterInstance.instanceNftId, MASTER_INSTANCE_OWNER);
    
    // await validateNftOwnerhip(core.chainNftAddress, instance.instanceNftId, instanceOwner);
    
    // await validateNftOwnerhip(core.chainNftAddress, poolNftId, poolOwner);
    // await validateNftOwnerhip(core.chainNftAddress, distributionNftId, distributionOwner);
    // await validateNftOwnerhip(core.chainNftAddress, productNftId, productOwner);
    logger.info("ownerships verified");
}

function printAddresses(
    libraries: LibraryAddresses, core: CoreAddresses, 
    services: ServiceAddresses,
    masterInstance: InstanceAddresses, clonedInstance: InstanceAddresses,
    // tokenAddress: AddressLike, 
    // poolAddress: AddressLike, poolNftId: string,
    // distributionAddress: AddressLike, distributionNftId: string,
    // productAddress: AddressLike, productNftId: string,
) {
    let addresses = "\nAddresses of deployed smart contracts:\n==========\n";  
    addresses += `amountLibAddress: ${libraries.amountLibAddress}\n`;
    addresses += `blockNumberLibAddress: ${libraries.blockNumberLibAddress}\n`;
    addresses += `feeLibAddress: ${libraries.feeLibAddress}\n`;
    addresses += `key32LibAddress: ${libraries.key32LibAddress}\n`;
    addresses += `libNftIdSetAddress: ${libraries.libNftIdSetAddress}\n`;
    addresses += `mathLibAddress: ${libraries.mathLibAddress}\n`;
    addresses += `nftIdLibAddress: ${libraries.nftIdLibAddress}\n`;
    addresses += `objectTypeLibAddress: ${libraries.objectTypeLibAddress}\n`;
    addresses += `referralLibAddress: ${libraries.referralLibAddress}\n`;
    addresses += `riskIdLibAddress: ${libraries.riskIdLibAddress}\n`;
    addresses += `roleIdLibAddress: ${libraries.roleIdLibAddress}\n`;
    addresses += `stateIdLibAddress: ${libraries.stateIdLibAddress}\n`;
    addresses += `timestampLibAddress: ${libraries.timestampLibAddress}\n`;
    addresses += `uFixedLibAddress: ${libraries.uFixedLibAddress}\n`;
    addresses += `versionLibAddress: ${libraries.versionLibAddress}\n`;
    addresses += `versionPartLibAddress: ${libraries.versionPartLibAddress}\n`;
    addresses += `instanceAuthorizationsLibAddress: ${libraries.instanceAuthorizationsLibAddress}\n`;
    addresses += `--------\n`;
    addresses += `registryAdminAddress: ${core.registryAdminAddress}\n`;
    addresses += `releaseManagerAddress: ${core.releaseManagerAddress}\n`;
    addresses += `registryAddress: ${core.registryAddress}\n`;
    addresses += `registryNftId: ${core.registryNftId}\n`;
    addresses += `chainNftAddress: ${core.chainNftAddress}\n`;
    addresses += `tokenRegistryAddress: ${core.tokenRegistryAddress}\n`;
    addresses += `stakingNftId: ${core.stakingNftId}\n`;
    addresses += `stakingAddress: ${core.stakingAddress}\n`;
    addresses += `dipAddress: ${core.dipAddress}\n`;
    addresses += `--------\n`;
    addresses += `registryServiceManagerAddress: ${services.registryServiceManagerAddress}\n`;
    addresses += `registryServiceAddress: ${services.registryServiceAddress}\n`;
    addresses += `registryServiceNftId: ${services.registryServiceNftId}\n`;

    addresses += `stakingServiceManagerAddress: ${services.stakingServiceManagerAddress}\n`;
    addresses += `stakingServiceAddress: ${services.stakingServiceAddress}\n`;
    addresses += `stakingServiceNftId: ${services.stakingServiceNftId}\n`;

    addresses += `instanceServiceManagerAddress: ${services.instanceServiceManagerAddress}\n`;
    addresses += `instanceServiceAddress: ${services.instanceServiceAddress}\n`;
    addresses += `instanceServiceNftId: ${services.instanceServiceNftId}\n`;

    addresses += `componentServiceManagerAddress: ${services.componentServiceManagerAddress}\n`;
    addresses += `componentServiceAddress: ${services.componentServiceAddress}\n`;
    addresses += `componentServiceNftId: ${services.componentServiceNftId}\n`;

    addresses += `distributionServiceManagerAddress: ${services.distributionServiceManagerAddress}\n`;
    addresses += `distributionServiceAddress: ${services.distributionServiceAddress}\n`;
    addresses += `distributionServiceNftId: ${services.distributionServiceNftId}\n`;

    addresses += `poolServiceManagerAddress: ${services.poolServiceManagerAddress}\n`;
    addresses += `poolServiceAddress: ${services.poolServiceAddress}\n`;
    addresses += `poolServiceNftId: ${services.poolServiceNftId}\n`;

    addresses += `productServiceManagerAddress: ${services.productServiceManagerAddress}\n`;
    addresses += `productServiceAddress: ${services.productServiceAddress}\n`;
    addresses += `productServiceNftId: ${services.productServiceNftId}\n`;

    addresses += `applicationServiceManagerAddress: ${services.applicationServiceManagerAddress}\n`;
    addresses += `applicationServiceAddress: ${services.applicationServiceAddress}\n`;
    addresses += `applicationServiceNftId: ${services.applicationServiceNftId}\n`;

    addresses += `policyServiceManagerAddress: ${services.policyServiceManagerAddress}\n`;
    addresses += `policyServiceAddress: ${services.policyServiceAddress}\n`;
    addresses += `policyServiceNftId: ${services.policyServiceNftId}\n`;

    addresses += `claimServiceManagerAddress: ${services.claimServiceManagerAddress}\n`;
    addresses += `claimServiceAddress: ${services.claimServiceAddress}\n`;
    addresses += `claimServiceNftId: ${services.claimServiceNftId}\n`;

    addresses += `bundleServiceManagerAddress: ${services.bundleServiceManagerAddress}\n`;
    addresses += `bundleServiceAddress: ${services.bundleServiceAddress}\n`;
    addresses += `bundleServiceNftId: ${services.bundleServiceNftId}\n`;
    addresses += `--------\n`;
    addresses += `masterInstanceAddress: ${masterInstance.instanceAddress}\n`;
    addresses += `masterInstanceNftId: ${masterInstance.instanceNftId}\n`;
    addresses += `masterInstanceAccessManagerAddress: ${masterInstance.instanceAccessManagerAddress}\n`;
    addresses += `masterInstanceAdminAddress: ${masterInstance.instanceAdminAddress}\n`;
    addresses += `masterBundleManagerAddress: ${masterInstance.instanceBundleManagerAddress}\n`;
    addresses += `masterInstanceReaderAddress: ${masterInstance.instanceReaderAddress}\n`;
    addresses += `masterInstanceStoreAddress: ${masterInstance.instanceStoreAddress}\n`;
    addresses += `--------\n`;
    addresses += `clonedInstanceAddress: ${clonedInstance.instanceAddress}\n`;
    addresses += `clonedInstanceNftId: ${clonedInstance.instanceNftId}\n`;
    addresses += `clonedInstanceAccessManagerAddress: ${clonedInstance.instanceAccessManagerAddress}\n`;
    addresses += `clonedInstanceAdminAddress: ${clonedInstance.instanceAdminAddress}\n`;
    addresses += `clonedBundleManagerAddress: ${clonedInstance.instanceBundleManagerAddress}\n`;
    addresses += `clonedInstanceReaderAddress: ${clonedInstance.instanceReaderAddress}\n`;
    addresses += `--------\n`;
    // addresses += `tokenAddress: ${tokenAddress}\n`;
    // addresses += `poolAddress: ${poolAddress}\n`;
    // addresses += `poolNftId: ${poolNftId}\n`;
    // addresses += `distributionAddress: ${distributionAddress}\n`;
    // addresses += `distributionNftId: ${distributionNftId}\n`;
    // addresses += `productAddress: ${productAddress}\n`;
    // addresses += `productNftId: ${productNftId}\n`;    
    
    logger.info(addresses);
}

export type InstanceAddresses = {
    ozAccessManagerAddress: AddressLike,
    instanceAccessManagerAddress: AddressLike,
    instanceReaderAddress: AddressLike,
    instanceBundleManagerAddress: AddressLike,
    instanceAddress: AddressLike,
    instanceNftId: string,
}


main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});