// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IOracleComponent} from "./IOracleComponent.sol";
import {IOracleService} from "./IOracleService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, ORACLE, INSTANCE} from "../type/ObjectType.sol";
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
        string calldata callbackMethodName // TODO consider to replace with method signature
    ) external virtual restricted() returns (uint256 requestId) {}

    /// @dev respond to oracle request by oracle compnent.
    /// persmissioned: only the oracle component linked to the request id may call this method
    function respond(
        uint256 requestId,
        bytes calldata responseData
    ) external virtual restricted() {}

    /// @dev notify the oracle component that the specified request has become invalid
    /// permissioned: only the originator of the request may cancel a request
    function cancel(uint256 requestId) external virtual restricted() {}


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