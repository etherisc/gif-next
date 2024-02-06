// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {TestGifBase} from "./base/TestGifBase.sol";
import {NftId, NftIdLib} from "../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE} from "../contracts/types/RoleId.sol";
import {MockProduct} from "./mock/MockProduct.sol";
import {ISetup} from "../contracts/instance/module/ISetup.sol";
import {IPolicy} from "../contracts/instance/module/IPolicy.sol";
import {IBundle} from "../contracts/instance/module/IBundle.sol";
import {Fee, FeeLib} from "../contracts/types/Fee.sol";
import {UFixedLib} from "../contracts/types/UFixed.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../contracts/types/Timestamp.sol";
import {IRisk} from "../contracts/instance/module/IRisk.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../contracts/types/RiskId.sol";
import {ReferralLib} from "../contracts/types/Referral.sol";
import {APPLIED, ACTIVE, UNDERWRITTEN} from "../contracts/types/StateId.sol";
import {POLICY} from "../contracts/types/ObjectType.sol";

contract TestProduct is TestGifBase {
    using NftIdLib for NftId;

    function test_Product_SetFees() public {
        _prepareProduct();
        vm.startPrank(productOwner);

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        Fee memory productFee = productSetupInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 0, "product fee not 0");
        assertEq(productFee.fixedFee, 0, "product fee not 0");
        Fee memory processingFee = productSetupInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 0, "processing fee not 0");
        assertEq(processingFee.fixedFee, 0, "processing fee not 0");
        
        Fee memory newProductFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newProcessingFee = FeeLib.toFee(UFixedLib.toUFixed(789,0), 101112);
        product.setFees(newProductFee, newProcessingFee);

        productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        productFee = productSetupInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 123, "product fee not 123");
        assertEq(productFee.fixedFee, 456, "product fee not 456");
        processingFee = productSetupInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 789, "processing fee not 789");
        assertEq(processingFee.fixedFee, 101112, "processing fee not 101112");

        vm.stopPrank();
    }

    function test_Product_calculatePremium() public {
        _prepareProduct();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        MockProduct dproduct = MockProduct(address(product));
        dproduct.createRisk(riskId, data);

        uint256 premium = product.calculatePremium(
            1000,
            riskId,
            30,
            "",
            ReferralLib.zero(),
            bundleNftId
        );
        assertEq(premium, 140, "premium not 140 (100 + 10 + 10 + 10 + 10)");
    }

    function test_Product_createApplication() public {
        _prepareProduct();  

        

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        MockProduct dproduct = MockProduct(address(product));
        dproduct.createRisk(riskId, data);

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            30,
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");


        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        // assertEq(policyInfo.owner, customer, "customer not set");
        assertTrue(eqRiskId(riskId, riskId), "riskId not set");
        assertEq(policyInfo.sumInsuredAmount, 1000, "sumInsuredAmount not set");
        assertEq(policyInfo.lifetime, 30, "lifetime not set");
        assertTrue(policyInfo.bundleNftId.eq(bundleNftId), "bundleNftId not set");        
    }

    function test_Product_underwrite() public {
        // GIVEN
        _prepareProduct();  

        

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        MockProduct dproduct = MockProduct(address(product));
        dproduct.createRisk(riskId, data);

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            30,
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        // WHEN
        dproduct.underwrite(policyNftId, false, TimestampLib.blockTimestamp()); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not UNDERWRITTEN");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount, 1000, "lockedAmount not 1000");
        assertEq(bundleInfo.balanceAmount, 10000, "lockedAmount not 1000");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt == policyInfo.activatedAt.addSeconds(30), "expiredAt not activatedAt + 30");

        assertEq(instanceBundleManager.activePolicies(bundleNftId), 1, "expected one active policy");
        assertTrue(instanceBundleManager.getActivePolicy(bundleNftId, 0).eq(policyNftId), "active policy nft id in bundle manager not equal to policy nft id");
    }

    function test_Product_underwriteWithPayment() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProduct();  

        

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        MockProduct dproduct = MockProduct(address(product));
        dproduct.createRisk(riskId, data);

        vm.stopPrank();

        vm.startPrank(customer);

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        token.approve(address(productSetupInfo.tokenHandler), 1000);
        // revert("checkApprove");

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            30,
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.stopPrank();

        // WHEN
        vm.startPrank(productOwner);
        dproduct.underwrite(policyNftId, true, TimestampLib.blockTimestamp()); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not UNDERWRITTEN");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount, 1000, "lockedAmount not 1000");
        assertEq(bundleInfo.balanceAmount, 10000 + 130, "lockedAmount not 1000");
        
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt == policyInfo.activatedAt.addSeconds(30), "expiredAt not activatedAt + 30");

        assertEq(token.balanceOf(address(product)), 10, "product balance not 10");
        assertEq(token.balanceOf(address(customer)), 860, "customer balance not 860");
        assertEq(token.balanceOf(address(pool)), 10130, "pool balance not 130");

        assertEq(instanceBundleManager.activePolicies(bundleNftId), 1, "expected one active policy");
        assertTrue(instanceBundleManager.getActivePolicy(bundleNftId, 0).eq(policyNftId), "active policy nft id in bundle manager not equal to policy nft id");
    }

    function test_underwrite_reverts_on_locked_bundle() public {
        // GIVEN
        _prepareProduct();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        MockProduct dproduct = MockProduct(address(product));
        dproduct.createRisk(riskId, data);

        vm.stopPrank();

        vm.startPrank(customer);
        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            30,
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        vm.stopPrank();

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        vm.startPrank(investor);
        pool.lockBundle(bundleNftId);

        Timestamp now = TimestampLib.blockTimestamp();

        // THEN - WHEN - try underwrite on locked bundle
        vm.expectRevert();
        dproduct.underwrite(policyNftId, false, now); 

        // WHEN - unlock bundle and try underwrite again
        pool.unlockBundle(bundleNftId);
        dproduct.underwrite(policyNftId, false, now);

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not UNDERWRITTEN");
    }

    function test_activate() public {
        // GIVEN
        _prepareProduct();  

        

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        MockProduct dproduct = MockProduct(address(product));
        dproduct.createRisk(riskId, data);

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            30,
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        // WHEN
        dproduct.underwrite(policyNftId, false, zeroTimestamp()); 

        // THEN 
        assertTrue(instanceReader.getPolicyState(policyNftId) == UNDERWRITTEN(), "policy state not UNDERWRITTEN");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount, 1000, "lockedAmount not 1000");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.eqz(), "activatedAt set");
        assertTrue(policyInfo.expiredAt.eqz(), "expiredAt set");
        
        // another WHEN
        dproduct.activate(policyNftId, TimestampLib.blockTimestamp());
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not ACTIVE");

        // and THEN
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt == policyInfo.activatedAt.addSeconds(30), "expiredAt not activatedAt + 30");
    }

    function test_createRisk() public {
        _prepareProduct();
        vm.startPrank(productOwner);

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";

        MockProduct dproduct = MockProduct(address(product));
        dproduct.createRisk(riskId, data);
        IRisk.RiskInfo memory riskInfo = instanceReader.getRiskInfo(riskId);

        assertTrue(riskInfo.productNftId.eq(productNftId), "productNftId not set");
        assertEq(riskInfo.data, data, "data not set");

        vm.stopPrank();
    }

    function test_updateRisk() public {
        _prepareProduct();
        vm.startPrank(productOwner);

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";

        MockProduct dproduct = MockProduct(address(product));
        dproduct.createRisk(riskId, data);
        IRisk.RiskInfo memory riskInfo = instanceReader.getRiskInfo(riskId);

        assertTrue(riskInfo.productNftId.eq(productNftId), "productNftId not set");
        assertEq(riskInfo.data, data, "data not set");

        bytes memory newData = "new data";
        dproduct.updateRisk(riskId, newData);

        riskInfo = instanceReader.getRiskInfo(riskId);

        assertTrue(riskInfo.productNftId.eq(productNftId), "productNftId not set");
        assertEq(riskInfo.data, newData, "data not updated to new data");
    }

    

    function _prepareProduct() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new MockProduct(
            address(registry),
            instanceNftId,
            address(token),
            false,
            address(pool), 
            address(distribution),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            productOwner
        );

        productNftId = productService.register(address(product));
        product.setProductNftId(productNftId);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution.setProductNftId(productNftId);
        Fee memory distributionFee = FeeLib.toFee(UFixedLib.zero(), 10);
        distribution.setFees(distributionFee);
        vm.stopPrank();


        vm.startPrank(poolOwner);
        pool.setProductNftId(productNftId);
        Fee memory poolFee = FeeLib.toFee(UFixedLib.zero(), 10);
        pool.setFees(poolFee, FeeLib.zeroFee(), FeeLib.zeroFee());
        vm.stopPrank();

        vm.startPrank(registryOwner);
        token.transfer(investor, 10000);
        vm.stopPrank();

        vm.startPrank(investor);
        ISetup.PoolSetupInfo memory poolSetupInfo = instanceReader.getPoolSetupInfo(poolNftId);
        token.approve(address(poolSetupInfo.tokenHandler), 10000);

        Fee memory bundleFee = FeeLib.toFee(UFixedLib.zero(), 10);
        bundleNftId = pool.createBundle(
            bundleFee, 
            10000, 
            604800, 
            ""
        );
        vm.stopPrank();
    }

    

}
