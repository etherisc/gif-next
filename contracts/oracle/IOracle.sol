// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../type/NftId.sol";
import {RequestId} from "../type/RequestId.sol";
import {Timestamp} from "../type/Timestamp.sol";


interface IOracle {

    struct RequestInfo {
        NftId requesterNftId; // originator of the request
        string callbackMethodName; // callback function of the requestor to call to provide response data
        NftId oracleNftId; // responsible oracle component
        bytes requestData; 
        bytes responseData; 
        Timestamp respondedAt; // response timestamp
        Timestamp expiredAt; // expiry timestamp
        bool isCancelled;
    }


    /// @dev Callback function for oracle service to notify this oracle component to retreive some oracle data.
    function request(
        RequestId requestId,
        NftId requesterId,
        bytes calldata requestData,
        Timestamp expiryAt
    ) external;


    /// @dev Callback function for oracle service to notify this oracle component that the specified oracle request has ben cancelled by the requestor.
    function cancel(
        RequestId requestId
    ) external;
}