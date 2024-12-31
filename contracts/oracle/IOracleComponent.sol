// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Fee} from "../type/Fee.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {ReferralId, ReferralStatus} from "../type/Referral.sol";
import {NftId} from "../type/NftId.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {RequestId} from "../type/RequestId.sol";
import {UFixed} from "../type/UFixed.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IOracleComponent is IInstanceLinkedComponent {
    error ErrorOracleNotImplemented(string methodName);
    
    event LogOracleRequestReceived(RequestId indexed requestId, NftId indexed requesterId);
    event LogOracleRequestCancelled(RequestId indexed requestId);


    /// @dev callback method for requesting some data from the oracle
    function request(
        RequestId requestId,
        NftId requesterNftId,
        bytes calldata requestData,
        Timestamp expiryAt
    ) external;


    /// @dev callback method for cancelling the specified oracle request
    function cancel(
        RequestId requestId
    ) external;


    /// @dev returns true iff the component needs to be called when selling/renewing policis
    function isVerifying() external view returns (bool verifying);

    function activeRequests() external view returns(uint256 numberOfRequests);
    
    function getActiveRequest(uint256 idx) external view returns(RequestId requestId);

    function isActiveRequest(RequestId requestId) external view returns(bool isActive);
}
