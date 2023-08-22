// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;


import {IOwnable, IRegistryLinked, IRegisterable} from "../../registry/IRegistry.sol";
import {IInstance} from "../IInstance.sol";

interface IComponent {

    // TODO decide if enum or uints with constants (as in IRegistry.PRODUCT())
    enum CState {
        Undefined,
        Active,
        Locked
    }

    struct ComponentInfo {
        uint256 id;
        address cAddress;
        uint256 cType;
        CState state;
    }
}


interface IInstanceLinked {
    function setInstance(address instance) external;
    function getInstance() external view returns(IInstance instance);
}


interface IComponentContract is
    IRegisterable,
    IInstanceLinked,
    IComponent
{ }


interface IComponentOwnerService {

    function register(IComponentContract component) external returns(uint256 id);
    function lock(IComponentContract component) external;
    function unlock(IComponentContract component) external;
}


interface IComponentModule is
    IOwnable,
    IRegistryLinked,
    IComponent
{

    function setComponentInfo(ComponentInfo memory info)
        external
        returns(uint256 componentId);

    function getComponentInfo(uint256 id)
        external
        view
        returns(ComponentInfo memory info);

    function getComponentOwner(uint256 id)
        external
        view
        returns(address owner);

    function getComponentId(address componentAddress)
        external
        view
        returns(uint256 id);

    function getComponentId(uint256 idx)
        external
        view
        returns(uint256 id);

    function components()
        external
        view
        returns(uint256 numberOfCompnents);

    function getComponentOwnerService()
        external
        view
        returns(IComponentOwnerService);
}