// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {ACTIVE} from "../../../contracts/type/StateId.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {GifTest} from "../../base/GifTest.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IPoolComponent} from "../../../contracts/pool/IPoolComponent.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {VerifyingPool} from "./VerifyingPool.sol";
import {VerifyingProduct} from "./VerifyingProduct.sol";

// solhint-disable func-name-mixedcase
contract VerifyingPoolTest is GifTest {

    VerifyingProduct public vProduct;
    VerifyingPool public vPool;

    NftId vProductNftId;
    NftId vPoolNftId;

    function setUp() public override {
        super.setUp();

        _deployProduct();

        vm.startPrank(instanceOwner);
        vProductNftId = instance.registerProduct(address(vProduct), address(token));
        vProduct.init();
        vm.stopPrank();

        vm.startPrank(registryOwner);
        token.transfer(productOwner, 10000);
        vm.stopPrank();

        _deployPool(vProductNftId);

        vm.startPrank(productOwner);
        vPoolNftId = vProduct.registerComponent(address(vPool));
        token.approve(address(vPool.getTokenHandler()), 10000);
        vPool.init();
        vm.stopPrank();
    }


    function test_verifyingPoolSetUp() public {
        // GIVEN 
        // WHEN just setUp

        // THEN
        IComponents.PoolInfo memory poolInfo = instanceReader.getPoolInfo(vPoolNftId);

        assertTrue(poolInfo.isVerifyingApplications, "unexpected isVerifyingApplications");
    }


    function test_verifyingPoolCreatePolicyHappyCase() public {
        // GIVEN 
        NftId bundle1NftId = vPool.bundleOneNftId();
        NftId bundle2NftId = vPool.bundleTwoNftId();

        Amount expectedCollateralizationAmount = AmountLib.toAmount(1000);
        NftId expectedPolicy1NftId = NftIdLib.toNftId(243133705);
        NftId expectedPolicy2NftId = NftIdLib.toNftId(253133705);

        // WHEN just setUp
        vm.startPrank(customer);

        vm.expectEmit(address(vPool));
        emit IPoolComponent.LogPoolVerifiedByPool(
            address(vPool), 
            expectedPolicy1NftId, 
            expectedCollateralizationAmount);
        NftId policy1NftId = vProduct.createPolicy(1, bundle1NftId);

        vm.expectEmit(address(vPool));
        emit IPoolComponent.LogPoolVerifiedByPool(
            address(vPool), 
            expectedPolicy2NftId, 
            expectedCollateralizationAmount);
        NftId policy2NftId = vProduct.createPolicy(2, bundle2NftId);
        vm.stopPrank();

        // THEN
        assertTrue(policy1NftId.gtz(), "unexpected policy1NftId");
        assertTrue(policy2NftId.gtz(), "unexpected policy2NftId");
    }


    function test_verifyingPoolCreatePolicyNonMatching() public {
        // GIVEN 
        NftId bundle1NftId = vPool.bundleOneNftId();
        NftId bundle2NftId = vPool.bundleTwoNftId();
        NftId expectedPolicyNftId = NftIdLib.toNftId(243133705);

        // WHEN + THEN
        vm.startPrank(customer);

        // application 1 with bundle 2
        vm.expectRevert(
            abi.encodeWithSelector(
                IPoolComponent.ErrorPoolApplicationBundleMismatch.selector,
                expectedPolicyNftId));

        NftId policy1NftId = vProduct.createPolicy(1, bundle2NftId);

        // application 2 with bundle 1
        vm.expectRevert(
            abi.encodeWithSelector(
                IPoolComponent.ErrorPoolApplicationBundleMismatch.selector,
                expectedPolicyNftId));

        NftId policy2NftId = vProduct.createPolicy(2, bundle1NftId);

        vm.stopPrank();

        // THEN
        assertTrue(policy1NftId.eqz(), "unexpected policy1NftId");
        assertTrue(policy2NftId.eqz(), "unexpected policy2NftId");
    }


    function _deployProduct() internal {
        IComponents.ProductInfo memory productInfo = _getSimpleProductInfo();
        productInfo.hasDistribution = false;
        productInfo.expectedNumberOfOracles = 0;
        IComponents.FeeInfo memory feeInfo = _getSimpleFeeInfo();

        vProduct = new VerifyingProduct(
            address(registry),
            instanceNftId,
            productInfo,
            feeInfo,
            productOwner
        );
    }


    function _deployPool(NftId prdNftId) internal {
        IComponents.PoolInfo memory poolInfo = IComponents.PoolInfo({
            maxBalanceAmount: AmountLib.max(),
            isInterceptingBundleTransfers: false,
            isProcessingConfirmedClaims: false,
            isExternallyManaged: false,
            isVerifyingApplications: true,
            collateralizationLevel: UFixedLib.one(),
            retentionLevel: UFixedLib.one()
        });

        vPool = new VerifyingPool(
            address(registry),
            prdNftId,
            poolInfo,
            poolOwner
        );
    }
}