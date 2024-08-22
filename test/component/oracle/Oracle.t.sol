// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Vm, console} from "../../../lib/forge-std/src/Test.sol";

import {GifTest} from "../../base/GifTest.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {SimpleOracle} from "../../../contracts/examples/unpermissioned/SimpleOracle.sol";
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
import {SUBMITTED, ACTIVE, CANCELLED, FAILED, FULFILLED} from "../../../contracts/type/StateId.sol";
import {StateId} from "../../../contracts/type/StateId.sol";

contract TestOracle is GifTest {

    // from SimpleOracle
    event LogSimpleOracleRequestReceived(RequestId requestId, NftId requesterId, bool synchronous, string requestText);
    event LogSimpleOracleCancellingReceived(RequestId requestId);
    event LogSimpleOracleAsyncResponseSent(RequestId requestId, string responseText);

    // from SimpleProduct
    event LogSimpleProductRequestAsyncFulfilled(RequestId requestId, string responseText, uint256 responseDataLength);
    event LogSimpleProductRequestSyncFulfilled(RequestId requestId, string responseText, uint256 responseDataLength);

    // from IOracleService
    event LogOracleServiceResponseProcessed(RequestId requestId, NftId oracleNftId);
    event LogOracleServiceDeliveryFailed(RequestId requestId, address requesterAddress, string functionSignature);
    event LogOracleServiceResponseResent(RequestId requestId, NftId requesterNftId);


    function setUp() public override {
        super.setUp();

        _prepareProduct();  
    }


    function test_oracleRequestCreateAsyncHappyCase() public {

        // GIVEN
        string memory requestText = "some question for the oracle to answer";
        Timestamp expiryAt = TimestampLib.blockTimestamp().addSeconds(
            SecondsLib.oneYear());

        // check that oracle component has received oracle request
        RequestId expectedRequestId = RequestIdLib.toRequestId(1);
        vm.expectEmit(address(oracle));
        emit LogSimpleOracleRequestReceived(
            expectedRequestId, 
            productNftId,
            false,
            requestText);

        // WHEN
        bool synchronous = false;
        RequestId requestId = product.createOracleRequest(
            oracleNftId, 
            requestText,
            expiryAt,
            synchronous);

        // THEN
        console.log("requestId", requestId.toInt());
        assertTrue(requestId.gtz(), "request id 0");
        assertEq(requestId.toInt(), 1, "request id not 1");

        // check request info
        IOracle.RequestInfo memory request = instanceReader.getRequestInfo(requestId);
        bytes memory expectedRequestData = abi.encode(SimpleOracle.SimpleRequest(
            synchronous,
            requestText));

        assertEq(request.requesterNftId.toInt(), productNftId.toInt(), "requester not product");
        assertEq(request.callbackMethodName, "fulfillOracleRequestAsync", "unexpected callback name");
        assertEq(request.oracleNftId.toInt(), oracleNftId.toInt(), "unexpected oracle nft id");
        assertEq(request.requestData, expectedRequestData, "unexpected request data");
        assertEq(request.expiredAt.toInt(), expiryAt.toInt(), "unexpected expired at");

        // check request state
        StateId requestState = instanceReader.getState(requestId.toKey32());
        assertEq(requestState.toInt(), ACTIVE().toInt(), "unexpected request state");
    }


    function test_oracleRequestCreateSyncHappyCase() public {

        // GIVEN
        string memory requestText = "some sync question";
        Timestamp expiryAt = TimestampLib.blockTimestamp().addSeconds(
            SecondsLib.oneYear());

        RequestId expectedRequestId = RequestIdLib.toRequestId(1);

        // check that sync answer from oracle reaches product
        uint256 expectedResponseLength = bytes(oracle.ANSWER_SYNC()).length;
        vm.expectEmit(address(product));
        emit LogSimpleProductRequestSyncFulfilled(
            expectedRequestId, 
            oracle.ANSWER_SYNC(),
            expectedResponseLength);

        // check that oracle component has received oracle request
        vm.expectEmit(address(oracle));
        emit LogSimpleOracleRequestReceived(
            expectedRequestId, 
            productNftId,
            true,
            requestText);

        // WHEN
        bool synchronous = true;
        RequestId requestId = product.createOracleRequest(
            oracleNftId, 
            requestText,
            expiryAt,
            synchronous);

        // THEN
        console.log("requestId", requestId.toInt());
        assertTrue(requestId.gtz(), "request id 0");
        assertEq(requestId.toInt(), 1, "request id not 1");

        // check request info
        IOracle.RequestInfo memory request = instanceReader.getRequestInfo(requestId);
        bytes memory expectedRequestData = abi.encode(SimpleOracle.SimpleRequest(
            synchronous,
            requestText));
        
        bytes memory expectedResponseData = abi.encode(oracle.ANSWER_SYNC());

        assertEq(request.requesterNftId.toInt(), productNftId.toInt(), "requester not product");
        assertEq(request.callbackMethodName, "fulfillOracleRequestSync", "unexpected callback name");
        assertEq(request.oracleNftId.toInt(), oracleNftId.toInt(), "unexpected oracle nft id");
        assertEq(request.requestData, expectedRequestData, "unexpected request data");
        assertEq(request.responseData, expectedResponseData, "unexpected response data");
        assertEq(request.expiredAt.toInt(), expiryAt.toInt(), "unexpected expired at");

        // check request state
        StateId requestState = instanceReader.getState(requestId.toKey32());
        assertEq(requestState.toInt(), FULFILLED().toInt(), "unexpected request state");
    }


    function test_oracleResponseAsyncHappyCase() public {

        // GIVEN
        string memory requestText = "some question for the oracle to answer";
        Timestamp expiryAt = TimestampLib.blockTimestamp().addSeconds(
            SecondsLib.oneYear());

        bool synchronous = false;
        RequestId requestId = product.createOracleRequest(
            oracleNftId, 
            requestText,
            expiryAt,
            synchronous);

        string memory responseText = "async 42";

        // check product fulfillOracleRequestAsync has been called
        Timestamp revertUntil = TimestampLib.max();
        vm.expectEmit(address(product));
        emit LogSimpleProductRequestAsyncFulfilled(
            requestId, 
            responseText,
            bytes(responseText).length);

        // check that oracle component has received oracle request
        vm.expectEmit(address(oracle));
        emit LogSimpleOracleAsyncResponseSent(
            requestId, 
            responseText);
        
        // actual LogSimpleOracleAsyncResponseSent(requestId: 1, responseText: "async 42")

        // WHEN
        oracle.respondAsync(
            requestId, 
            responseText,
            false, // revert in call
            revertUntil);

        // THEN
        // check request info
        IOracle.RequestInfo memory request = instanceReader.getRequestInfo(requestId);
        bytes memory expectedRequestData = abi.encode(SimpleOracle.SimpleRequest(
            synchronous,
            requestText));
        
        bytes memory expectedResponseData = abi.encode(
            SimpleOracle.SimpleResponse({
                revertInCall: false, 
                revertUntil: TimestampLib.max(),
                text: responseText}));

        assertEq(request.requesterNftId.toInt(), productNftId.toInt(), "requester not product");
        assertEq(request.callbackMethodName, "fulfillOracleRequestAsync", "unexpected callback name");
        assertEq(request.oracleNftId.toInt(), oracleNftId.toInt(), "unexpected oracle nft id");
        assertEq(request.requestData, expectedRequestData, "unexpected request data");
        assertEq(request.responseData, expectedResponseData, "unexpected response data");
        assertEq(request.expiredAt.toInt(), expiryAt.toInt(), "unexpected expired at");

        // check request state
        StateId requestState = instanceReader.getState(requestId.toKey32());
        assertEq(requestState.toInt(), FULFILLED().toInt(), "unexpected request state");
    }


    function test_oracleResponseAsyncWithRequesterRevert() public {

        // GIVEN
        string memory requestText = "some question for the oracle to answer";
        Timestamp expiryAt = TimestampLib.blockTimestamp().addSeconds(
            SecondsLib.oneYear());

        bool synchronous = false;
        RequestId requestId = product.createOracleRequest(
            oracleNftId, 
            requestText,
            expiryAt,
            synchronous);

        string memory responseText = "async /w revert";

        // check product fulfillOracleRequestAsync has been called
        Timestamp revertUntil = TimestampLib.max();
        vm.expectEmit(address(oracleService));
        emit LogOracleServiceDeliveryFailed(
            requestId, 
            address(product),
            "fulfillOracleRequestAsync(uint64,bytes)");

        // check that oracle component has received oracle request
        vm.expectEmit(address(oracleService));
        emit LogOracleServiceResponseProcessed(
            requestId, 
            oracleNftId);

        // WHEN
        oracle.respondAsync(
            requestId, 
            responseText,
            true, // revert in call
            revertUntil);

        // THEN
        // check request info
        IOracle.RequestInfo memory request = instanceReader.getRequestInfo(requestId);
        bytes memory expectedRequestData = abi.encode(SimpleOracle.SimpleRequest(
            synchronous,
            requestText));
        
        bytes memory expectedResponseData = abi.encode(
            SimpleOracle.SimpleResponse({
                revertInCall: true, 
                revertUntil: revertUntil,
                text: responseText}));

        assertEq(request.requesterNftId.toInt(), productNftId.toInt(), "requester not product");
        assertEq(request.callbackMethodName, "fulfillOracleRequestAsync", "unexpected callback name");
        assertEq(request.oracleNftId.toInt(), oracleNftId.toInt(), "unexpected oracle nft id");
        assertEq(request.requestData, expectedRequestData, "unexpected request data");
        assertEq(request.responseData, expectedResponseData, "unexpected response data");
        assertEq(request.expiredAt.toInt(), expiryAt.toInt(), "unexpected expired at");

        // check request state
        StateId requestState = instanceReader.getState(requestId.toKey32());
        assertEq(requestState.toInt(), FAILED().toInt(), "unexpected request state");
    }


    function test_oracleResponseAsyncResendHappyCase() public {

        // GIVEN
        string memory requestText = "some question for the oracle to answer";
        Timestamp expiryAt = TimestampLib.blockTimestamp().addSeconds(
            SecondsLib.oneYear());

        bool synchronous = false;
        RequestId requestId = product.createOracleRequest(
            oracleNftId, 
            requestText,
            expiryAt,
            synchronous);

        string memory responseText = "async /w revert to replay";
        Timestamp revertUntil = TimestampLib.blockTimestamp();

        oracle.respondAsync(
            requestId, 
            responseText,
            true, // revert in call
            revertUntil);

        // check failed state
        StateId requestState = instanceReader.getState(requestId.toKey32());
        assertEq(requestState.toInt(), FAILED().toInt(), "unexpected request state");

        // ensure callback doesn't revert anymore
        vm.warp(revertUntil.toInt() + 1); 

        vm.expectEmit(address(product));
        emit LogSimpleProductRequestAsyncFulfilled(
            requestId, 
            responseText,
            bytes(responseText).length);

        vm.expectEmit(address(oracleService));
        emit LogOracleServiceResponseResent(
            requestId, 
            productNftId);

        // WHEN
        product.resend(requestId);

        // THEN
        // check request info
        IOracle.RequestInfo memory request = instanceReader.getRequestInfo(requestId);

        assertEq(request.requesterNftId.toInt(), productNftId.toInt(), "requester not product");
        assertEq(request.callbackMethodName, "fulfillOracleRequestAsync", "unexpected callback name");
        assertEq(request.oracleNftId.toInt(), oracleNftId.toInt(), "unexpected oracle nft id");
        assertEq(request.expiredAt.toInt(), expiryAt.toInt(), "unexpected expired at");

        // check request state
        requestState = instanceReader.getState(requestId.toKey32());
        assertEq(requestState.toInt(), FULFILLED().toInt(), "unexpected request state");
    }


    function test_oracleRequestCancelHappyCase() public {

        // GIVEN
        string memory requestText = "some question for the oracle to answer";
        Timestamp expiryAt = TimestampLib.blockTimestamp().addSeconds(
            SecondsLib.oneYear());

        bool synchronous = false;
        RequestId requestId = product.createOracleRequest(
            oracleNftId, 
            requestText,
            expiryAt,
            synchronous);

        // check that oracle component has received the cancelling
        vm.expectEmit(address(oracle));
        emit LogSimpleOracleCancellingReceived(
            requestId);

        // WHEN
        product.cancelOracleRequest(requestId);

        // THEN
        // check request info
        IOracle.RequestInfo memory request = instanceReader.getRequestInfo(requestId);
        bytes memory expectedRequestData = abi.encode(SimpleOracle.SimpleRequest(
            synchronous,
            requestText));

        assertEq(request.requesterNftId.toInt(), productNftId.toInt(), "requester not product");
        assertEq(request.callbackMethodName, "fulfillOracleRequestAsync", "unexpected callback name");
        assertEq(request.oracleNftId.toInt(), oracleNftId.toInt(), "unexpected oracle nft id");
        assertEq(request.requestData, expectedRequestData, "unexpected request data");
        assertEq(request.expiredAt.toInt(), expiryAt.toInt(), "unexpected expired at");

        // check request state
        StateId requestState = instanceReader.getState(requestId.toKey32());
        assertEq(requestState.toInt(), CANCELLED().toInt(), "unexpected request state");
    }
}
