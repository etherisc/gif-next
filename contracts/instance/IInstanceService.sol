// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";
import {RoleId} from "../types/RoleId.sol";
import {IService} from "../shared/IService.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IBaseComponent} from "../components/IBaseComponent.sol";

import {AccessManagerSimple} from "./AccessManagerSimple.sol";
import {Instance} from "./Instance.sol";
import {InstanceReader} from "./InstanceReader.sol";

interface IInstanceService is IService {

    event LogInstanceCloned(address clonedAccessManagerAddress, address clonedInstanceAddress, address clonedInstanceReaderAddress, NftId clonedInstanceNftId);

    function createInstanceClone()
        external 
        returns (
            AccessManagerSimple clonedAccessManager, 
            Instance clonedInstance,
            NftId instanceNftId,
            InstanceReader clonedInstanceReader
        );
}

