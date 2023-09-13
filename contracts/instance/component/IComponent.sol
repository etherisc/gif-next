// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IOwnable, IRegistryLinked, IRegisterable} from "../../registry/IRegistry.sol";
import {IInstance} from "../IInstance.sol";
import {StateId} from "../../types/StateId.sol";
import {NftId} from "../../types/NftId.sol";
import {ObjectType} from "../../types/ObjectType.sol";
import {Fee} from "../../types/Fee.sol";
import {UFixed} from "../../types/UFixed.sol";

interface IComponent {
    // component dynamic info (static info kept in registry)
    struct ComponentInfo {
        NftId nftId;
        StateId state;
        IERC20Metadata token;
    }
}

interface IInstanceLinked {
    // function setInstance(address instance) external;
    function getInstance() external view returns (IInstance instance);
}

interface IComponentContract is IRegisterable, IInstanceLinked, IComponent {
    function lock() external;

    function unlock() external;

    function getToken() external view returns (IERC20Metadata token);

    function getWallet() external view returns (address walletAddress);
}

interface IComponentOwnerService is IRegistryLinked {
    function register(IComponentContract component) external returns(NftId componentNftId);

    function lock(IComponentContract component) external;

    function unlock(IComponentContract component) external;

    function setProductFees(
        IComponentContract product,
        Fee memory policyFee,
        Fee memory processingFee
    ) external;
}

interface IComponentModule is IOwnable, IRegistryLinked, IComponent {
    function registerComponent(
        IComponentContract component,
        NftId nftId,
        ObjectType objectType,
        IERC20Metadata token
    ) external;

    function setComponentInfo(
        ComponentInfo memory info
    ) external returns (NftId componentNftId);

    function getComponentInfo(
        NftId nftId
    ) external view returns (ComponentInfo memory info);

    function getComponentId(
        address componentAddress
    ) external view returns (NftId nftId);

    function getComponentId(uint256 idx) external view returns (NftId nftId);

    function components() external view returns (uint256 numberOfCompnents);

    function getComponentOwnerService()
        external
        view
        returns (IComponentOwnerService);

    function getRoleForType(ObjectType cType) external view returns (bytes32 role);
}
