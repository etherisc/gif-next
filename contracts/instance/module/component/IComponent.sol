// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


import {IRegistry} from "../../../registry/IRegistry.sol";
import {IInstance} from "../../IInstance.sol";
import {StateId} from "../../../types/StateId.sol";
import {NftId} from "../../../types/NftId.sol";
import {ObjectType} from "../../../types/ObjectType.sol";
import {Fee} from "../../../types/Fee.sol";
import {UFixed} from "../../../types/UFixed.sol";

import {IComponentBase} from "../../../components/IComponentBase.sol";
import {IModuleBase} from "../IModuleBase.sol";

interface IComponent {
    // component dynamic info (static info kept in registry)
    struct ComponentInfo {
        NftId nftId;
        StateId state;
        IERC20Metadata token;
    }
}

// TODO cleanup
// interface IInstanceLinked {
//     function getInstance() external view returns (IInstance instance);
// }

interface IComponentModule is IModuleBase, IComponent {
    function getRegistry() external view returns (IRegistry registry);

    function registerComponent(
        IComponentBase component,
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

    // repeat service linked signaturea to avoid linearization issues
    function senderIsComponentOwnerService() external  returns(bool isService);

    function PRODUCT_OWNER_ROLE() external view returns (bytes32 role);

    function ORACLE_OWNER_ROLE() external view returns (bytes32 role);

    function POOL_OWNER_ROLE() external view returns (bytes32 role);

    function getRoleForType(ObjectType cType) external view returns (bytes32 role);

    function hasRole(bytes32 role, address member) external view returns (bool);
}
