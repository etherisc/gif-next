// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistryLinked} from "../../registry/IRegistry.sol";
import {IComponent, IComponentContract} from "../module/component/IComponent.sol";
import {NftId} from "../../types/NftId.sol";

interface IComponentOwnerService is IRegistryLinked, IComponent {
    function register(IComponentContract component) external returns(NftId componentNftId);

    function lock(IComponentContract component) external;

    function unlock(IComponentContract component) external;
}
