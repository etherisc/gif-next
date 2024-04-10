// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";
import {RoleId} from "../types/RoleId.sol";
import {IService} from "../shared/IService.sol";

import {AccessManagerUpgradeableInitializeable} from "../shared/AccessManagerUpgradeableInitializeable.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {Instance} from "./Instance.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";
import {InstanceStore} from "./InstanceStore.sol";

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

    error ErrorInstanceServiceInstanceAccessManagerZero();
    error ErrorInstanceServiceInstanceReaderZero();
    error ErrorInstanceServiceBundleManagerZero();
    error ErrorInstanceServiceInstanceStoreZero();

    error ErrorInstanceServiceInstanceAuthorityMismatch();
    error ErrorInstanceServiceBundleManagerAuthorityMismatch();
    error ErrorInstanceServiceInstanceReaderInstanceMismatch2();
    error ErrorInstanceServiceBundleMangerInstanceMismatch();
    error ErrorInstanceServiceInstanceStoreAuthorityMismatch();

    error ErrorInstanceServiceRequestUnauhorized(address caller);
    error ErrorInstanceServiceNotInstanceOwner(address caller, NftId instanceNftId);
    error ErrorInstanceServiceNotInstance(NftId nftId);
    error ErrorInstanceServiceComponentNotRegistered(address componentAddress);
    error ErrorInstanceServiceInstanceComponentMismatch(NftId instanceNftId, NftId componentNftId);
    error ErrorInstanceServiceInvalidComponentType(address componentAddress, ObjectType expectedType, ObjectType componentType);
    
    event LogInstanceCloned(
        address clonedOzAccessManager,
        address clonedInstanceAccessManager,
        address clonedInstance,
        address clonedInstanceStore,
        address clonedBundleManager, 
        address clonedInstanceReader, 
        NftId clonedInstanceNftId
    );

    function createInstanceClone()
        external 
        returns (
            Instance clonedInstance,
            NftId instanceNftId
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