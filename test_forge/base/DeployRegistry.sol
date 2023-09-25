// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {console} from "../../lib/forge-std/src/Script.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {ComponentOwnerService} from "../../contracts/instance/service/ComponentOwnerService.sol";
import {ProductService} from "../../contracts/instance/service/ProductService.sol";
import {PoolService} from "../../contracts/instance/service/PoolService.sol";
import {NftId} from "../../contracts/types/NftId.sol";

contract DeployRegistry {

    address public registryAddress;
    NftId public registryNftId;

    function run(address registryNftOwner) external returns (Registry registry) {
        console.log("tx origin", tx.origin);
        registry = _deployRegistry(registryNftOwner);
        _deployServices();
    }

    function _deployRegistry(address registryNftOwner) internal returns (Registry registry) {
        registry = new Registry();
        ChainNft nft = new ChainNft(address(registry));

        registry.initialize(address(nft), registryNftOwner);
        registryAddress = address(registry);
        registryNftId = registry.getNftId();

        console.log("nft deployed at", address(nft));
        console.log("registry deployed at", address(registry));
    }

    function _deployServices() internal {
        ComponentOwnerService componentOwnerService = new ComponentOwnerService(
            registryAddress, registryNftId);
        componentOwnerService.register();

        console.log("service name", componentOwnerService.NAME());
        console.log("service nft id", componentOwnerService.getNftId().toInt());
        console.log("component owner service deployed at", address(componentOwnerService));

        ProductService productService = new ProductService(
            registryAddress, registryNftId);
        productService.register();

        console.log("service name", productService.NAME());
        console.log("service nft id", productService.getNftId().toInt());
        console.log("product service deployed at", address(productService));

        PoolService poolService = new PoolService(
            registryAddress, registryNftId);
        poolService.register();

        console.log("service name", poolService.NAME());
        console.log("service nft id", poolService.getNftId().toInt());
        console.log("pool service deployed at", address(poolService));
    }
}