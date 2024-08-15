// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {COMPONENT, PRODUCT, ORACLE} from "../type/ObjectType.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IOracleComponent} from "./IOracleComponent.sol";
import {IOracleService} from "./IOracleService.sol";
import {NftId} from "../type/NftId.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {RequestId} from "../type/RequestId.sol";
import {Timestamp} from "../type/Timestamp.sol";


abstract contract Oracle is
    InstanceLinkedComponent,
    IOracleComponent
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Oracle")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant ORACLE_STORAGE_LOCATION_V1 = 0xaab7c0ea03d290e56d6c060e0733d3ebcbe647f7694616a2ec52738a64b2f900;

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


    function _initializeOracle(
        address registry,
        NftId productNftId,
        IAuthorization authorization,
        address initialOwner,
        string memory name,
        address token,
        bytes memory componentData // component specifidc data 
    )
        internal
        virtual
        onlyInitializing()
    {
        _initializeInstanceLinkedComponent(
            registry, 
            productNftId, 
            name, 
            token, 
            ORACLE(), 
            authorization,
            true, 
            initialOwner, 
            componentData);

        OracleStorage storage $ = _getOracleStorage();
        $._componentService = IComponentService(_getServiceAddress(COMPONENT())); 
        $._oracleService = IOracleService(_getServiceAddress(ORACLE())); 

        _registerInterface(type(IOracleComponent).interfaceId);
    }


    /// @dev Internal function for handling requests.
    /// Empty implementation.
    /// Overwrite this function to implement use case specific handling for oracle calls.
    function _request(
        RequestId requestId,
        NftId requesterId,
        bytes calldata requestData,
        Timestamp expiryAt
    )
        internal
        virtual
    {
    }


    /// @dev Internal function for cancelling requests.
    /// Empty implementation.
    /// Overwrite this function to implement use case specific cancelling.
    function _cancel(
        RequestId requestId
    )
        internal
        virtual
    {
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
        _getOracleStorage()._oracleService.respond(
            requestId, responseData);
    }

    function _getOracleStorage() private pure returns (OracleStorage storage $) {
        assembly {
            $.slot := ORACLE_STORAGE_LOCATION_V1
        }
    }
}
