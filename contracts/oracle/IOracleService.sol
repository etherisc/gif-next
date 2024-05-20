// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IService} from "../shared/IService.sol";
import {NftId} from "../type/NftId.sol";
import {RequestId} from "../type/RequestId.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";


interface IOracleService is IService {

    event LogOracleServiceRequestCreated(RequestId requestId, NftId requesterNftId, NftId oracleNftId, Timestamp expiryAt);
    event LogOracleRequestFulfilled(RequestId requestId, NftId oracleNftId);
    event LogOracleRequestCancelled(RequestId requestId, NftId requesterNftId);

    // create request
    error ErrorOracleServiceInstanceMismatch(NftId expectedInstanceNftId, NftId oracleInstanceNftId);
    error ErrorOracleServiceExpiryInThePast(Timestamp blockTimestamp, Timestamp expiryAt);
    error ErrorOracleServiceCallbackMethodNameEmpty();

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
        string calldata callbackMethodName // TODO consider to replace with method signature
    ) external returns (RequestId requestId);

    /// @dev respond to oracle request by oracle compnent.
    /// persmissioned: only the oracle component linked to the request id may call this method
    function respond(
        RequestId requestId,
        bytes calldata responseData
    ) external;

    /// @dev notify the oracle component that the specified request has become invalid
    /// permissioned: only the originator of the request may cancel a request
    function cancel(RequestId requestId) external;

}