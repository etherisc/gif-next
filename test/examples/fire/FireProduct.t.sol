// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {APPLIED, COLLATERALIZED, PAID} from "../../../contracts/type/StateId.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {ONE_YEAR} from "../../../contracts/examples/fire/FireProduct.sol";
import {FireTestBase} from "./FireTestBase.t.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";

// solhint-disable func-name-mixedcase
contract FireProductTest is FireTestBase {

    string public cityName;
    NftId public policyNftId;

    function setUp() public override {
        super.setUp();
        
        _createInitialBundle();
        cityName = "London";
    }

    function test_FireProduct_calculatePremium() public {
        // GIVEN
        // 100'000 FireUSD
        Amount sumInsured = AmountLib.toAmount(100000 * 10**6);

        // WHEN
        Amount premium = fireProduct.calculatePremium(
            cityName, 
            sumInsured, 
            ONE_YEAR(),
            bundleNftId);
        
        // THEN - premium is 5k (5% of 100k for one full year) + 100 (2% of 5k bundle fee)
        assertEq((5000 + 100) * 10 ** 6, premium.toInt());
    }

    function test_FireProduct_createApplication() public {
        // GIVEN
        vm.startPrank(customer);
        
        // 100'000 FireUSD
        Amount sumInsured = AmountLib.toAmount(100000 * 10**6);
        
        // WHEN - apply for application is called
        policyNftId = fireProduct.createApplication(
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            bundleNftId);
        
        // THEN - check application
        assertTrue(! policyNftId.eqz());

        assertTrue(APPLIED().eq(instanceReader.getPolicyState(policyNftId)));
        IPolicy.PolicyInfo memory policy = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(fireProductNftId.eq(policy.productNftId));
        assertTrue(bundleNftId.eq(policy.bundleNftId));
        assertTrue(fireProduct.riskId(cityName).eq(policy.riskId));
        assertEq(sumInsured.toInt(), policy.sumInsuredAmount.toInt());
        assertEq((5000 + 100) * 10 ** 6, policy.premiumAmount.toInt());
        assertEq(ONE_YEAR().toInt(), policy.lifetime.toInt());
        assertEq(0, policy.claimsCount);
        assertEq(0, policy.activatedAt.toInt());
        assertEq(0, policy.expiredAt.toInt());
        assertEq(0, policy.closedAt.toInt());
    }

    function test_FireProduct_createPolicy() public {
        // GIVEN
        vm.startPrank(customer);
        
        // 100'000 FireUSD
        Amount sumInsured = AmountLib.toAmount(100000 * 10**6);
        Amount premium = fireProduct.calculatePremium(
            cityName, 
            sumInsured, 
            ONE_YEAR(),
            bundleNftId);
        
        policyNftId = fireProduct.createApplication(
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            bundleNftId);

        fireUSD.approve(address(fireProduct.getTokenHandler()), premium.toInt());
        vm.stopPrank();

        assertTrue(APPLIED().eq(instanceReader.getPolicyState(policyNftId)));
        Timestamp now = TimestampLib.blockTimestamp();

        uint256 tokenBalanceCustomerBefore = fireUSD.balanceOf(customer);
        uint256 tokenBalancePoolBefore = fireUSD.balanceOf(firePool.getWallet());
        Amount balancePoolBefore = instanceReader.getBalanceAmount(firePoolNftId);
        Amount balanceBundleBefore = instanceReader.getBalanceAmount(bundleNftId);
        Amount bundleFeeBefore = instanceReader.getFeeAmount(bundleNftId);
        
        // WHEN - policy is created
        fireProduct.createPolicy(policyNftId, now);

        // THEN - check created policy
        assertTrue(COLLATERALIZED().eq(instanceReader.getPolicyState(policyNftId)));

        IPolicy.PolicyInfo memory policy = instanceReader.getPolicyInfo(policyNftId);
        assertEq(now, policy.activatedAt, "policy.activatedAt mismatch");
        assertEq(now.addSeconds(ONE_YEAR()), policy.expiredAt, "policy.expiredAt mismatch");
        assertEq(TimestampLib.zero(), policy.closedAt, "policy.closedAt mismatch");

        // check premium state is PAID (product uses immediate payment) and then check the premium values
        assertTrue(PAID().eq(instanceReader.getPremiumInfoState(policyNftId)));
        IPolicy.PremiumInfo memory premiumInfo = instanceReader.getPremiumInfo(policyNftId);
        assertEq((5000 + 100) * 10 ** 6, premiumInfo.fullPremiumAmount.toInt());
        assertEq(premium, premiumInfo.fullPremiumAmount, "premiumInfo.fullPremiumAmount mismatch");
        assertEq((5000) * 10 ** 6, premiumInfo.netPremiumAmount.toInt());
        assertEq(0, premiumInfo.bundleFeeFixAmount.toInt());
        assertEq((100) * 10 ** 6, premiumInfo.bundleFeeVarAmount.toInt());

        // ensure tokens were transferred and balances updates
        assertEq(tokenBalanceCustomerBefore - premium.toInt(), fireUSD.balanceOf(customer), "token balance of customer mismatch");
        assertEq(tokenBalancePoolBefore + premium.toInt(), fireUSD.balanceOf(firePool.getWallet()), "token balance of pool mismatch");
        assertEq(balancePoolBefore + premium, instanceReader.getBalanceAmount(firePoolNftId), "pool balance mismatch");
        assertEq(balanceBundleBefore + premium, instanceReader.getBalanceAmount(bundleNftId), "bundle balance mismatch");
        assertEq(bundleFeeBefore + AmountLib.toAmount(100 * 10 ** 6), instanceReader.getFeeAmount(bundleNftId), "bundle fee mismatch");
    }

    function _createInitialBundle() internal {
        vm.startPrank(investor);
        Fee memory bundleFee = FeeLib.percentageFee(2);
        Amount investAmount = AmountLib.toAmount(10000000 * 10 ** 6);
        fireUSD.approve(
            address(firePool.getTokenHandler()), 
            investAmount.toInt());
        (bundleNftId,) = firePool.createBundle(
            bundleFee, 
            investAmount, 
            SecondsLib.toSeconds(5 * 365 * 24 * 60 * 60)); // 5 years
        vm.stopPrank();
    }
}