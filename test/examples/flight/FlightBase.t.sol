// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {FlightUSD} from "../../../contracts/examples/flight/FlightUSD.sol";
import {FlightPool} from "../../../contracts/examples/flight/FlightPool.sol";
import {FlightPoolAuthorization} from "../../../contracts/examples/flight/FlightPoolAuthorization.sol";
import {FlightProduct} from "../../../contracts/examples/flight/FlightProduct.sol";
import {FlightProductAuthorization} from "../../../contracts/examples/flight/FlightProductAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {VersionPartLib} from "../../../contracts/type/Version.sol";


contract FlightBaseTest is GifTest {

    address public flightOwner = makeAddr("flightOwner");

    FlightUSD public flightUSD;
    FlightPool public flightPool;
    FlightProduct public flightProduct;

    NftId public flightPoolNftId;
    NftId public flightProductNftId;

    function setUp() public virtual override {
        super.setUp();
        
        _deployFlightUSD();
        _deployFlightProduct();
        _deployFlightPool();
        _initialFundAccounts();
    }

    function _deployFlightUSD() internal {
        // deploy fire token
        vm.startPrank(flightOwner);
        flightUSD = new FlightUSD();
        vm.stopPrank();

        // whitelist fire token and make it active for release 3
        vm.startPrank(registryOwner);
        tokenRegistry.registerToken(address(flightUSD));
        tokenRegistry.setActiveForVersion(
            currentChainId, 
            address(flightUSD), 
            VersionPartLib.toVersionPart(3),
            true);
        vm.stopPrank();
    }

    function _deployFlightProduct() internal {
        vm.startPrank(flightOwner);
        FlightProductAuthorization productAuthz = new FlightProductAuthorization("FlightProduct");
        flightProduct = new FlightProduct(
            address(registry),
            instanceNftId,
            "FlightProduct",
            productAuthz
        );
        vm.stopPrank();

        // instance owner registeres fire product with instance (and registry)
        vm.prank(instanceOwner);
        flightProductNftId = instance.registerProduct(
            address(flightProduct), 
            address(flightUSD));

        // complete setup
        vm.prank(flightOwner);
        flightProduct.completeSetup();
    }

    function _deployFlightPool() internal {
        vm.startPrank(flightOwner);
        FlightPoolAuthorization poolAuthz = new FlightPoolAuthorization("FlightPool");
        flightPool = new FlightPool(
            address(registry),
            flightProductNftId,
            "FlightPool",
            poolAuthz
        );
        vm.stopPrank();

        flightPoolNftId = _registerComponent(
            flightOwner, 
            flightProduct, 
            address(flightPool), 
            "flightPool");
    }


    function _createInitialBundle() internal returns (NftId bundleNftId) {
        vm.startPrank(flightOwner);
        Amount investAmount = AmountLib.toAmount(10000000 * 10 ** 6);
        flightUSD.approve(
            address(flightPool.getTokenHandler()), 
            investAmount.toInt());
        bundleNftId = flightPool.createBundle(investAmount);
        vm.stopPrank();
    }


    function _initialFundAccounts() internal {
        _fundAccount(flightOwner, 100000 * 10 ** flightUSD.decimals());
        _fundAccount(customer, 10000 * 10 ** flightUSD.decimals());
    }


    function _fundAccount(address account, uint256 amount) internal {
        vm.startPrank(flightOwner);
        flightUSD.transfer(account, amount);
        vm.stopPrank();
    }

    function _printRisk(RiskId riskId, FlightProduct.FlightRisk memory flightRisk) internal {
        // solhint-disable
        console.log("riskId", riskId.toInt());
        console.log("- carrierFlightNumber", flightRisk.carrierFlightNumber.toString());
        console.log("- departureYearMonthDay", flightRisk.departureYearMonthDay.toString());
        console.log("- departureTime", flightRisk.departureTime.toInt());
        console.log("- arrivalTime", flightRisk.arrivalTime.toInt());
        console.log("- delaySeconds", flightRisk.delaySeconds.toInt());
        console.log("- delay", flightRisk.delay);
        console.log("- estimatedMaxTotalPayout", flightRisk.estimatedMaxTotalPayout.toInt());
        console.log("- premiumMultiplier", flightRisk.premiumMultiplier);
        console.log("- weight", flightRisk.weight);   
        // solhint-enable
    }

    function _printPolicy(NftId policyNftId, IPolicy.PolicyInfo memory policyInfo) internal {
        // solhint-disable
        console.log("policy", policyNftId.toInt());
        console.log("- productNftId", policyInfo.productNftId.toInt());
        console.log("- bundleNftId", policyInfo.bundleNftId.toInt());
        console.log("- riskId referralId", policyInfo.riskId.toInt(), policyInfo.referralId.toInt());
        console.log("- activatedAt lifetime", policyInfo.activatedAt.toInt(), policyInfo.lifetime.toInt());
        console.log("- expiredAt closedAt", policyInfo.expiredAt.toInt(), policyInfo.closedAt.toInt());
        console.log("- sumInsuredAmount", policyInfo.sumInsuredAmount.toInt());
        console.log("- premiumAmount", policyInfo.premiumAmount.toInt());
        console.log("- claimsCount claimAmount", policyInfo.claimsCount, policyInfo.claimAmount.toInt());
        console.log("- payoutAmount", policyInfo.payoutAmount.toInt());
        // solhint-enable
    }

    function _printPremium(NftId policyNftId, IPolicy.PremiumInfo memory premiumInfo) internal {
        // solhint-disable
        console.log("premium", policyNftId.toInt());
        console.log("- premiumAmount", premiumInfo.premiumAmount.toInt());
        console.log("- netPremiumAmount", premiumInfo.netPremiumAmount.toInt());
        console.log("- productFeeAmount", premiumInfo.productFeeAmount.toInt());
        console.log("- distributionFeeAndCommissionAmount", premiumInfo.distributionFeeAndCommissionAmount.toInt());
        console.log("- poolPremiumAndFeeAmount", premiumInfo.poolPremiumAndFeeAmount.toInt());
        console.log("- discountAmount", premiumInfo.discountAmount.toInt());
        // solhint-enable
    }
}