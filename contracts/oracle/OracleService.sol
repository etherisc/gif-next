// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ContractLib} from "../shared/ContractLib.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IOracle} from "./IOracle.sol";
import {IOracleComponent} from "./IOracleComponent.sol";
import {IOracleService} from "./IOracleService.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT, ORACLE, PRODUCT} from "../type/ObjectType.sol";
import {RequestId} from "../type/RequestId.sol";
import {Service} from "../shared/Service.sol";
import {StateId, ACTIVE, KEEP_STATE, FULFILLED, FAILED, CANCELLED} from "../type/StateId.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";


contract OracleService is
    Service,
    IOracleService
{

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        onlyInitializing()
    {
        (
            address authority
        ) = abi.decode(data, (address));

        __Service_init(authority, owner);
        _registerInterface(type(IOracleService).interfaceId);
    }

    function request(
        NftId oracleNftId,
        bytes calldata requestData,
        Timestamp expiryAt,
        string calldata callbackMethodName
    )
        external 
        virtual 
        restricted()
        returns (RequestId requestId) 
    {
        // checks
        NftId requesterNftId; // component
        IOracleComponent oracle;

        {
            IInstance instance;
            (
                requesterNftId, 
                oracle, 
                instance
            ) = ContractLib.getAndVerifyComponentAndOracle(
                oracleNftId, getRelease());
            
            _checkRequestParams(expiryAt, callbackMethodName);

            // effects
            // create request info
            IOracle.RequestInfo memory request = IOracle.RequestInfo({
                requesterNftId: requesterNftId,
                callbackMethodName: callbackMethodName,
                oracleNftId: oracleNftId,
                requestData: requestData,
                responseData: "",
                respondedAt: TimestampLib.zero(),
                expiredAt: expiryAt,
                isCancelled: false
            });

            // store request with instance
            requestId = instance.getInstanceStore().createRequest(request);
        }

        emit LogOracleServiceRequestCreated(requestId, requesterNftId, oracleNftId, expiryAt);

        // interactions
        // callback to oracle component
        oracle.request(
            requestId, 
            requesterNftId, 
            requestData, 
            expiryAt);
    }


    /// @dev respond to oracle request by oracle compnent.
    /// permissioned: only the oracle component linked to the request id may call this method
    function respond(
        RequestId requestId,
        bytes calldata responseData
    )
        external
        virtual
        restricted()
        returns (bool success)
    {
        (
            NftId oracleNftId,
            IInstance instance
        ) = ContractLib.getAndVerifyComponent(
                msg.sender, ORACLE(), getRelease(), true);

        bool callerIsOracle = true;
        IOracle.RequestInfo memory request = _checkAndGetRequestInfo(instance, requestId, oracleNftId, callerIsOracle);
        request.responseData = responseData;
        request.respondedAt = TimestampLib.current();

        instance.getInstanceStore().updateRequest(
            requestId, request, KEEP_STATE());

        IRegistry.ObjectInfo memory requesterInfo = _getRegistry().getObjectInfo(
            request.requesterNftId);

        string memory functionSignature = string(
            abi.encodePacked(
                request.callbackMethodName,
                "(uint64,bytes)"
            ));

        (success, ) = requesterInfo.objectAddress.call(
            abi.encodeWithSignature(
                functionSignature, 
                requestId,
                responseData));

        // check that calling requestor was successful
        if (success) {
            instance.getInstanceStore().updateRequestState(requestId, FULFILLED());
        } else {
            instance.getInstanceStore().updateRequestState(requestId, FAILED());
            emit LogOracleServiceDeliveryFailed(requestId, requesterInfo.objectAddress, functionSignature);
        }

        emit LogOracleServiceResponseProcessed(requestId, oracleNftId);
    }


    function resend(RequestId requestId)
        external 
        virtual 
        restricted()
    {
        (
            // !!! TODO requesterNftId is in request.requesterNftId
            // here is responder nft id?
            NftId requesterNftId, // component
            IInstance instance
        ) = ContractLib.getAndVerifyComponent(
                msg.sender, COMPONENT(), getRelease(), true);

        bool callerIsOracle = false;
        IOracle.RequestInfo memory request = _checkAndGetRequestInfo(instance, requestId, requesterNftId, callerIsOracle);

        // attempt to deliver response to requester
        address requester = msg.sender;
        string memory functionSignature = string(
            abi.encodePacked(
                request.callbackMethodName,
                "(uint64,bytes)"
            ));

        (bool success, bytes memory returnData) = requester.call(
            abi.encodeWithSignature(
                functionSignature, 
                requestId,
                request.responseData));

        // check that calling requestor was successful
        if (success) {
            instance.getInstanceStore().updateRequestState(requestId, FULFILLED());
            emit LogOracleServiceResponseResent(requestId, requesterNftId);
        } else {
            // TODO why requester address instead of nftId?
            emit LogOracleServiceDeliveryFailed(requestId, requester, functionSignature);
        }
    }


    function cancel(RequestId requestId)
        external 
        virtual 
        restricted()
    {
        (
            NftId requesterNftId, // component
            IInstance instance
        ) = ContractLib.getAndVerifyComponent(
                msg.sender, COMPONENT(), getRelease(), true);

        bool callerIsOracle = false;
        // TODO property isCancelled and state update to CANCELLED are redundant, get rid of isCancelled
        IOracle.RequestInfo memory request = _checkAndGetRequestInfo(instance, requestId, requesterNftId, callerIsOracle);
        request.isCancelled = true;

        instance.getInstanceStore().updateRequest(requestId, request, CANCELLED());

        // call oracle component
        // TODO add check that oracle is active?
        address oracleAddress = _getRegistry().getObjectAddress(request.oracleNftId);
        IOracleComponent(oracleAddress).cancel(requestId);

        emit LogOracleServiceRequestCancelled(requestId, requesterNftId);
    }


    function _checkRequestParams(
        Timestamp expiryAt,
        string memory callbackMethodName
    )
        internal
        virtual
        view
    {
        // check expiriyAt >= now
        if (expiryAt < TimestampLib.current()) {
            revert ErrorOracleServiceExpiryInThePast(TimestampLib.current(), expiryAt);
        }

        // check callbackMethodName.length > 0
        if (bytes(callbackMethodName).length == 0) {
            revert ErrorOracleServiceCallbackMethodNameEmpty();
        }
    }


    function _checkAndGetRequestInfo(
        IInstance instance,
        RequestId requestId,
        NftId callerNftId,
        bool callerIsOracle
    )
        internal
        virtual
        view
        returns (IOracle.RequestInfo memory info)
    {
        InstanceReader reader = instance.getInstanceReader();
        StateId state = reader.getState(requestId.toKey32());

        // check caller against resonsible oracle or requester
        info = reader.getRequestInfo(requestId);
        if (callerIsOracle) {
            if (state != ACTIVE()) {
                revert ErrorOracleServiceRequestStateNotActive(requestId, state);
            }

            if (callerNftId != info.oracleNftId) {
                revert ErrorOracleServiceCallerNotResponsibleOracle(requestId, info.oracleNftId, callerNftId);
            }
        } else {
            if (state != ACTIVE() && state != FAILED()) {
                revert ErrorOracleServiceRequestStateNotActive(requestId, state);
            }
            if (callerNftId != info.requesterNftId) {
                revert ErrorOracleServiceCallerNotRequester(requestId, info.requesterNftId, callerNftId);
            }
        }

        // check expiry
        if (info.expiredAt < TimestampLib.current()) {
            revert ErrorOracleServiceRequestExpired(requestId, info.expiredAt);
        }
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return ORACLE();
    }
}