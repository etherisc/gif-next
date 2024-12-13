// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAuthorization} from "../../authorization/IAuthorization.sol";

import {ACTIVE, FULFILLED, FAILED} from "../../type/StateId.sol";
import {NftId} from "../../type/NftId.sol";
import {BasicOracle} from "../../oracle/BasicOracle.sol";
import {RequestId} from "../../type/RequestId.sol";
import {RiskId} from "../../type/RiskId.sol";
import {StateId} from "../../type/StateId.sol";
import {Str} from "../../type/String.sol";
import {Timestamp, TimestampLib} from "../../type/Timestamp.sol";

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



    constructor(
        address registry,
        NftId productNftId,
        string memory componentName,
        IAuthorization authorization
    ) 
    {
        address initialOwner = msg.sender;
        initialize(
            registry,
            productNftId,
            authorization,
            initialOwner,
            componentName
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
        _updateRequestState(requestId);
    }


    function updateRequestState(
        RequestId requestId
    )
        external
        restricted()
    {
        _updateRequestState(requestId);
    }

    //--- view functions ----------------------------------------------------//

    function getRequestState(RequestId requestId)
        external
        view
        returns (
            RiskId riskId,
            string memory flightData,
            StateId requestState,
            bool readyForResponse,
            bool waitingForResend
        )
    {
        bytes memory requestData = _getInstanceReader().getRequestInfo(requestId).requestData;
        Str fltData;
        Timestamp departureTime;
        (riskId, fltData, departureTime) = abi.decode(requestData, (RiskId, Str, Timestamp));

        flightData = fltData.toString();
        requestState = _getInstanceReader().getRequestState(requestId);
        readyForResponse = requestState == ACTIVE() && TimestampLib.current() >= departureTime;
        waitingForResend = requestState == FAILED();
    }


    function decodeFlightStatusRequestData(bytes memory data) external pure returns (FlightStatusRequest memory) {
        return abi.decode(data, (FlightStatusRequest));
    }

}
