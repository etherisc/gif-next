// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IService} from "../shared/IService.sol";
import {NftId} from "../type/NftId.sol";
import {RequestId} from "../type/RequestId.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";


interface IOracleService is IService {

    event LogOracleServiceRequestCreated(RequestId requestId, NftId requesterNftId, NftId oracleNftId, Timestamp expiryAt);
    event LogOracleServiceResponseProcessed(RequestId requestId, NftId oracleNftId);
    event LogOracleServiceDeliveryFailed(RequestId requestId, address requesterAddress, string functionSignature);
    event LogOracleServiceResponseReplayed(RequestId requestId, NftId requesterNftId);
    event LogOracleServiceRequestCancelled(RequestId requestId, NftId requesterNftId);

    // create request
    error ErrorOracleServiceInstanceMismatch(NftId expectedInstanceNftId, NftId oracleInstanceNftId);
    error ErrorOracleServiceExpiryInThePast(Timestamp blockTimestamp, Timestamp expiryAt);
    error ErrorOracleServiceCallbackMethodNameEmpty();

    // respond
    error ErrorOracleServiceNotResponsibleOracle(RequestId requestId, NftId expectedOracleNftId, NftId oracleNftId);

    // get request info
    error ErrorOracleServiceRequestStateNotActive(RequestId requestId, StateId state);
    error ErrorOracleServiceCallerNotResponsibleOracle(RequestId requestId, NftId oracleNftId, NftId callerNftId);
    error ErrorOracleServiceCallerNotRequester(RequestId requestId, NftId requesterNftId, NftId callerNftId);
    error ErrorOracleServiceRequestExpired(RequestId requestId, Timestamp expiredAt);
    
    /// @dev send an oracle request to the specified oracle component.
    /// permissioned: only registered components may send requests to oracles.
    function request(
        NftId oracleNftId,
        bytes calldata requestData,
        Timestamp expiryAt,
        string calldata callbackMethodName
    ) external returns (RequestId requestId);

    /// @dev respond to oracle request by oracle compnent.
    /// the response data is amende in the request info stored with the instance.
    /// the request state changes to FULFILLED (when calling the callback method of the requester is successful)
    /// or to FAILED when calling the requester is not succesful.
    /// permissioned: only the oracle component linked to the request id may call this method
    function respond(
        RequestId requestId,
        bytes calldata responseData
    ) external;

    /// @dev replays a failed response delivery to the requester.
    /// only requests in state FAILED may be replayed.
    /// the request state changes to FULFILLED when calling the callback method of the requester is successful.
    /// permissioned: only the requester may replay a request
    function replay(RequestId requestId) external;

    /// @dev notify the oracle component that the specified request has become invalid.
    /// only requests in state ACTIVE may be cancelled.
    /// permissioned: only the requester may cancel a request
    function cancel(RequestId requestId) external;

}