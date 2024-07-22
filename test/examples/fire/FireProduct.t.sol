// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {console} from "../../../lib/forge-std/src/Test.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {FireUSD} from "../../../contracts/examples/fire/FireUSD.sol";
import {FirePool} from "../../../contracts/examples/fire/FirePool.sol";
import {FirePoolAuthorization} from "../../../contracts/examples/fire/FirePoolAuthorization.sol";
import {FireProduct, ONE_YEAR} from "../../../contracts/examples/fire/FireProduct.sol";
import {FireProductAuthorization} from "../../../contracts/examples/fire/FireProductAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";

contract TestFireProduct is GifTest {

    address firePoolOwner = makeAddr("firePoolOwner");
    address fireProductOwner = makeAddr("fireProductOwner");

    FireUSD public fireUSD;
    FirePool public firePool;
    NftId public firePoolNftId;
    FireProduct public fireProduct;
    NftId public fireProductNftId;

    function setUp() public override {
        super.setUp();
        
        _grantInitialRoles();
        _deployFireUSDAndFundAccounts();
        _deployFirePool();
        _deployFireProduct();
        _createInitialBundle();
    }

    function test_FireProduct_calculatePremium() public {
        // GIVEN
        // 100'000 FireUSD
        Amount sumInsured = AmountLib.toAmount(100000 * 10**6);

        // WHEN
        Amount premium = fireProduct.calculatePremium(
            "London", 
            sumInsured, 
            ONE_YEAR(),
            bundleNftId);
        
        // THEN
        assertEq((5000 + 100) * 10 ** 6, premium.toInt());
    }

    function _grantInitialRoles() internal {
        vm.startPrank(instanceOwner);
        instance.grantRole(POOL_OWNER_ROLE(), firePoolOwner);
        instance.grantRole(PRODUCT_OWNER_ROLE(), fireProductOwner);
        vm.stopPrank();
    }

    function _deployFireUSDAndFundAccounts() internal {
        vm.startPrank(fireProductOwner);
        fireUSD = new FireUSD();
        fireUSD.transfer(investor, 100000000);
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
        firePool.register();
        firePoolNftId = firePool.getNftId();
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
        fireProduct.register();
        fireProductNftId = fireProduct.getNftId();
        vm.stopPrank();
    }

    function _createInitialBundle() internal {
        vm.startPrank(investor);
        Fee memory bundleFee = FeeLib.percentageFee(2);
        Amount investAmount = AmountLib.toAmount(10000000);
        fireUSD.approve(
            address(firePool.getTokenHandler()), 
            10000000);
        (bundleNftId,) = firePool.createBundle(
            bundleFee, 
            investAmount, 
            SecondsLib.toSeconds(5 * 365 * 24 * 60 * 60)); // 5 years
        vm.stopPrank();
    }
}