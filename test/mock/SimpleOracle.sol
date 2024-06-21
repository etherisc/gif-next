// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAuthorization} from "../../contracts/authorization/IAuthorization.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {BasicOracle} from "../../contracts/oracle/BasicOracle.sol";
import {BasicOracleAuthorization} from "../../contracts/oracle/BasicOracleAuthorization.sol";
import {RequestId} from "../../contracts/type/RequestId.sol";
import {Timestamp} from "../../contracts/type/Timestamp.sol";

contract SimpleOracle is
    BasicOracle
{

    string public constant ANSWER_SYNC = "oracle constant sync answer";

    struct SimpleRequest {
        bool synchronous;
        string text;
    }

    struct SimpleResponse {
        bool revertInCall;
        Timestamp revertUntil;
        string text;
    }

    event LogSimpleOracleRequestReceived(RequestId requestId, NftId requesterId, bool synchronous, string requestText);
    event LogSimpleOracleCancellingReceived(RequestId requestId);

    event LogSimpleOracleAsyncResponseSent(RequestId requestId, string responseText);
    event LogSimpleOracleSyncResponseSent(RequestId requestId, string responseText);

    constructor(
        address registry,
        NftId instanceNftId,
        address initialOwner,
        address token
    ) 
    {
        initialize(
            registry,
            instanceNftId,
            initialOwner,
            "SimpleOracle",
            token
        );
    }

    function initialize(
        address registry,
        NftId instanceNftId,
        address initialOwner,
        string memory name,
        address token
    )
        public
        virtual
        initializer()
    {
        IAuthorization authorization = new BasicOracleAuthorization("SimpleOracle");

        _initializeBasicOracle(
            registry,
            instanceNftId,
            authorization,
            initialOwner,
            name,
            token);
    }

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
        SimpleRequest memory request = abi.decode(requestData, (SimpleRequest));

        if (request.synchronous) {
            _respondSync(requestId);
        }

        emit LogSimpleOracleRequestReceived(requestId, requesterId, request.synchronous, request.text);
    }


    /// @dev use case specific handling of oracle requests
    /// for now only log is emitted to verify that cancelling has been received by oracle component 
    function _cancel(
        RequestId requestId
    )
        internal
        virtual override
    {
        emit LogSimpleOracleCancellingReceived(requestId);
    }


    function respondAsync(
        RequestId requestId,
        string memory responseText,
        bool revertInCall,
        Timestamp revertUntil
    )
        external
        // permissionless, no restricted() for now
    {
        bytes memory responseData = abi.encode(
            SimpleResponse(
                revertInCall, 
                revertUntil,
                responseText));

        _respond(requestId, responseData);

        emit LogSimpleOracleAsyncResponseSent(requestId, responseText);
    }


    function _respondSync(
        RequestId requestId
    )
        internal
    {
        bytes memory responseData = abi.encode(ANSWER_SYNC);
        _respond(requestId, responseData);

        emit LogSimpleOracleSyncResponseSent(requestId, ANSWER_SYNC);
    }

}
