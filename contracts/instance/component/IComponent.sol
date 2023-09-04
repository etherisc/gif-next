// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistryLinked, IRegisterable} from "../../registry/IRegistry.sol";
import {IInstance} from "../IInstance.sol";
import {NftId} from "../../types/NftId.sol";

interface IComponent {
    // TODO decide if enum or uints with constants (as in IRegistry.PRODUCT())
    enum CState {
        Undefined,
        Active,
        Locked
    }

    // component dynamic info (static info kept in registry)
    struct ComponentInfo {
        NftId nftId;
        CState state;
    }
}

interface IInstanceLinked {
    // function setInstance(address instance) external;
    function getInstance() external view returns (IInstance instance);
}

interface IComponentContract is IRegisterable, IInstanceLinked, IComponent {}

interface IComponentOwnerService is IRegistryLinked {
    function register(
        IComponentContract component
    ) external returns (NftId nftId);

    function lock(IComponentContract component) external;

    function unlock(IComponentContract component) external;
}

interface IComponentModule is IOwnable, IRegistryLinked, IComponent {
    function registerComponent(
        IComponentContract component
    ) external returns (NftId nftId);

    function setComponentInfo(
        ComponentInfo memory info
    ) external returns (NftId componentNftId);

    function getComponentInfo(
        NftId nftId
    ) external view returns (ComponentInfo memory info);

    function getComponentOwner(
        NftId nftId
    ) external view returns (address owner);

    function getComponentId(
        address componentAddress
    ) external view returns (NftId nftId);

    function getComponentId(uint256 idx) external view returns (NftId nftId);

    function getPoolNftId(
        NftId productNftId
    ) external view returns (NftId poolNftId);

    function components() external view returns (uint256 numberOfCompnents);

    function getComponentOwnerService()
        external
        view
        returns (IComponentOwnerService);
}
