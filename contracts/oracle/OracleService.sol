// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IOracle} from "./IOracle.sol";
import {IOracleComponent} from "./IOracleComponent.sol";
import {IOracleService} from "./IOracleService.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT, ORACLE, INSTANCE} from "../type/ObjectType.sol";
import {RequestId} from "../type/RequestId.sol";
import {StateId, ACTIVE, KEEP_STATE, FULFILLED, FAILED, CANCELLED} from "../type/StateId.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";


contract OracleService is
    ComponentVerifyingService,
    IOracleService
{

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        (
            address registryAddress,
            address authority
        ) = abi.decode(data, (address, address));

        _initializeService(registryAddress, authority, owner);
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
        // restricted() // add authz
        returns (
            RequestId requestId
        ) 
    {
        (
            NftId componentNftId,
            IRegistry.ObjectInfo memory componentInfo, 
            IInstance instance
        ) = _getAndVerifyActiveComponent(COMPONENT());

        // oracleNftId exists and is active oracle
        (
            IRegistry.ObjectInfo memory oracleInfo, 
        ) = _getAndVerifyComponentInfo(
            oracleNftId, 
            ORACLE(), 
            true); // only active

        // TODO move to stronger validation, requester and oracle need to belong to same product cluster
        // check that requester and oracle share same instance
        if (componentInfo.parentNftId != oracleInfo.parentNftId) {
            revert ErrorOracleServiceInstanceMismatch(componentInfo.parentNftId, oracleInfo.parentNftId);
        }

        // check expiriyAt >= now
        if (expiryAt < TimestampLib.blockTimestamp()) {
            revert ErrorOracleServiceExpiryInThePast(TimestampLib.blockTimestamp(), expiryAt);
        }

        // check callbackMethodName.length > 0
        if (bytes(callbackMethodName).length == 0) {
            revert ErrorOracleServiceCallbackMethodNameEmpty();
        }

        // create request info
        IOracle.RequestInfo memory request = IOracle.RequestInfo({
            requesterNftId: componentNftId,
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

        // call oracle component
        IOracleComponent(oracleInfo.objectAddress).request(
            requestId, 
            componentNftId, 
            requestData, 
            expiryAt);

        emit LogOracleServiceRequestCreated(requestId, componentNftId, oracleNftId, expiryAt);
    }


    /// @dev respond to oracle request by oracle compnent.
    /// permissioned: only the oracle component linked to the request id may call this method
    function respond(
        RequestId requestId,
        bytes calldata responseData
    )
        external
        virtual
        // restricted() // add authz
        returns (bool success)
    {
        (
            NftId oracleNftId,
            IRegistry.ObjectInfo memory componentInfo, 
            IInstance instance
        ) = _getAndVerifyActiveComponent(ORACLE());

        bool callerIsOracle = true;
        IOracle.RequestInfo memory request = _checkAndGetRequestInfo(instance, requestId, oracleNftId, callerIsOracle);
        request.responseData = responseData;
        request.respondedAt = TimestampLib.blockTimestamp();

        instance.getInstanceStore().updateRequest(
            requestId, request, KEEP_STATE());

        IRegistry.ObjectInfo memory requesterInfo = getRegistry().getObjectInfo(
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
        // restricted() // add authz
    {
        (
            NftId requesterNftId,
            IRegistry.ObjectInfo memory requesterInfo, 
            IInstance instance
        ) = _getAndVerifyActiveComponent(COMPONENT());

        bool callerIsOracle = false;
        IOracle.RequestInfo memory request = _checkAndGetRequestInfo(instance, requestId, requesterNftId, callerIsOracle);

        // attempt to deliver response to requester
        string memory functionSignature = string(
            abi.encodePacked(
                request.callbackMethodName,
                "(uint64,bytes)"
            ));

        (bool success, bytes memory returnData) = requesterInfo.objectAddress.call(
            abi.encodeWithSignature(
                functionSignature, 
                requestId,
                request.responseData));

        // check that calling requestor was successful
        if (success) {
            instance.getInstanceStore().updateRequestState(requestId, FULFILLED());
            emit LogOracleServiceResponseResent(requestId, requesterNftId);
        } else {
            emit LogOracleServiceDeliveryFailed(requestId, requesterInfo.objectAddress, functionSignature);
        }
    }


    function cancel(RequestId requestId)
        external 
        virtual 
        // restricted() // add authz
    {
        (
            NftId requesterNftId,
            IRegistry.ObjectInfo memory componentInfo, 
            IInstance instance
        ) = _getAndVerifyActiveComponent(COMPONENT());

        bool callerIsOracle = false;
        // TODO property isCancelled and state update to CANCELLED are redundant, get rid of isCancelled
        IOracle.RequestInfo memory request = _checkAndGetRequestInfo(instance, requestId, requesterNftId, callerIsOracle);
        request.isCancelled = true;

        instance.getInstanceStore().updateRequest(requestId, request, CANCELLED());

        // call oracle component
        // TODO add check that oracle is active?
        address oracleAddress = getRegistry().getObjectAddress(request.oracleNftId);
        IOracleComponent(oracleAddress).cancel(requestId);

        emit LogOracleServiceRequestCancelled(requestId, requesterNftId);
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
        if (info.expiredAt < TimestampLib.blockTimestamp()) {
            revert ErrorOracleServiceRequestExpired(requestId, info.expiredAt);
        }
    }


    function _getInstanceForComponent(NftId componentNftId)
        internal
        view
        returns(IInstance instance)
    {
        NftId instanceNftId = getRegistry().getObjectInfo(componentNftId).parentNftId;
        address instanceAddress = getRegistry().getObjectAddress(instanceNftId);
        return IInstance(instanceAddress);
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return ORACLE();
    }
}