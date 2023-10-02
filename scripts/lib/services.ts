import { AddressLike, Signer } from "ethers";
import { Registerable } from "../../typechain-types";
import { deployContract } from "./deployment";
import { IERC721ABI } from "./erc721";
import { LibraryAddresses } from "./libraries";
import { RegistryAddresses } from "./registry";
import { executeTx, getFieldFromLogs } from "./transaction";
import { logger } from "../logger";

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
    const componentOwnerService = componentOwnerServiceBaseContract as Registerable;
    logger.debug("registering componentOwnerService");
    let tx = await executeTx(async () => await componentOwnerService.register());
    const componentOwnerServiceNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
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
    const productService = productServiceBaseContract as Registerable;
    logger.debug("registering productService");
    tx = await executeTx(async () => await productService.register());
    const productServiceNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
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
    const poolService = PoolServiceBaseContract as Registerable;
    logger.debug("registering poolService");
    tx = await executeTx(async () => await poolService.register());
    const poolServiceNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");
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
