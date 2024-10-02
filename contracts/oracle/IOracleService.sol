// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IService} from "../shared/IService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RequestId} from "../type/RequestId.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";


interface IOracleService is IService {

    event LogOracleServiceRequestCreated(RequestId requestId, NftId requesterNftId, NftId oracleNftId, Timestamp expiryAt);
    event LogOracleServiceResponseProcessed(RequestId requestId, NftId oracleNftId);
    event LogOracleServiceDeliveryFailed(RequestId requestId, address requesterAddress, string functionSignature);
    event LogOracleServiceResponseResent(RequestId requestId, NftId requesterNftId);
    event LogOracleServiceRequestCancelled(RequestId requestId, NftId requesterNftId);

    // create request
    error ErrorOracleServiceExpiryInThePast(Timestamp blockTimestamp, Timestamp expiryAt);
    error ErrorOracleServiceCallbackMethodNameEmpty();

    // get request info
    error ErrorOracleServiceRequestStateNotActive(RequestId requestId, StateId state);
    error ErrorOracleServiceCallerNotResponsibleOracle(RequestId requestId, NftId oracleNftId, NftId callerNftId);
    error ErrorOracleServiceCallerNotRequester(RequestId requestId, NftId requesterNftId, NftId callerNftId);
    error ErrorOracleServiceRequestExpired(RequestId requestId, Timestamp expiredAt);
    
    /// @dev send an oracle request to the specified oracle component.
    /// the function returns the id of the newly created request.
    /// permissioned: only registered components may send requests to oracles.
    function request(
        NftId oracleNftId,
        bytes calldata requestData,
        Timestamp expiryAt,
        string calldata callbackMethodName
    ) external returns (RequestId requestId);

    /// @dev Respond to oracle request by oracle compnent.
    /// The response data is amended in the request info stored with the instance.
    /// The request state changes to FULFILLED (when calling the callback method of the requester is successful)
    /// or to FAILED when calling the requester is not succesful.
    /// The function returns true iff the state changes to FULFILLED.
    /// Permissioned: only the receiving oracle component may call this method
    function respond(
        RequestId requestId,
        bytes calldata responseData
    ) external returns (bool success);

    /// @dev Resend a failed response to the requester.
    /// Only requests in state FAILED may be resent.
    /// The request state changes to FULFILLED when calling the callback method of the requester is successful.
    /// Permissioned: only the receiving oracle may resend a request
    function resend(RequestId requestId) external;

    /// @dev Notify the oracle component that the specified request has become invalid.
    /// Only requests in state ACTIVE may be cancelled.
    /// Permissioned: only the requester may cancel a request
    function cancel(RequestId requestId) external;

}