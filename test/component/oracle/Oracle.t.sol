// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Vm, console} from "../../../lib/forge-std/src/Test.sol";

import {GifTest} from "../../base/GifTest.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {PRODUCT_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {SimpleProduct} from "../../mock/SimpleProduct.sol";
import {SimplePool} from "../../mock/SimplePool.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {ILifecycle} from "../../../contracts/shared/ILifecycle.sol";
import {IOracle} from "../../../contracts/oracle/IOracle.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../../contracts/type/Timestamp.sol";
import {IPolicyService} from "../../../contracts/product/IPolicyService.sol";
import {IRisk} from "../../../contracts/instance/module/IRisk.sol";
import {PayoutId, PayoutIdLib} from "../../../contracts/type/PayoutId.sol";
import {POLICY} from "../../../contracts/type/ObjectType.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralLib} from "../../../contracts/type/Referral.sol";
import {RequestId, RequestIdLib} from "../../../contracts/type/RequestId.sol";
import {SUBMITTED, ACTIVE, CANCELLED, FULFILLED} from "../../../contracts/type/StateId.sol";
import {StateId} from "../../../contracts/type/StateId.sol";

contract TestOracle is GifTest {

    event LogClaimTestClaimInfo(NftId policyNftId, IPolicy.PolicyInfo policyInfo, ClaimId claimId, IPolicy.ClaimInfo claimInfo);

    uint256 public constant BUNDLE_CAPITAL = 5000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant CUSTOMER_FUNDS = 400;
    
    RiskId public riskId;
    NftId public policyNftId;

    function setUp() public override {
        super.setUp();

        _prepareProduct();  
    }


    function test_OracleRequestCreateHappyCase() public {

        // GIVEN
        string memory requestText = "some question for the oracle to answer";
        Timestamp expiryAt = TimestampLib.blockTimestamp().addSeconds(
            SecondsLib.oneYear());

        // WHEN
        RequestId requestId = product.createOracleTextRequest(
            oracleNftId, 
            requestText,
            expiryAt);

        // THEN
        console.log("requestId", requestId.toInt());
        assertTrue(requestId.gtz(), "request id 0");
        assertEq(requestId.toInt(), 1, "request id not 1");

        // check request info
        IOracle.RequestInfo memory request = instanceReader.getRequestInfo(requestId);
        bytes memory requestData = abi.encode(requestText);
        assertEq(request.requesterNftId.toInt(), productNftId.toInt(), "requester not product");
        assertEq(request.callbackMethodName, "fulfillOracleTextRequest", "unexpected callback name");
        assertEq(request.oracleNftId.toInt(), oracleNftId.toInt(), "unexpected oracle nft id");
        assertEq(request.requestData, requestData, "unexpected request data");
        assertEq(request.expiredAt.toInt(), expiryAt.toInt(), "unexpected expired at");
        assertFalse(request.isCancelled, "request cancelled");

        // check request state
        StateId requestState = instanceReader.getState(requestId.toKey32());
        assertEq(requestState.toInt(), ACTIVE().toInt(), "unexpected request state");
    }


    function test_OracleRequestCancelHappyCase() public {

        // GIVEN
        string memory requestText = "some question for the oracle to answer";
        Timestamp expiryAt = TimestampLib.blockTimestamp().addSeconds(
            SecondsLib.oneYear());

        RequestId requestId = product.createOracleTextRequest(
            oracleNftId, 
            requestText,
            expiryAt);

        // WHEN
        product.cancelOracleTextRequest(requestId);

        // THEN
        // check request info
        IOracle.RequestInfo memory request = instanceReader.getRequestInfo(requestId);
        bytes memory requestData = abi.encode(requestText);
        assertEq(request.requesterNftId.toInt(), productNftId.toInt(), "requester not product");
        assertEq(request.callbackMethodName, "fulfillOracleTextRequest", "unexpected callback name");
        assertEq(request.oracleNftId.toInt(), oracleNftId.toInt(), "unexpected oracle nft id");
        assertEq(request.requestData, requestData, "unexpected request data");
        assertEq(request.expiredAt.toInt(), expiryAt.toInt(), "unexpected expired at");
        assertTrue(request.isCancelled, "request not cancelled");

        // check request state
        StateId requestState = instanceReader.getState(requestId.toKey32());
        assertEq(requestState.toInt(), CANCELLED().toInt(), "unexpected request state");
    }
}
