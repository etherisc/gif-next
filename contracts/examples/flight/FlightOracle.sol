// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAuthorization} from "../../authorization/IAuthorization.sol";

import {FULFILLED} from "../../type/StateId.sol";
import {NftId} from "../../type/NftId.sol";
import {BasicOracle} from "../../oracle/BasicOracle.sol";
import {RequestId} from "../../type/RequestId.sol";
import {RequestIdSet} from "../../type/RequestIdSet.sol";
import {RiskId} from "../../type/RiskId.sol";
import {Str} from "../../type/String.sol";
import {Timestamp} from "../../type/Timestamp.sol";

contract FlightOracle is
    BasicOracle
{

    struct FlightStatusRequest {
        RiskId riskId;
        Str flightData; // "LX 180 ZRH BKK 20241104"
        Timestamp departureTime; // is this needed or is flight number and date unique aready?
    }

    struct FlightStatusResponse {
        RiskId riskId;
        bytes1 status;
        int256 delayMinutes;
    }

    event LogFlightOracleRequestReceived(RequestId requestId, NftId requesterId);
    event LogFlightOracleResponseSent(RequestId requestId, bytes1 status, int256 delay);
    event LogFlightOracleRequestCancelled(RequestId requestId);

    // TODO decide if this variable should be moved to instance store
    // if so it need to manage active requests by requestor nft id
    RequestIdSet.Set internal _activeRequests;


    constructor(
        address registry,
        NftId productNftId,
        IAuthorization authorization,
        address initialOwner
    ) 
    {
        initialize(
            registry,
            productNftId,
            authorization,
            initialOwner,
            "FlightOracle"
        );
    }


    function initialize(
        address registry,
        NftId productNftId,
        IAuthorization authorization,
        address initialOwner,
        string memory name
    )
        public
        virtual
        initializer()
    {
        _initializeBasicOracle(
            registry,
            productNftId,
            authorization,
            initialOwner,
            name);
    }


    function respondWithFlightStatus(
        RequestId requestId,
        bytes1 status,
        int256 delayMinutes
    )
        external
        restricted()
    {
        // obtain riskId for request
        bytes memory requestData = _getInstanceReader().getRequestInfo(requestId).requestData;
        (RiskId riskId,,) = abi.decode(requestData, (RiskId, Str, Timestamp));
        // assemble response data
        bytes memory responseData = abi.encode(
            FlightStatusResponse ({
                riskId: riskId,
                status: status,
                delayMinutes: delayMinutes}));

        // logging
        emit LogFlightOracleResponseSent(requestId, status, delayMinutes);

        // effects + interaction (via framework to receiving component)
        _respond(requestId, responseData);

        // TODO decide if the code below should be moved to GIF
        // check callback result
        bool requestFulfilled = _getInstanceReader().getRequestState(
            requestId) == FULFILLED();

        // remove from active requests when successful
        if (requestFulfilled) {
            RequestIdSet.remove(_activeRequests, requestId);
        }
    }

    //--- view functions ----------------------------------------------------//

    // TODO decide if the code below should be moved to GIF
    function activeRequests()
        external
        view
        returns(uint256 numberOfRequests)
    {
        return RequestIdSet.size(_activeRequests);
    }


    // TODO decide if the code below should be moved to GIF
    function getActiveRequest(uint256 idx)
        external
        view
        returns(RequestId requestId)
    {
        return RequestIdSet.getElementAt(_activeRequests, idx);
    }

    //--- internal functions ------------------------------------------------//

    /// @dev use case specific handling of oracle requests
    /// for now only log is emitted to verify that request has been received by oracle component 
    function _request(
        RequestId requestId,
        NftId requesterId,
        bytes calldata requestData,
        Timestamp expiryAt
    )
        internal
        virtual override
    {
        FlightStatusRequest memory request = abi.decode(requestData, (FlightStatusRequest));

        // TODO decide if the line below should be moved to GIF
        RequestIdSet.add(_activeRequests, requestId);
        emit LogFlightOracleRequestReceived(requestId, requesterId);
    }


    /// @dev use case specific handling of oracle requests
    /// for now only log is emitted to verify that cancelling has been received by oracle component 
    function _cancel(
        RequestId requestId
    )
        internal
        virtual override
    {
        // TODO decide if the line below should be moved to GIF
        RequestIdSet.remove(_activeRequests, requestId);
        emit LogFlightOracleRequestCancelled(requestId);
    }
}
