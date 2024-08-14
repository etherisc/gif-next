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
        onlyNftOfType(oracleNftId, ORACLE())
        returns (RequestId requestId) 
    {
        // IRegistry registry = getRegistry();

        // get and check active caller
        (
            IRegistry.ObjectInfo memory info, 
            address instance
        ) = ContractLib.getAndVerifyAnyComponent(
            getRegistry(), msg.sender, true);

        (
            NftId requesterNftId,
            IOracleComponent oracle
        ) = _checkRequestParams(
            getRegistry(), oracleNftId, info, expiryAt, callbackMethodName);

        {
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
            requestId = IInstance(instance).getInstanceStore().createRequest(request);
        }

        // callback to oracle component
        oracle.request(
            requestId, 
            requesterNftId, 
            requestData, 
            expiryAt);

        emit LogOracleServiceRequestCreated(requestId, requesterNftId, oracleNftId, expiryAt);
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
            IRegistry.ObjectInfo memory info, 
            address instanceAddress
        ) = ContractLib.getAndVerifyComponent(
            getRegistry(), msg.sender, ORACLE(), true);

        NftId oracleNftId = info.nftId;
        IInstance instance = IInstance(instanceAddress);
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
            IRegistry.ObjectInfo memory info, 
            address instanceAddress
        ) = ContractLib.getAndVerifyAnyComponent(
            getRegistry(), msg.sender, true);

        NftId requesterNftId = info.nftId;
        IInstance instance = IInstance(instanceAddress);
        bool callerIsOracle = false;
        IOracle.RequestInfo memory request = _checkAndGetRequestInfo(instance, requestId, requesterNftId, callerIsOracle);

        // attempt to deliver response to requester
        string memory functionSignature = string(
            abi.encodePacked(
                request.callbackMethodName,
                "(uint64,bytes)"
            ));

        (bool success, bytes memory returnData) = info.objectAddress.call(
            abi.encodeWithSignature(
                functionSignature, 
                requestId,
                request.responseData));

        // check that calling requestor was successful
        if (success) {
            instance.getInstanceStore().updateRequestState(requestId, FULFILLED());
            emit LogOracleServiceResponseResent(requestId, requesterNftId);
        } else {
            emit LogOracleServiceDeliveryFailed(requestId, info.objectAddress, functionSignature);
        }
    }


    function cancel(RequestId requestId)
        external 
        virtual 
        // restricted() // add authz
    {
        (
            IRegistry.ObjectInfo memory info, 
            address instanceAddress
        ) = ContractLib.getAndVerifyAnyComponent(
            getRegistry(), msg.sender, true);

        NftId requesterNftId = info.nftId;
        IInstance instance = IInstance(instanceAddress);
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


    function _checkRequestParams(
        IRegistry registry,
        NftId oracleNftId,
        IRegistry.ObjectInfo memory info,
        Timestamp expiryAt,
        string memory callbackMethodName
    )
        internal
        virtual
        view
        returns (
            NftId requesterNftId,
            IOracleComponent oracle
        )
    {
        // get oracle info
        (IRegistry.ObjectInfo memory oracleInfo,) = ContractLib.getInfoAndInstance(
            registry, oracleNftId, true);

        // obtain return values
        requesterNftId = info.nftId;
        oracle = IOracleComponent(oracleInfo.objectAddress);

        // check that requester and oracle share same product cluster
        if (info.objectType == PRODUCT()) {
            if (oracleInfo.parentNftId != requesterNftId) {
                revert ErrorOracleServiceProductMismatch(info.objectType, requesterNftId, oracleInfo.parentNftId);
            }
        } else {
            if (oracleInfo.parentNftId != info.parentNftId) {
                revert ErrorOracleServiceProductMismatch(info.objectType, info.parentNftId, oracleInfo.parentNftId);
            }
        }

        // check expiriyAt >= now
        if (expiryAt < TimestampLib.blockTimestamp()) {
            revert ErrorOracleServiceExpiryInThePast(TimestampLib.blockTimestamp(), expiryAt);
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
        if (info.expiredAt < TimestampLib.blockTimestamp()) {
            revert ErrorOracleServiceRequestExpired(requestId, info.expiredAt);
        }
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return ORACLE();
    }
}