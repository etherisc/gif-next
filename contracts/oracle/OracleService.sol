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
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
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
            address authority,
            address registry
        ) = abi.decode(data, (address, address));

        __Service_init(authority, registry, owner);
        _registerInterface(type(IOracleService).interfaceId);
    }

    // Auth:
    // - oracleNftId is ORACLE
    // - msg.sender is COMPONENT and have same version as service
    // - msg.sender and oracleNftId share the same product cluster
    //    - msg.sender is parent of oracleNftId OR
    //    - msg.sender have same parent as oracleNftId
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
        (
            ,
            NftId requesterNftId,
            IInstance instance
        ) = _getAndVerifyComponentAndObjectHaveSameProduct(oracleNftId, ORACLE());

        _checkRequestParams(expiryAt, callbackMethodName);

        // effects
        {
            // create request info
            IOracle.RequestInfo memory request = IOracle.RequestInfo({
                requesterNftId: requesterNftId,
                callbackMethodName: callbackMethodName,
                oracleNftId: oracleNftId,
                requestData: requestData,
                responseData: "",
                respondedAt: TimestampLib.zero(),
                expiredAt: expiryAt
            });

            // store request with instance
            requestId = IInstance(instance).getInstanceStore().createRequest(request);
        }

        emit LogOracleServiceRequestCreated(requestId, requesterNftId, oracleNftId, expiryAt);

        // interactions
        // callback to oracle component
        IOracleComponent oracle = IOracleComponent(getRegistry().getObjectAddress(oracleNftId));
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
        nonReentrant() // TODO add RESPONDING state?
        returns (bool success)
    {
        (NftId oracleNftId,, IInstance instance) = _getAndVerifyCallingComponent(ORACLE());

        // oracle nft id - referral id corespondence is stored in instance store instead of registry
        bool callerIsOracle = true;
        IOracle.RequestInfo memory request = _checkAndGetRequestInfo(instance, requestId, oracleNftId, callerIsOracle);
        request.responseData = responseData;
        request.respondedAt = TimestampLib.blockTimestamp();

        instance.getInstanceStore().updateRequest(
            requestId, request, KEEP_STATE());

        address requesterAddress = getRegistry().getObjectAddress(
            request.requesterNftId);

        string memory functionSignature = string(
            abi.encodePacked(
                request.callbackMethodName,
                "(uint64,bytes)"
            ));

        (success, ) = requesterAddress.call(
            abi.encodeWithSignature(
                functionSignature, 
                requestId,
                responseData));

        // check that calling requestor was successful
        if (success) {
            instance.getInstanceStore().updateRequestState(requestId, FULFILLED());
        } else {
            instance.getInstanceStore().updateRequestState(requestId, FAILED());
            emit LogOracleServiceDeliveryFailed(requestId, requesterAddress, functionSignature);
        }

        emit LogOracleServiceResponseProcessed(requestId, oracleNftId);
    }

    function resend(RequestId requestId)
        external 
        virtual
        restricted()
        nonReentrant() 
    {
        (
            NftId requesterNftId,
            IRegistry.ObjectInfo memory requesterInfo, 
            IInstance instance
        ) = _getAndVerifyCallingComponent(COMPONENT());

        // oracle nftId - referral id corespondence is stored in instance store instead of registry
        bool callerIsOracle = false;
        IOracle.RequestInfo memory request = _checkAndGetRequestInfo(instance, requestId, requesterNftId, callerIsOracle);

        // attempt to deliver response to requester
        string memory functionSignature = string(
            abi.encodePacked(
                request.callbackMethodName,
                "(uint64,bytes)"
            ));

        (bool success,) = requesterInfo.objectAddress.call(
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
        restricted()
    {
        (
            NftId requesterNftId,,
            IInstance instance
        ) = _getAndVerifyCallingComponent(COMPONENT());

        // oracle nftId - referral id corespondence is stored in instance store instead of registry
        bool callerIsOracle = false;
        IOracle.RequestInfo memory request = _checkAndGetRequestInfo(instance, requestId, requesterNftId, callerIsOracle);

        instance.getInstanceStore().updateRequest(requestId, request, CANCELLED());

        // call oracle component
        // TODO add check that oracle is active?
        address oracleAddress = getRegistry().getObjectAddress(request.oracleNftId);
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
        returns (
            NftId requesterNftId,
            IOracleComponent oracle
        )
    {
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
        info = reader.getRequestInfo(requestId);

        // check caller against resonsible oracle or requester
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