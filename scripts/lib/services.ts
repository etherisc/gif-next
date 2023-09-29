import { AddressLike, BaseContract, Signer } from "ethers";
import { RegistryAddresses } from "./registry";
import { LibraryAddresses } from "./libraries";
import { deployContract } from "./deployment";
import { executeTx, getFieldFromLogs } from "./transaction";
import { ComponentOwnerService, ProductService, ServiceBase } from "../../typechain-types";
import { IERC721ABI } from "./erc721";

export type ServiceAddresses = {
    componentOwnerServiceAddress: AddressLike,
    componentOwnerServiceNftId: string,
    productServiceAddress: AddressLike,
    productServiceNftId: string,
    poolServiceAddress: AddressLike,
    poolServiceNftId: string,
}

export async function deployServices(owner: Signer, registry: RegistryAddresses, libraries: LibraryAddresses): Promise<ServiceAddresses> {
    const { address: componentOwnerServiceAddress, contract: componentOwnerServiceBaseContract } = await deployContract(
        "ComponentOwnerService",
        owner,
        [registry.registryAddress, registry.registryNftId],
        { libraries: { NftIdLib: libraries.nfIdLibAddress, BlocknumberLib: libraries.blockNumberLibAddress, VersionLib: libraries.versionLibAddress, VersionPartLib: libraries.versionPartLibAddress }});
    const componentOwnerService = componentOwnerServiceBaseContract as ComponentOwnerService;
    let tx = await executeTx(async () => await componentOwnerService["register()"]());
    const componentOwnerServiceNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");

    const { address: productServiceAddress, contract: productServiceBaseContract } = await deployContract(
        "ProductService",
        owner,
        [registry.registryAddress, registry.registryNftId],
        { libraries: {
                NftIdLib: libraries.nfIdLibAddress,
                BlocknumberLib: libraries.blockNumberLibAddress, 
                VersionLib: libraries.versionLibAddress, 
                VersionPartLib: libraries.versionPartLibAddress, 
                TimestampLib: libraries.timestampLibAddress,
                UFixedMathLib: libraries.uFixedMathLibAddress,
            }});
    const productService = productServiceBaseContract as ProductService;
    tx = await executeTx(async () => await productService.register());
    const productServiceNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");

    const { address: poolServiceAddress, contract: PoolServiceBaseContract } = await deployContract(
        "PoolService",
        owner,
        [registry.registryAddress, registry.registryNftId],
        { libraries: { 
            NftIdLib: libraries.nfIdLibAddress,
            BlocknumberLib: libraries.blockNumberLibAddress,
            VersionLib: libraries.versionLibAddress,
            VersionPartLib: libraries.versionPartLibAddress,
        }});
    const poolService = PoolServiceBaseContract as ServiceBase;
    tx = await executeTx(async () => await poolService.register());
    const poolServiceNftId = getFieldFromLogs(tx, IERC721ABI, "Transfer", "tokenId");

    return {
        componentOwnerServiceAddress,
        componentOwnerServiceNftId,
        productServiceAddress,
        productServiceNftId,
        poolServiceAddress,
        poolServiceNftId,
    };
}
