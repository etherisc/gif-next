// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";
import {RoleId} from "../types/RoleId.sol";
import {IService} from "../shared/IService.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IBaseComponent} from "../components/IBaseComponent.sol";

import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {Instance} from "./Instance.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";

interface IInstanceService is IService {

    error ErrorInstanceServiceRequestUnauhorized(address caller);
    error ErrorInstanceServiceNotInstanceOwner(address caller, NftId instanceNftId);

    event LogInstanceCloned(address clonedAccessManagerAddress, address clonedInstanceAddress, address clonedInstanceReaderAddress, NftId clonedInstanceNftId);

    function createInstanceClone()
        external 
        returns (
            InstanceAccessManager clonedAccessManager, 
            Instance clonedInstance,
            NftId instanceNftId,
            InstanceReader clonedInstanceReader,
            BundleManager clonedBundleManager
        );

    function createRole(RoleId role, string memory name, NftId instanceNftId) external;

    function grantRole(RoleId role, address member, NftId instanceNftId) external;

    function hasRole(address account, RoleId role, address instanceAddress) external returns (bool);

}

