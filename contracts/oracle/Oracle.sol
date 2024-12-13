// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {COMPONENT, PRODUCT, ORACLE} from "../type/ObjectType.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IOracleComponent} from "./IOracleComponent.sol";
import {IOracleService} from "./IOracleService.sol";
import {LibRequestIdSet} from "../type/RequestIdSet.sol";
import {NftId} from "../type/NftId.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {RequestId} from "../type/RequestId.sol";
import {FULFILLED} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";


abstract contract Oracle is
    InstanceLinkedComponent,
    IOracleComponent
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Oracle")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant ORACLE_STORAGE_LOCATION_V1 = 0xaab7c0ea03d290e56d6c060e0733d3ebcbe647f7694616a2ec52738a64b2f900;

    // TODO decide if this variable should be moved to instance store
    // if so it need to manage active requests by requestor nft id
    LibRequestIdSet.Set internal _activeRequests;

    struct OracleStorage {
        IComponentService _componentService;
        IOracleService _oracleService;
    }


    function request(
        RequestId requestId,
        NftId requesterId,
        bytes calldata requestData,
        Timestamp expiryAt
    )
        external
        virtual
        restricted()
    {
        _request(requestId, requesterId, requestData, expiryAt);
    }


    function cancel(
        RequestId requestId
    )
        external
        virtual
        restricted()
    {
        _cancel(requestId);
    }


    /// @dev Not relevant for oracle components, always returns false.
    function isVerifying()
        external 
        virtual 
        view 
        returns (bool verifying)
    {
        return false;
    }

    /// @dev Not relevant for oracle components
    function withdrawFees(Amount amount)
        external
        virtual
        override(IInstanceLinkedComponent, InstanceLinkedComponent)
        onlyOwner()
        restricted()
        returns (Amount)
    {
        revert ErrorOracleNotImplemented("withdrawFees");
    }

    // TODO decide if the code below should be moved to GIF
    function activeRequests()
        external
        view
        returns(uint256 numberOfRequests)
    {
        return LibRequestIdSet.size(_activeRequests);
    }


    // TODO decide if the code below should be moved to GIF
    function getActiveRequest(uint256 idx)
        external
        view
        returns(RequestId requestId)
    {
        return LibRequestIdSet.getElementAt(_activeRequests, idx);
    }

    // TODO decide if the code below should be moved to GIF
    function isActiveRequest(RequestId requestId)
        external
        view
        returns(bool isActive)
    {
        return LibRequestIdSet.contains(_activeRequests, requestId);
    }

    function __Oracle_init(
        address registry,
        NftId productNftId,
        IAuthorization authorization,
        address initialOwner,
        string memory name
    )
        internal
        virtual
        onlyInitializing()
    {
        __InstanceLinkedComponent_init(
            registry, 
            productNftId, 
            name, 
            ORACLE(), 
            authorization,
            true, 
            initialOwner);

        OracleStorage storage $ = _getOracleStorage();
        $._componentService = IComponentService(_getServiceAddress(COMPONENT())); 
        $._oracleService = IOracleService(_getServiceAddress(ORACLE())); 

        _registerInterface(type(IOracleComponent).interfaceId);
    }

    /// @dev Internal function for handling oracle responses.
    /// Default implementation sends response back to oracle service.
    /// Use this function in use case specific external/public functions to handle use case specific response handling.
    function _respond(
        RequestId requestId,
        bytes memory responseData
    )
        internal
        virtual
    {
        _getOracleStorage()._oracleService.respond(requestId, responseData);
    }

        // TODO decide if the code below should be moved to GIF
    // check callback result
    function _updateRequestState(
        RequestId requestId
    )
        internal
    {
        bool requestFulfilled = _getInstanceReader().getRequestState(
            requestId) == FULFILLED();

        // remove from active requests when successful
        if (requestFulfilled && LibRequestIdSet.contains(_activeRequests, requestId)) {
            LibRequestIdSet.remove(_activeRequests, requestId);
        } 
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
        virtual 
    {
        // TODO decide if the line below should be moved to GIF
        LibRequestIdSet.add(_activeRequests, requestId);
        emit LogOracleRequestReceived(requestId, requesterId);
    }


    /// @dev use case specific handling of oracle requests
    /// for now only log is emitted to verify that cancelling has been received by oracle component 
    function _cancel(
        RequestId requestId
    )
        internal
        virtual 
    {
        // TODO decide if the line below should be moved to GIF
        LibRequestIdSet.remove(_activeRequests, requestId);
        emit LogOracleRequestCancelled(requestId);
    }


    function _getOracleStorage() private pure returns (OracleStorage storage $) {
        assembly {
            $.slot := ORACLE_STORAGE_LOCATION_V1
        }
    }
}
