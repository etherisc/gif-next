// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {ACTIVE} from "../../../contracts/type/StateId.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {GifTest} from "../../base/GifTest.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IPoolComponent} from "../../../contracts/pool/IPoolComponent.sol";
import {IPoolService} from "../../../contracts/pool/IPoolService.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {ExternallyManagedPool} from "./ExternallyManagedPool.sol";
import {ExternallyManagedProduct} from "./ExternallyManagedProduct.sol";

// solhint-disable func-name-mixedcase
contract ExternallyManagedPoolTest is GifTest {

    ExternallyManagedProduct public emProduct;
    ExternallyManagedPool public emPool;

    NftId emProductNftId;
    NftId emPoolNftId;

    function setUp() public override {
        super.setUp();

        _deployProduct(); // simple product setup

        vm.startPrank(instanceOwner);
        emProductNftId = instance.registerProduct(address(emProduct));
        emProduct.init();
        vm.stopPrank();

        _deployPool(emProductNftId);

        vm.startPrank(productOwner);
        emPoolNftId = emProduct.registerComponent(address(emPool));
        emPool.init();
        vm.stopPrank();
    }


    function test_externallyManagedPoolSetUp() public {
        // GIVEN just setUp

        // WHEN + THEN
        IComponents.PoolInfo memory emPoolInfo = instanceReader.getPoolInfo(emPoolNftId);

        assertTrue(emPoolInfo.isExternallyManaged, "unexpected emPoolInfo.isVerifyingApplications");
        assertEq(instanceReader.getBalanceAmount(emPoolNftId).toInt(), 0, "unexpected em pool balance amount");
        assertEq(instanceReader.getLockedAmount(emPoolNftId).toInt(), 0, "unexpected em pool locked amount");
        assertEq(instanceReader.getFeeAmount(emPoolNftId).toInt(), 0, "unexpected em pool fee amount");
        assertEq(instanceReader.activeBundles(emPoolNftId), 0, "unexpected em pool active bundle count");
        assertEq(token.balanceOf(emPool.getWallet()), 0, "em pool balance not zero");
    }


    function test_externallyManagedPoolFundPool() public {
        // GIVEN 
        uint256 funding = 12345;
        Amount fundingAmount = AmountLib.toAmount(funding);

        vm.startPrank(registryOwner);
        token.transfer(poolOwner, fundingAmount.toInt());
        vm.stopPrank();

        // pool owner now has tokens
        assertEq(token.balanceOf(poolOwner), funding, "unexpected poolOwner balance (before)");

        // WHEN
        address tokenHandlerAddress = address(emPool.getTokenHandler());

        vm.startPrank(poolOwner);
        token.approve(tokenHandlerAddress, funding);

        vm.expectEmit(address(poolService));
        emit IPoolService.LogPoolServiceWalletFunded(
            emPoolNftId, 
            poolOwner, 
            fundingAmount);

        emPool.fundPoolWallet(fundingAmount);
        vm.stopPrank();

        // THEN

        // pool owner no longer has tokens
        assertEq(token.balanceOf(poolOwner), 0, "unexpected poolOwner balance (after)");

        // pool book keeping all zero
        assertEq(instanceReader.getBalanceAmount(emPoolNftId).toInt(), 0, "unexpected em pool balance amount");
        assertEq(instanceReader.getLockedAmount(emPoolNftId).toInt(), 0, "unexpected em pool locked amount");
        assertEq(instanceReader.getFeeAmount(emPoolNftId).toInt(), 0, "unexpected em pool fee amount");
        assertEq(instanceReader.activeBundles(emPoolNftId), 0, "unexpected em pool active bundle count");

        // pool wallet has the funds
        assertEq(token.balanceOf(emPool.getWallet()), fundingAmount.toInt(), "unexpected em pool wallet token balance");
    }


    function test_externallyManagedPoolDefundPool() public {
        // GIVEN 
        uint256 funding = 12345;
        uint256 defunding = 345;

        Amount fundingAmount = AmountLib.toAmount(funding);
        Amount defundingAmount = AmountLib.toAmount(defunding);

        address tokenHandlerAddress = address(emPool.getTokenHandler());

        vm.startPrank(registryOwner);
        token.transfer(poolOwner, fundingAmount.toInt());
        vm.stopPrank();

        vm.startPrank(poolOwner);
        token.approve(tokenHandlerAddress, funding);
        emPool.fundPoolWallet(fundingAmount);
        vm.stopPrank();

        // pool book keeping
        assertEq(instanceReader.getBalanceAmount(emPoolNftId).toInt(), 0, "unexpected em pool balance amount");
        assertEq(instanceReader.getLockedAmount(emPoolNftId).toInt(), 0, "unexpected em pool locked amount");
        assertEq(instanceReader.getFeeAmount(emPoolNftId).toInt(), 0, "unexpected em pool fee amount");

        // token balances
        assertEq(token.balanceOf(poolOwner), 0, "unexpected poolOwner balance (before)");
        assertEq(token.balanceOf(emPool.getWallet()), funding, "unexpected em pool balance (before)");

        // WHEN

        vm.startPrank(poolOwner);
        vm.expectEmit(address(poolService));
        emit IPoolService.LogPoolServiceWalletDefunded(
            emPoolNftId, 
            poolOwner, 
            defundingAmount);

        emPool.defundPoolWallet(defundingAmount);
        vm.stopPrank();


        // THEN

        // pool owner no longer has tokens
        assertEq(token.balanceOf(poolOwner), defunding, "unexpected poolOwner balance (after)");
        assertEq(token.balanceOf(emPool.getWallet()), funding - defunding, "unexpected em pool balance (after)");

        // pool book keeping all zero
        assertEq(instanceReader.getBalanceAmount(emPoolNftId).toInt(), 0, "unexpected em pool balance amount");
        assertEq(instanceReader.getLockedAmount(emPoolNftId).toInt(), 0, "unexpected em pool locked amount");
        assertEq(instanceReader.getFeeAmount(emPoolNftId).toInt(), 0, "unexpected em pool fee amount");
        assertEq(instanceReader.activeBundles(emPoolNftId), 0, "unexpected em pool active bundle count");
    }


    function test_externallyManagedPoolCreateBundle() public {
        // GIVEN just setUp
        // WHEN

        Amount bundleAmount = AmountLib.toAmount(10042);

        vm.startPrank(registryOwner);
        token.transfer(investor, bundleAmount.toInt());
        token.approve(address(emPool.getTokenHandler()), bundleAmount.toInt());
        vm.stopPrank();

        assertEq(token.balanceOf(investor), bundleAmount.toInt(), "unexpected investor balance (before)");

        vm.startPrank(investor);
        NftId bundleNftId = emPool.createAndFundBundle(bundleAmount);
        vm.stopPrank();

        // THEN

        // investor still has the tokens
        assertEq(token.balanceOf(investor), bundleAmount.toInt(), "unexpected investor balance (after)");

        // check pool book keeping
        IComponents.PoolInfo memory emPoolInfo = instanceReader.getPoolInfo(emPoolNftId);
        assertTrue(emPoolInfo.isExternallyManaged, "unexpected emPoolInfo.isVerifyingApplications");
        assertEq(instanceReader.getBalanceAmount(emPoolNftId).toInt(), bundleAmount.toInt(), "unexpected em pool balance amount");
        assertEq(instanceReader.getLockedAmount(emPoolNftId).toInt(), 0, "unexpected em pool locked amount");
        assertEq(instanceReader.getFeeAmount(emPoolNftId).toInt(), 0, "unexpected em pool fee amount");

        // check bundle book keeping
        assertEq(instanceReader.activeBundles(emPoolNftId), 1, "unexpected em pool active bundle count");
        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), bundleAmount.toInt(), "unexpected em pool balance amount");
        assertEq(instanceReader.getLockedAmount(bundleNftId).toInt(), 0, "unexpected em pool locked amount");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "unexpected em pool fee amount");

        // pool wallet does not yet have any funds
        assertEq(token.balanceOf(emPool.getWallet()), 0, "em pool balance not zero");
    }



    function _deployProduct() internal {
        IComponents.ProductInfo memory productInfo = _getSimpleProductInfo();
        productInfo.hasDistribution = false;
        productInfo.expectedNumberOfOracles = 0;

        emProduct = new ExternallyManagedProduct(
            address(registry),
            instanceNftId,
            address(token),
            productInfo,
            productOwner
        );
    }


    function _deployPool(NftId prdNftId) internal {
        IComponents.PoolInfo memory poolInfo = IComponents.PoolInfo({
            maxBalanceAmount: AmountLib.max(),
            isInterceptingBundleTransfers: false,
            isProcessingConfirmedClaims: false,
            isExternallyManaged: true,
            isVerifyingApplications: false,
            collateralizationLevel: UFixedLib.one(),
            retentionLevel: UFixedLib.one()
        });

        emPool = new ExternallyManagedPool(
            address(registry),
            prdNftId,
            address(token),
            poolInfo,
            poolOwner
        );
    }
}