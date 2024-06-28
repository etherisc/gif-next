// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {BasicDistributionAuthorization} from "../contracts/distribution/BasicDistributionAuthorization.sol";
import {GifTest} from "./base/GifTest.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {DISTRIBUTION_OWNER_ROLE} from "../contracts/type/RoleId.sol";
import {IComponent} from "../contracts/shared/IComponent.sol";
import {IComponentService} from "../contracts/shared/IComponentService.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {IAccess} from "../contracts/instance/module/IAccess.sol";
import {Fee, FeeLib} from "../contracts/type/Fee.sol";
import {UFixedLib} from "../contracts/type/UFixed.sol";
import {SimpleDistribution} from "./mock/SimpleDistribution.sol";
import {RiskId, RiskIdLib} from "../contracts/type/RiskId.sol";
import {ReferralId, ReferralLib} from "../contracts/type/Referral.sol";
import {Seconds, SecondsLib} from "../contracts/type/Seconds.sol";
import {ACTIVE} from "../contracts/type/StateId.sol";
import {TimestampLib} from "../contracts/type/Timestamp.sol";
import {Amount, AmountLib} from "../contracts/type/Amount.sol";

contract TestFees is GifTest {
    using NftIdLib for NftId;

    /// @dev test withdraw fees from distribution component as distribution owner
    function test_Fees_withdrawDistributionOwnerFees() public {
        // GIVEN
        _setupWithActivePolicy();

        // solhint-disable-next-line 
        Amount distributionFee = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFee.toInt(), 20, "distribution fee not 20"); // 20% of the 10% premium -> 20

        uint256 distributionOwnerBalanceBefore = token.balanceOf(distributionOwner);
        uint256 distributionBalanceBefore = token.balanceOf(address(distribution));
        vm.stopPrank();

        // WHEN
        vm.startPrank(distributionOwner);
        distribution.withdrawFees(AmountLib.toAmount(15));

        // THEN
        uint256 distributionOwnerBalanceAfter = token.balanceOf(distributionOwner);
        assertEq(distributionOwnerBalanceAfter, distributionOwnerBalanceBefore + 15, "distribution owner balance not 15 higher");
        uint256 distributionBalanceAfter = token.balanceOf(address(distribution));
        assertEq(distributionBalanceAfter, distributionBalanceBefore - 15, "distribution balance not 15 lower");

        Amount distributionFeeAfter = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFeeAfter.toInt(), 5, "distribution fee not 5");
    }

    /// @dev test withdraw fees from distribution component as distribution owner
    function test_Fees_withdrawPoolOwnerFees() public {
        // GIVEN
        _setupWithActivePolicy();

        // solhint-disable-next-line 
        Amount poolFee = instanceReader.getFeeAmount(poolNftId);
        assertEq(poolFee.toInt(), 5, "pool fee not 5"); // 5% of the 10% premium -> 5

        uint256 poolOwnerBalanceBefore = token.balanceOf(poolOwner);
        uint256 poolBalanceBefore = token.balanceOf(address(pool));
        vm.stopPrank();

        // WHEN
        vm.startPrank(poolOwner);
        pool.withdrawFees(AmountLib.toAmount(3));

        // THEN
        uint256 poolOwnerBalanceAfter = token.balanceOf(poolOwner);
        assertEq(poolOwnerBalanceAfter, poolOwnerBalanceBefore + 3, "pool owner balance not 3 higher");
        uint256 poolBalanceAfter = token.balanceOf(address(pool));
        assertEq(poolBalanceAfter, poolBalanceBefore - 3, "pool balance not 3 lower");

        Amount poolFeeAfter = instanceReader.getFeeAmount(poolNftId);
        assertEq(poolFeeAfter.toInt(), 2, "pool fee not 2");
    }

    function _setupWithActivePolicy() internal returns (NftId policyNftId) {
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProduct();  

        // setup pool fees
        vm.startPrank(poolOwner);
        pool.setFees(
            FeeLib.percentageFee(5), 
            FeeLib.zero(),
            FeeLib.zero());
        vm.stopPrank();


        vm.startPrank(productOwner);
        
        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        product.createRisk(riskId, data);
        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);
        // revert("checkApprove");

        // crete application
        // solhint-disable-next-line 
        console.log("before application creation");

        uint sumInsuredAmount = 1000;
        Seconds lifetime = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        vm.stopPrank();

        assertTrue(policyNftId.gtz(), "policyNftId was zero");

        vm.startPrank(productOwner);

        // solhint-disable-next-line 
        console.log("before collateralization of", policyNftId.toInt());
        product.collateralize(policyNftId, true, TimestampLib.blockTimestamp()); 

        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not COLLATERALIZED");
    }
}