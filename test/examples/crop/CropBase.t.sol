// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IBaseStore} from "../../../contracts/instance/IBaseStore.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";

import {AccountingToken} from "../../../contracts/examples/crop/AccountingToken.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {FlightOracle} from "../../../contracts/examples/flight/FlightOracle.sol";
import {FlightOracleAuthorization} from "../../../contracts/examples/flight/FlightOracleAuthorization.sol";
import {CropPool} from "../../../contracts/examples/crop/CropPool.sol";
import {CropPoolAuthorization} from "../../../contracts/examples/crop/CropPoolAuthorization.sol";
import {CropProduct} from "../../../contracts/examples/crop/CropProduct.sol";
import {CropProductAuthorization} from "../../../contracts/examples/crop/CropProductAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {Location} from "../../../contracts/examples/crop/Location.sol";
import {RequestId} from "../../../contracts/type/RequestId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {RoleId} from "../../../contracts/type/RoleId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Str, StrLib} from "../../../contracts/type/String.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {VersionPartLib} from "../../../contracts/type/Version.sol";


contract CropBaseTest is GifTest {

    address public cropOwner = makeAddr("cropOwner");
    address public productOperator = makeAddr("productOperator");

    uint8 public constant MAX_POLICIES_IN_ONE_GO = 2;

    AccountingToken public accountingToken;
    FlightOracle public flightOracle;
    CropPool public cropPool;

    CropProduct public cropProduct;

    NftId public flightOracleNftId;
    NftId public cropPoolNftId;
    NftId public cropProductNftId;

    function setUp() public virtual override {
        customer = makeAddr("farmer");
        
        super.setUp();
        
        _deployAccountingToken();
        _deployCropProduct();
        _deployCropPool();

        // do some initial funding
        _initialFundAccounts();
    }


    function _deployAccountingToken() internal {
        // deploy fire token
        vm.startPrank(cropOwner);
        accountingToken = new AccountingToken();
        vm.stopPrank();

        // whitelist fire token and make it active for release 3
        vm.startPrank(registryOwner);
        tokenRegistry.registerToken(address(accountingToken));
        tokenRegistry.setActiveForVersion(
            currentChainId, 
            address(accountingToken), 
            VersionPartLib.toVersionPart(3),
            true);
        vm.stopPrank();
    }


    function _deployCropProduct() internal {

        vm.startPrank(cropOwner);
        CropProductAuthorization productAuthz = new CropProductAuthorization("CropProduct");
        cropProduct = new CropProduct(
            address(registry),
            instanceNftId,
            "CropProduct",
            productAuthz
        );
        vm.stopPrank();

        // instance owner registeres fire product with instance (and registry)
        vm.startPrank(instanceOwner);
        cropProductNftId = instance.registerProduct(
            address(cropProduct), 
            address(accountingToken));

        // grant statistics provider role to statistics provider
        (RoleId productOperatorRoleId, bool exists) = instanceReader.getRoleForName(
            productAuthz.PRODUCT_OPERATOR_ROLE_NAME());

        assertTrue(exists, "role PRODUCT_OPERATOR_ROLE_NAME missing");
        instance.grantRole(productOperatorRoleId, productOperator);
        vm.stopPrank();

        // complete setup
        vm.startPrank(cropOwner);
        cropProduct.setConstants(
            AmountLib.toAmount(10 * 10 ** accountingToken.decimals()), // min premium
            AmountLib.toAmount(99 * 10 ** accountingToken.decimals()), // max premium
            AmountLib.toAmount(200 * 10 ** accountingToken.decimals()), // min sum insured
            AmountLib.toAmount(1000 * 10 ** accountingToken.decimals()), // max sum insured
            5 // max policies to process
        );
        vm.stopPrank();
    }


    function _deployCropPool() internal {
        vm.startPrank(cropOwner);
        CropPoolAuthorization poolAuthz = new CropPoolAuthorization("CropPool");
        cropPool = new CropPool(
            address(registry),
            cropProductNftId,
            "CropPool",
            poolAuthz
        );
        vm.stopPrank();

        cropPoolNftId = _registerComponent(
            cropOwner, 
            cropProduct, 
            address(cropPool), 
            "cropPool");
    }


    function _createInitialBundle() internal returns (NftId bundleNftId) {
        vm.startPrank(cropOwner);
        Amount investAmount = AmountLib.toAmount(10000000 * 10 ** 6);
        accountingToken.approve(
            address(cropPool.getTokenHandler()), 
            investAmount.toInt());
        bundleNftId = cropPool.createBundle(investAmount);
        vm.stopPrank();
    }


    function _initialFundAccounts() internal {
        _fundAccount(cropOwner, 100000 * 10 ** accountingToken.decimals());
        _fundAccount(productOperator, 100000 * 10 ** accountingToken.decimals());
        _fundAccount(customer, 10000 * 10 ** accountingToken.decimals());

        vm.startPrank(customer);
        accountingToken.approve(
            address(cropProduct.getTokenHandler()), 
            accountingToken.balanceOf(customer));
        vm.stopPrank();
    }


    function _fundAccount(address account, uint256 amount) internal {
        vm.startPrank(cropOwner);
        accountingToken.transfer(account, amount);
        vm.stopPrank();
    }


    // function _printStatusRequest(FlightOracle.FlightStatusRequest memory statusRequest) internal {
    //     // solhint-disable
    //     console.log("FlightStatusRequest (requestData)", statusRequest.riskId.toInt());
    //     console.log("- riskId", statusRequest.riskId.toInt());
    //     console.log("- flightData", statusRequest.flightData.toString());
    //     console.log("- departureTime", statusRequest.departureTime.toInt());
    //     // solhint-enable
    // }


    // function _printRequest(RequestId requestId, IOracle.RequestInfo memory requestInfo) internal {
    //     // solhint-disable
    //     console.log("requestId", requestId.toInt());
    //     console.log("- state", instanceReader.getRequestState(requestId).toInt());
    //     console.log("- requesterNftId", requestInfo.requesterNftId.toInt());
    //     console.log("- oracleNftId", requestInfo.oracleNftId.toInt());
    //     console.log("- isCancelled", requestInfo.isCancelled);
    //     console.log("- respondedAt", requestInfo.respondedAt.toInt());
    //     console.log("- expiredAt", requestInfo.expiredAt.toInt());
    //     console.log("- callbackMethodName", requestInfo.callbackMethodName);
    //     console.log("- requestData.length", requestInfo.requestData.length);
    //     console.log("- responseData.length", requestInfo.responseData.length);
    //     // solhint-enable
    // }


    function _printRisk(RiskId riskId, CropProduct.CropRisk memory cropRisk) internal {
        // solhint-disable
        console.log("riskId", riskId.toInt());
        console.log("- seasonId", cropRisk.seasonId.toString());
        console.log("- locationId", cropRisk.locationId.toString());
        console.log("- crop", cropRisk.crop.toString());
        console.log("- seasonEndAt", cropRisk.seasonEndAt.toInt());
        console.log("- payoutFactor (%)", (cropRisk.payoutFactor * UFixedLib.toUFixed(100)).toInt());
        console.log("- payoutDefined", cropRisk.payoutDefined);

        CropProduct.Season memory season = cropProduct.getSeason(cropRisk.seasonId);
        console.log("- season", season.year);
        console.log("  - season name", season.name.toString());
        console.log("  - season start", season.seasonStart.toString());
        console.log("  - season end", season.seasonEnd.toString());
        console.log("  - season days", season.seasonDays);

        Location location = cropProduct.getLocation(cropRisk.locationId);
        console.log("- location");
        console.log("  - latitude", location.latitude());
        console.log("  - longitude", location.longitude());
        // solhint-enable
    }


    function _printPolicy(NftId policyNftId, IPolicy.PolicyInfo memory policyInfo) internal {
        // solhint-disable
        console.log("policy", policyNftId.toInt());
        console.log("- productNftId", policyInfo.productNftId.toInt());
        console.log("- bundleNftId", policyInfo.bundleNftId.toInt());
        console.log("- riskId referralId", policyInfo.riskId.toInt(), policyInfo.referralId.toInt());
        console.log("- state", instanceReader.getPolicyState(policyNftId).toInt());
        console.log("- activatedAt lifetime", policyInfo.activatedAt.toInt(), policyInfo.lifetime.toInt());
        console.log("- expiredAt closedAt", policyInfo.expiredAt.toInt(), policyInfo.closedAt.toInt());
        console.log("- sumInsuredAmount", policyInfo.sumInsuredAmount.toInt());
        console.log("- premiumAmount", policyInfo.premiumAmount.toInt());
        console.log("- claimsCount claimAmount", policyInfo.claimsCount, policyInfo.claimAmount.toInt());
        console.log("- payoutAmount", policyInfo.payoutAmount.toInt());
        // solhint-enable
    }


    function _printMetadata(IBaseStore.Metadata memory metadata) internal {
        // solhint-disable
        console.log("metadata");
        console.log("- objectType", metadata.objectType.toInt());
        console.log("- state", metadata.state.toInt());
        console.log("- updatedIn", metadata.updatedIn.toInt());
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