// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {COMPONENT, ORACLE} from "../type/ObjectType.sol";
import {IOracleService} from "./IOracleService.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IOracleComponent} from "./IOracleComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {RequestId} from "../type/RequestId.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {ITransferInterceptor} from "../registry/ITransferInterceptor.sol";
import {UFixed} from "../type/UFixed.sol";


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


    function initializeOracle(
        address registry,
        NftId instanceNftId,
        address initialOwner,
        string memory name,
        address token,
        bytes memory registryData, // writeonly data that will saved in the object info record of the registry
        bytes memory componentData // component specifidc data 
    )
        public
        virtual
        onlyInitializing()
    {
        initializeInstanceLinkedComponent(registry, instanceNftId, name, token, ORACLE(), true, initialOwner, registryData, componentData);

        OracleStorage storage $ = _getOracleStorage();
        $._oracleService = IOracleService(_getServiceAddress(ORACLE())); 
        $._componentService = IComponentService(_getServiceAddress(COMPONENT())); 

        registerInterface(type(IOracleComponent).interfaceId);
    }


    function register()
        external
        virtual
        onlyOwner()
    {
        _getOracleStorage()._componentService.registerOracle();
    }


    function isVerifying()
        external 
        virtual 
        view 
        returns (bool verifying)
    {
        return false;
    }


    function request(
        RequestId requestId,
        NftId requesterId,
        bytes calldata requestData,
        Timestamp expiryAt
    )
        external
        virtual
        restricted() // only oracle service
    {
        _request(requestId, requesterId, requestData, expiryAt);
    }


    /// @dev internal function for handling requests.
    /// empty implementation.
    /// overwrite this function to implement use case specific handling
    /// for oracle calls.
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


    /// @dev internal function for handling oracle responses.
    /// use this function in use case specific external/public functions
    /// to handle use case specific response handling.
    function _respond(
        RequestId requestId,
        bytes calldata responseData
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
