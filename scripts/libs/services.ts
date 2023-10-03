import { AddressLike, Signer } from "ethers";
import { Registerable } from "../../typechain-types";
import { logger } from "../logger";
import { deployContract } from "./deployment";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses, register } from "./registry";

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
    logger.info(`componentOwnerService registered - componentOwnerServiceNftId: ${componentOwnerServiceNftId}`);

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

    return {
        componentOwnerServiceAddress,
        componentOwnerServiceNftId,
        productServiceAddress,
        productServiceNftId,
        poolServiceAddress,
        poolServiceNftId,
    };
}
