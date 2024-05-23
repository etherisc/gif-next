// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../type/NftId.sol";
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
}