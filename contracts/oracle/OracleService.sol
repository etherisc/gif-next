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
import {StateId, ACTIVE, FULFILLED, CANCELLED} from "../type/StateId.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";


contract OracleService is
    ComponentVerifyingService,
    IOracleService
{

    IInstanceService private _instanceService;


    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        address initialOwner;
        address registryAddress;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));
        initializeService(registryAddress, address(0), owner);

        _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));

        registerInterface(type(IOracleService).interfaceId);
    }

    function getDomain() public pure override returns(ObjectType) {
        return ORACLE();
    }

    function request(
        NftId oracleNftId,
        bytes calldata requestData,
        Timestamp expiryAt,
        string calldata callbackMethodName // TODO consider to replace with method signature
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

        // TODO add checks
        // oracleNftId exists and is active oracle
        // expiriyAt > 0
        // callbackMethodName.length > 0

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

        requestId = instance.getInstanceStore().createRequest(request);

        // TODO add call to oracle component

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

        instance.getInstanceStore().updateRequest(requestId, request, FULFILLED());

        // TODO add callback to requesting compnent

        emit LogOracleRequestFulfilled(requestId, oracleNftId);
    }

    /// @dev notify the oracle component that the specified request has become invalid
    /// permissioned: only the originator of the request may cancel a request
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
        IOracle.RequestInfo memory request = _checkAndGetRequestInfo(instance, requestId, requesterNftId, callerIsOracle);
        request.isCancelled = true;

        instance.getInstanceStore().updateRequest(requestId, request, CANCELLED());

        emit LogOracleRequestCancelled(requestId, requesterNftId);
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

        // check request state
        if (state != ACTIVE()) {
            revert ErrorOracleServiceRequestStateNotActive(requestId, state);
        }

        // check caller against resonsible oracle or requester
        info = reader.getRequestInfo(requestId);
        if (callerIsOracle) {
            if (callerNftId != info.oracleNftId) {
                revert ErrorOracleServiceCallerNotResponsibleOracle(requestId, info.oracleNftId, callerNftId);
            }
        } else {
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
        address instanceAddress = getRegistry().getObjectInfo(instanceNftId).objectAddress;
        return IInstance(instanceAddress);
    }
}