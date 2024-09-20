// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AmountLib} from "../../../contracts/type/Amount.sol";
import {FireUSD} from "../../../contracts/examples/fire/FireUSD.sol";
import {FirePool} from "../../../contracts/examples/fire/FirePool.sol";
import {FirePoolAuthorization} from "../../../contracts/examples/fire/FirePoolAuthorization.sol";
import {FireProduct} from "../../../contracts/examples/fire/FireProduct.sol";
import {FireProductAuthorization} from "../../../contracts/examples/fire/FireProductAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {VersionPartLib} from "../../../contracts/type/Version.sol";

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
        // deploy fire token
        vm.startPrank(fireProductOwner);
        fireUSD = new FireUSD();
        vm.stopPrank();

        // whitelist fire token and make it active for release 3
        vm.startPrank(gifManager);
        tokenRegistry.registerToken(address(fireUSD));
        tokenRegistry.setActiveForVersion(
            currentChainId, 
            address(fireUSD), 
            VersionPartLib.toVersionPart(3),
            true);
        vm.stopPrank();
    }

    function _deployFireProduct() internal {
        vm.startPrank(fireProductOwner);
        FireProductAuthorization productAuth = new FireProductAuthorization("FireProduct");
        fireProduct = new FireProduct(
            address(registry),
            instanceNftId,
            "FireProduct",
            productAuth
        );
        vm.stopPrank();

        // instance owner registeres fire product with instance (and registry)
        vm.startPrank(instanceOwner);
        fireProductNftId = instance.registerProduct(address(fireProduct), address(fireUSD));
        vm.stopPrank();
    }

    function _deployFirePool() internal {
        vm.startPrank(firePoolOwner);
        FirePoolAuthorization poolAuth = new FirePoolAuthorization("FirePool");
        firePool = new FirePool(
            address(registry),
            fireProductNftId,
            "FirePool",
            poolAuth
        );
        vm.stopPrank();

        firePoolNftId = _registerComponent(fireProductOwner, fireProduct, address(firePool), "firePool");
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