// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {ACTIVE} from "../../../contracts/type/StateId.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {GifTest} from "../../base/GifTest.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IPoolService} from "../../../contracts/pool/IPoolService.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IPoolService} from "../../../contracts/pool/IPoolService.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {TokenHandler} from "../../../contracts/shared/TokenHandler.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {ExternallyManagedPool} from "./ExternallyManagedPool.sol";
import {ExternallyManagedProduct} from "./ExternallyManagedProduct.sol";

// solhint-disable func-name-mixedcase
contract DefaultPoolTest is GifTest {

    ExternallyManagedProduct public emProduct;
    ExternallyManagedPool public emPool;

    NftId emProductNftId;
    NftId emPoolNftId;

    function setUp() public override {
        super.setUp();

        _prepareProduct(); // simple product setup
    }


    function test_externallyManagedDefaultPoolSetUp() public {
        // GIVEN just setUp

        // WHEN + THEN
        IComponents.PoolInfo memory poolInfo = instanceReader.getPoolInfo(poolNftId);

        assertFalse(poolInfo.isExternallyManaged, "unexpected info.isExternallyManaged");
    }


    function test_externallyManagedDefaultPoolFundPoolWithRevert() public {
        // GIVEN 
        uint256 funding = 12345;
        Amount fundingAmount = AmountLib.toAmount(funding);

        vm.startPrank(tokenIssuer);
        token.transfer(poolOwner, fundingAmount.toInt());
        vm.stopPrank();

        // pool owner now has tokens
        assertEq(token.balanceOf(poolOwner), funding, "unexpected poolOwner balance (before)");

        // WHEN + THEN
        address tokenHandlerAddress = address(pool.getTokenHandler());

        vm.startPrank(poolOwner);
        token.approve(tokenHandlerAddress, funding);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPoolService.ErrorPoolServicePoolNotExternallyManaged.selector,
                poolNftId));

        pool.fundPoolWallet(fundingAmount);
        vm.stopPrank();
    }


    function test_externallyManagedDefaultPoolDefundPoolWithRevert() public {
        // GIVEN 
        uint256 funding = 12345;
        Amount fundingAmount = AmountLib.toAmount(funding);

        vm.startPrank(tokenIssuer);
        token.transfer(poolOwner, fundingAmount.toInt());
        vm.stopPrank();

        // pool owner now has tokens
        assertEq(token.balanceOf(poolOwner), funding, "unexpected poolOwner balance (before)");

        // WHEN + THEN
        address tokenHandlerAddress = address(pool.getTokenHandler());

        vm.startPrank(poolOwner);
        token.approve(tokenHandlerAddress, funding);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPoolService.ErrorPoolServicePoolNotExternallyManaged.selector,
                poolNftId));

        pool.defundPoolWallet(fundingAmount);
        vm.stopPrank();
    }
}