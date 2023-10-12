import { AddressLike, JsonRpcApiProvider, Signer } from "ethers";
import { Registerable, ComponentOwnerService__factory, Registry__factory } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses, register, approve } from "./registry";
import { executeTx, getFieldFromLogs } from "./transaction";
import { IERC721ABI } from "./erc721";

export type ServiceAddresses = {
    componentOwnerServiceAddress: AddressLike,
    componentOwnerServiceNftId: string,
    productServiceAddress: AddressLike,
    productServiceNftId: string,
    poolServiceAddress: AddressLike,
    poolServiceNftId: string,
}

export async function deployAndRegisterServices(owner: Signer, registry: RegistryAddresses, libraries: LibraryAddresses): Promise<ServiceAddresses> {
    const { address: componentOwnerServiceAddress, contract: componentOwnerServiceBaseContract } = await deployContract(
        "ComponentOwnerService",
        owner,
        [registry.registryAddress, registry.registryNftId],
        { libraries: { 
            NftIdLib: libraries.nftIdLibAddress, 
            BlocknumberLib: libraries.blockNumberLibAddress, 
            VersionLib: libraries.versionLibAddress,
            RoleIdLib: libraries.roleIdLibAddress,
        }});
    const componentOwnerServiceNftId = await register(componentOwnerServiceBaseContract as Registerable, componentOwnerServiceAddress, "ComponentOwnerService", registry, owner);

    // INSTANCE for REGISTRY
    await approve(componentOwnerServiceNftId, 50, 20,  "ComponentOwnerService", registry, owner);
    // PRODUCT for INSTANCE
    await approve(componentOwnerServiceNftId, 100, 50,  "ComponentOwnerService", registry, owner);
    // POOL for REGISTRY
    await approve(componentOwnerServiceNftId, 130, 50,  "ComponentOwnerService", registry, owner);

    const { address: productServiceAddress, contract: productServiceBaseContract } = await deployContract(
        "ProductService",
        owner,
        [registry.registryAddress, registry.registryNftId],
        { libraries: {
                NftIdLib: libraries.nftIdLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress, 
                VersionLib: libraries.versionLibAddress, 
                TimestampLib: libraries.timestampLibAddress,
                UFixedMathLib: libraries.uFixedMathLibAddress,
                FeeLib: libraries.feeLibAddress,
            }});
    const productServiceNftId = await register(productServiceBaseContract as Registerable, productServiceAddress, "ProductService", registry, owner);
    logger.info(`productService registered - productServiceNftId: ${productServiceNftId}`);

    // POLICY for PRODUCT
    await approve(productServiceNftId, 200, 100,  "ProductService", registry, owner);


    const { address: poolServiceAddress, contract: PoolServiceBaseContract } = await deployContract(
        "PoolService",
        owner,
        [registry.registryAddress, registry.registryNftId],
        { libraries: { 
            NftIdLib: libraries.nftIdLibAddress,
            BlocknumberLib: libraries.blockNumberLibAddress,
            VersionLib: libraries.versionLibAddress,
        }});
    const poolServiceNftId = await register(PoolServiceBaseContract as Registerable, poolServiceAddress, "PoolService", registry, owner);
    logger.info(`poolService registered - poolServiceNftId: ${poolServiceNftId}`);

    // BUNDLE for POOL
    await approve(poolServiceNftId, 210, 130,  "PoolService", registry, owner);

    return {
        componentOwnerServiceAddress,
        componentOwnerServiceNftId,
        productServiceAddress,
        productServiceNftId,
        poolServiceAddress,
        poolServiceNftId,
    };
}


export async function registerInstance(registrable: Registerable, address: AddressLike, name: string, servicesAddresses: ServiceAddresses, registryAddresses: RegistryAddresses, signer: Signer): Promise<string> {
    const service = ComponentOwnerService__factory.connect(servicesAddresses.componentOwnerServiceAddress.toString(), signer);
    const registry = Registry__factory.connect(registryAddresses.registryAddress.toString(), signer);
    if (await registry["isRegistered(address)"](address)) {
        const nftId = await registry["getNftId(address)"](address);
        logger.info(`already registered - nftId: ${nftId}`);
        return nftId.toString();
    }

    logger.debug("registering Instance " + name);

    const tx = await executeTx(async () => await service.registerInstance(registrable));
    const nftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    return nftId;
}

export async function registerPool(registrable: Registerable, address: AddressLike, name: string, servicesAddresses: ServiceAddresses, registryAddresses: RegistryAddresses, signer: Signer): Promise<string> {
    const service = ComponentOwnerService__factory.connect(servicesAddresses.componentOwnerServiceAddress.toString(), signer);
    const registry = Registry__factory.connect(registryAddresses.registryAddress.toString(), signer);
    if (await registry["isRegistered(address)"](address)) {
        const nftId = await registry["getNftId(address)"](address);
        logger.info(`already registered - nftId: ${nftId}`);
        return nftId.toString();
    }

    logger.debug("registering Pool " + name);

    const tx = await executeTx(async () => await service.registerPool(registrable));
    const nftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    return nftId;
}


export async function registerProduct(registrable: Registerable, address: AddressLike, name: string, servicesAddresses: ServiceAddresses, registryAddresses: RegistryAddresses, signer: Signer): Promise<string> {
    const service = ComponentOwnerService__factory.connect(servicesAddresses.componentOwnerServiceAddress.toString(), signer);
    const registry = Registry__factory.connect(registryAddresses.registryAddress.toString(), signer);
    if (await registry["isRegistered(address)"](address)) {
        const nftId = await registry["getNftId(address)"](address);
        logger.info(`already registered - nftId: ${nftId}`);
        return nftId.toString();
    }

    logger.debug("registering Product " + name);

    const tx = await executeTx(async () => await service.registerProduct(registrable));
    const nftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
    return nftId;
}