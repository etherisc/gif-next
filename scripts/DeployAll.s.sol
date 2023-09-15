// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {ChainNft} from "../contracts/registry/ChainNft.sol";
import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {IComponentOwnerService} from "../contracts/instance/service/IComponentOwnerService.sol";
import {ComponentOwnerService} from "../contracts/instance/service/ComponentOwnerService.sol";
import {ProductService} from "../contracts/instance/service/ProductService.sol";
import {PoolService} from "../contracts/instance/service/PoolService.sol";
import {TestProduct} from "../contracts/test/TestProduct.sol";
import {TestPool} from "../contracts/test/TestPool.sol";
import {USDC} from "../test_forge/mock/Usdc.sol";

import {NftId, NftIdLib} from "../contracts/types/NftId.sol";
import {UFixed, UFixedMathLib} from "../contracts/types/UFixed.sol";
import {Fee, toFee} from "../contracts/types/Fee.sol";

contract DeployAll is Script {

    function run(
        address instanceOwner,
        address productOwner,
        address poolOwner
    )
        external
        returns (
            Registry,
            Instance,
            TestProduct,
            TestPool
        )
    {
        // HelperConfig helperConfig = new HelperConfig();
        // HelperConfig.NetworkConfig memory config = HelperConfig.NetworkConfig(helperConfig.activeNetworkConfig());
        // address dipAddress = config.dipAddress;

        console.log("tx origin", tx.origin);

        vm.startBroadcast();
        (, Registry registry) = _deployRegistry();
        (
            Instance instance,
            TestPool pool,
            TestProduct product
        ) = _deployInstancePoolAndProduct(registry);
        _registerAndTransfer(registry, instance, product, pool, instanceOwner, productOwner, poolOwner);
        vm.stopBroadcast();

        return (
            registry,
            instance,
            product,
            pool
        );
    }

    function _deployInstancePoolAndProduct(Registry registry)
        internal
        returns(
            Instance instance,
            TestPool pool,
            TestProduct product
        )
    {
        instance = _deployInstance(registry);
        pool = _deployPool(registry, instance);
        product = _deployProduct(registry, instance, pool);
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

        // TODO add usdc token registration
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

    function _deployPool(Registry registry, Instance instance) internal returns(TestPool pool) {
        USDC token  = new USDC();
        console.log("usdc token deployed at", address(token));

        pool = new TestPool(address(registry), address(instance), address(token));
        console.log("pool deployed at", address(pool));
    }

    function _deployProduct(Registry registry, Instance instance, TestPool pool) internal returns(TestProduct product) {
        product = new TestProduct(address(registry), address(instance), address(pool.getToken()), address(pool));
        console.log("product deployed at", address(product));
    }

    function _registerAndTransfer(
        Registry registry,
        Instance instance, 
        TestProduct product, 
        TestPool pool, 
        address instanceOwner,
        address productOwner,
        address poolOwner
    )
        internal
    {
        NftId instanceNftId = instance.register();
        IComponentOwnerService componentOwnerService = instance.getComponentOwnerService();

        // register pool
        bytes32 poolOwnerRole = instance.getRoleForName("PoolOwner");
        instance.grantRole(poolOwnerRole, address(tx.origin));
        instance.grantRole(poolOwnerRole, poolOwner);

        NftId poolNftId = componentOwnerService.register(pool);

        // register product
        bytes32 productOwnerRole = instance.getRoleForName("ProductOwner");
        instance.grantRole(productOwnerRole, address(tx.origin));
        instance.grantRole(productOwnerRole, productOwner);

        NftId productNftId = componentOwnerService.register(product);

        // transfer token
        IERC20Metadata token = product.getToken();
        token.transfer(instanceOwner, token.totalSupply());

        // transfer ownerships
        ChainNft nft = ChainNft(registry.getNftAddress());
        nft.safeTransferFrom(tx.origin, instanceOwner, instanceNftId.toInt());
        nft.safeTransferFrom(tx.origin, productOwner, productNftId.toInt());
        nft.safeTransferFrom(tx.origin, poolOwner, poolNftId.toInt());
    }

}