// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {DeployInstance} from "./DeployInstance.s.sol";

import {IChainNft} from "../contracts/registry/IChainNft.sol";
import {ChainNft} from "../contracts/registry/ChainNft.sol";
import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {ComponentOwnerService} from "../contracts/instance/service/ComponentOwnerService.sol";
import {ProductService} from "../contracts/instance/service/ProductService.sol";
import {PoolService} from "../contracts/instance/service/PoolService.sol";
import {TestProduct} from "../contracts/test/TestProduct.sol";
import {TestPool} from "../contracts/test/TestPool.sol";
import {USDC} from "../test_forge/mock/Usdc.sol";

import {NftId, NftIdLib} from "../contracts/types/NftId.sol";
import {UFixed, UFixedMathLib} from "../contracts/types/UFixed.sol";
import {Version} from "../contracts/types/Version.sol";
import {Fee, toFee} from "../contracts/types/Fee.sol";

contract DeployAll is DeployInstance {

    event LogTest(uint a, string b, address c);

    address public productOwner;
    address public poolOwner;

    IERC20Metadata public token;
    TestProduct public product;
    TestPool public pool;

    function run(
        address registryOwner_,
        address instanceOwner_,
        address productOwner_,
        address poolOwner_
    )
        external
        returns (
            Registry,
            Instance,
            TestProduct,
            TestPool
        )
    {
        productOwner = productOwner_;
        poolOwner = poolOwner_;

        super.run(registryOwner_, instanceOwner_);

        Version version = instance.getVersion();
        address cosAddress = registry.getServiceAddress("ComponentOwnerService", version.toMajorPart());
        componentOwnerService = ComponentOwnerService(cosAddress);

        console.log("deploy pool and product");

        vm.startBroadcast();
        pool = _deployPool();
        product = _deployProduct();
        _registerAndTransferProductAndPool();
        vm.stopBroadcast();

        return (
            registry,
            instance,
            product,
            pool
        );
    }

    function _deployPool() internal returns(TestPool pool_) {
        USDC usdc  = new USDC();
        console.log("usdc token deployed at", address(usdc));

        pool_ = new TestPool(address(registry), instance.getNftId(), address(usdc));
        console.log("pool deployed at", address(pool_));
    }

    function _deployProduct() internal returns(TestProduct product_) {
        product_ = new TestProduct(address(registry), instance.getNftId(), address(pool.getToken()), address(pool));
        console.log("product deployed at", address(product_));
    }

    function _registerAndTransferProductAndPool() internal {

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
        token = product.getToken();
        token.transfer(instanceOwner, token.totalSupply());

        // transfer ownerships
        IChainNft nft = registry.getChainNft();
        nft.safeTransferFrom(tx.origin, productOwner, productNftId.toInt());
        nft.safeTransferFrom(tx.origin, poolOwner, poolNftId.toInt());
    }

}