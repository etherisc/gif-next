// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {FireUSD} from "../../../contracts/examples/fire/FireUSD.sol";
import {FirePool} from "../../../contracts/examples/fire/FirePool.sol";
import {FirePoolAuthorization} from "../../../contracts/examples/fire/FirePoolAuthorization.sol";
import {FireProduct} from "../../../contracts/examples/fire/FireProduct.sol";
import {FireProductAuthorization} from "../../../contracts/examples/fire/FireProductAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";

contract FireTestBase is GifTest {

    address public firePoolOwner = makeAddr("firePoolOwner");
    address public fireProductOwner = makeAddr("fireProductOwner");

    FireUSD public fireUSD;
    FirePool public firePool;
    NftId public firePoolNftId;
    FireProduct public fireProduct;
    NftId public fireProductNftId;

    function setUp() public virtual override {
        super.setUp();
        
        _deployFireUSD();
        _deployFireProduct();
        _deployFirePool();
        _initialFundAccounts();
    }

    function _deployFireUSD() internal {
        vm.startPrank(fireProductOwner);
        fireUSD = new FireUSD();
        vm.stopPrank();
    }

    function _deployFireProduct() internal {
        vm.startPrank(fireProductOwner);
        FireProductAuthorization productAuth = new FireProductAuthorization("FireProduct");
        fireProduct = new FireProduct(
            address(registry),
            instanceNftId,
            "FireProduct",
            address(fireUSD),
            address(firePool),
            productAuth
        );
        vm.stopPrank();

        // instance owner registeres fire product with instance (and registry)
        vm.startPrank(instanceOwner);
        fireProductNftId = instance.registerProduct(address(fireProduct));
        vm.stopPrank();
    }

    function _deployFirePool() internal {
        vm.startPrank(firePoolOwner);
        FirePoolAuthorization poolAuth = new FirePoolAuthorization("FirePool");
        firePool = new FirePool(
            address(registry),
            instanceNftId,
            "FirePool",
            address(fireUSD),
            poolAuth
        );
        vm.stopPrank();

        firePoolNftId = _registerComponent(fireProduct, address(firePool), "firePool");
    }

    function _initialFundAccounts() internal {
        _fundAccount(investor, 100000000 * 10 ** 6);
        _fundAccount(customer, 10000 * 10 ** 6);
    }

    function _fundAccount(address account, uint256 amount) internal {
        vm.startPrank(fireProductOwner);
        fireUSD.transfer(account, amount);
        vm.stopPrank();
    }
}