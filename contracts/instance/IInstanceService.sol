// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";
import {RoleId} from "../types/RoleId.sol";
import {IService} from "../shared/IService.sol";

import {AccessManagerUpgradeableInitializeable} from "./AccessManagerUpgradeableInitializeable.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {Instance} from "./Instance.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";

interface IInstanceService is IService {

    error ErrorInstanceServiceMasterInstanceAlreadySet();
    error ErrorInstanceServiceMasterOzAccessManagerAlreadySet();
    error ErrorInstanceServiceMasterInstanceAccessManagerAlreadySet();
    error ErrorInstanceServiceMasterBundleManagerAlreadySet();
    error ErrorInstanceServiceInstanceAddressZero();

    error ErrorInstanceServiceMasterInstanceReaderNotSet();
    error ErrorInstanceServiceInstanceReaderAddressZero();
    error ErrorInstanceServiceInstanceReaderSameAsMasterInstanceReader();
    error ErrorInstanceServiceInstanceReaderInstanceMismatch();

    error ErrorInstanceServiceOzAccessManagerZero();
    error ErrorInstanceServiceInstanceAccessManagerZero();
    error ErrorInstanceServiceInstanceReaderZero();
    error ErrorInstanceServiceBundleManagerZero();

    error ErrorInstanceServiceInstanceAuthorityMismatch();
    error ErrorInstanceServiceBundleManagerAuthorityMismatch();
    error ErrorInstanceServiceInstanceReaderInstanceMismatch2();
    error ErrorInstanceServiceBundleMangerInstanceMismatch();

    error ErrorInstanceServiceRequestUnauhorized(address caller);
    error ErrorInstanceServiceNotInstanceOwner(address caller, NftId instanceNftId);
    error ErrorInstanceServiceNotInstance(NftId nftId);
    error ErrorInstanceServiceComponentNotRegistered(address componentAddress);
    error ErrorInstanceServiceInstanceComponentMismatch(NftId instanceNftId, NftId componentNftId);
    error ErrorInstanceServiceInvalidComponentType(address componentAddress, ObjectType expectedType, ObjectType componentType);
    
    event LogInstanceCloned(address clonedOzAccessManager, address clonedInstanceAccessManager, address clonedInstance, address clonedBundleManager, address clonedInstanceReader, NftId clonedInstanceNftId);

    function createInstanceClone()
        external 
        returns (
            AccessManagerUpgradeableInitializeable clonedOzAccessManager,
            InstanceAccessManager clonedInstanceAccessManager, 
            Instance clonedInstance,
            NftId instanceNftId,
            InstanceReader clonedInstanceReader,
            BundleManager clonedBundleManager
        );

    function createGifTarget(
        NftId instanceNftId,
        address targetAddress,
        string memory targetName,
        bytes4[][] memory selectors,
        RoleId[] memory roles
    ) external;

    function setComponentLocked(bool locked) external;
}

