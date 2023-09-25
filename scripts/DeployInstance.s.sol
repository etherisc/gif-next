// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {ChainNft} from "../contracts/registry/ChainNft.sol";
import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {ComponentOwnerService} from "../contracts/instance/service/ComponentOwnerService.sol";
import {IComponentOwnerService} from "../contracts/instance/service/IComponentOwnerService.sol";
import {ProductService} from "../contracts/instance/service/ProductService.sol";
import {PoolService} from "../contracts/instance/service/PoolService.sol";
import {NftId, NftIdLib} from "../contracts/types/NftId.sol";

contract DeployInstance is Script {
    using NftIdLib for NftId;

    address public registryOwner;
    address public instanceOwner;

    ChainNft public nft;
    Registry public registry;
    address public registryAddress;
    NftId public registryNftId;
    Instance public instance;

    ComponentOwnerService public componentOwnerService;
    ProductService public productService;
    PoolService public poolService;

    function run(address registryOwner_, address instanceOwner_) public virtual returns (Instance) {

        // HelperConfig helperConfig = new HelperConfig();
        // HelperConfig.NetworkConfig memory config = HelperConfig.NetworkConfig(helperConfig.activeNetworkConfig());
        // address dipAddress = config.dipAddress;

        registryOwner = registryOwner_;
        instanceOwner =  instanceOwner_;

        console.log("tx origin", tx.origin);

        vm.startBroadcast();
        _deployRegistry();
        _deployInstance();
        _registerAndTransfer();
        vm.stopBroadcast();

        return instance;
    }

    function _deployRegistry()
        internal 
    {
        registry = new Registry();
        nft = new ChainNft(address(registry));
        registry.initialize(address(nft), registryOwner);
        registryAddress = address(registry);
        registryNftId = registry.getNftId();

        console.log("nft deployed at", address(nft));
        console.log("registry deployed at", address(registry));
    }

    function _deployInstance() internal returns(Instance) {
        componentOwnerService = new ComponentOwnerService(
            registryAddress, registryNftId);
        componentOwnerService.register();
        console.log("service name", componentOwnerService.NAME());
        console.log("service nft id", componentOwnerService.getNftId().toInt());
        console.log("component owner service deployed at", address(componentOwnerService));

        productService = new ProductService(
            registryAddress, registryNftId);
        productService.register();
        console.log("service name", productService.NAME());
        console.log("service nft id", productService.getNftId().toInt());
        console.log("product service deployed at", address(productService));

        poolService = new PoolService(
            registryAddress, registryNftId);
        poolService.register();
        console.log("service name", poolService.NAME());
        console.log("service nft id", poolService.getNftId().toInt());
        console.log("pool service deployed at", address(poolService));

        instance = new Instance(
            registryAddress, 
            registryNftId);

        console.log("instance deployed at", address(instance));

        return instance;
    }

    function _registerAndTransfer() internal {
        NftId instanceNftId = instance.register();

        // transfer ownerships
        nft.safeTransferFrom(tx.origin, instanceOwner, instanceNftId.toInt());
        console.log("transferred instance nft", instanceNftId.toInt());
    }
}