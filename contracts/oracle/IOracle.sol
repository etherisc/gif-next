// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {NftId} from "../type/NftId.sol";
import {Fee} from "../type/Fee.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IService} from "../shared/IService.sol";
import {UFixed} from "../type/UFixed.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {ReferralId} from "../type/Referral.sol";
import {Timestamp} from "../type/Timestamp.sol";


interface IOracle {

    struct RequestInfo {
        NftId oracleNftId; // responsible oracle component
        bytes requestData; 
        NftId requesterNftId; // originator of the request
        string callbackMethodName; // callback function of the requestor to call to provide response data
        bytes responseData; 
        Timestamp respondedAt; // response timestamp
    }
}