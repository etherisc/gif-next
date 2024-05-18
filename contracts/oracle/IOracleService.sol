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


interface IOracleService is IService {

    /// @dev send an oracle request to the specified oracle component.
    /// permissioned: only registered components may send requests to oracles.
    function request(
        NftId oracleNftId,
        bytes calldata requestData,
        string calldata callbackMethodName // TODO consider to replace with method signature
    ) external returns (uint256 requestId);

    /// @dev respond to oracle request by oracle compnent.
    /// persmissioned: only the oracle component linked to the request id may call this method
    function respond(
        uint256 requestId,
        bytes calldata responseData
    ) external;

    /// @dev notify the oracle component that the specified request has become invalid
    /// permissioned: only the originator of the request may cancel a request
    function cancel(uint256 requestId) external;

}