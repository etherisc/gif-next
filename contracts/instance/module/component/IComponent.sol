// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


import {IRegistry} from "../../../registry/IRegistry.sol";
import {IInstance} from "../../IInstance.sol";
import {StateId} from "../../../types/StateId.sol";
import {NftId} from "../../../types/NftId.sol";
import {ObjectType} from "../../../types/ObjectType.sol";
import {RoleId} from "../../../types/RoleId.sol";
import {Fee} from "../../../types/Fee.sol";
import {UFixed} from "../../../types/UFixed.sol";

import {IComponentOwnerService} from "../../service/IComponentOwnerService.sol";
// import {IComponentBase} from "../../../components/IComponentBase.sol";

interface IComponent {
    // component dynamic info (static info kept in registry)
    struct ComponentInfo {
        NftId nftId;
        StateId state;
        IERC20Metadata token;
    }
}

interface IComponentModule is IComponent {
    function getRegistry() external view returns (IRegistry registry);

    function registerComponent(
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

    function getComponentCount() external view returns (uint256 numberOfCompnents);

    function getComponentId(uint256 idx) external view returns (NftId nftId);

    // repeat service linked signaturea to avoid linearization issues
    function getComponentOwnerService() external view returns(IComponentOwnerService);

    function hasRole(RoleId role, address member) external view returns (bool);
}
