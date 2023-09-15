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

    function run(address instanceOwner) external returns (Instance instance) {

        // HelperConfig helperConfig = new HelperConfig();
        // HelperConfig.NetworkConfig memory config = HelperConfig.NetworkConfig(helperConfig.activeNetworkConfig());
        // address dipAddress = config.dipAddress;

        console.log("tx origin", tx.origin);

        vm.startBroadcast();
        (ChainNft nft, Registry registry) = _deployRegistry();
        instance = _deployInstance(registry);
        _registerAndTransfer(nft, instance, instanceOwner);
        vm.stopBroadcast();

        return instance;
    }

    function _deployRegistry()
        internal 
        returns(
            ChainNft nft,
            Registry registry
        )
    {
        registry = new Registry();
        nft = new ChainNft(address(registry));
        registry.initialize(address(nft));

        console.log("nft deployed at", address(nft));
        console.log("registry deployed at", address(registry));
    }

    function _deployInstance(Registry registry) internal returns(Instance instance) {
        ComponentOwnerService componentOwnerService = new ComponentOwnerService(
            address(registry));

        ProductService productService = new ProductService(
            address(registry));

        PoolService poolService = new PoolService(
            address(registry));

        instance = new Instance(
            address(registry),
            address(componentOwnerService),
            address(productService),
            address(poolService));

        console.log("instance deployed at", address(instance));
    }

    function _registerAndTransfer(
        ChainNft nft,
        Instance instance, 
        address instanceOwner
    )
        internal
    {
        NftId instanceNftId = instance.register();

        // transfer ownerships
        nft.safeTransferFrom(tx.origin, instanceOwner, instanceNftId.toInt());
    }

}