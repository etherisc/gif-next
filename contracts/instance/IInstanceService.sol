// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {IService} from "../shared/IService.sol";

import {InstanceAdmin} from "./InstanceAdmin.sol";
import {Instance} from "./Instance.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";
import {InstanceStore} from "./InstanceStore.sol";

interface IInstanceService is IService {

    error ErrorInstanceServiceComponentNotInstanceLinked(address component);

    error ErrorInstanceServiceMasterInstanceAlreadySet();
    error ErrorInstanceServiceMasterInstanceAccessManagerAlreadySet();
    error ErrorInstanceServiceMasterInstanceAdminAlreadySet();
    error ErrorInstanceServiceMasterBundleManagerAlreadySet();
    error ErrorInstanceServiceInstanceAddressZero();

    error ErrorInstanceServiceMasterInstanceReaderNotSet();
    error ErrorInstanceServiceInstanceReaderAddressZero();
    error ErrorInstanceServiceInstanceReaderSameAsMasterInstanceReader();
    error ErrorInstanceServiceInstanceReaderInstanceMismatch();

    error ErrorInstanceServiceInstanceAdminZero();
    error ErrorInstanceServiceInstanceReaderZero();
    error ErrorInstanceServiceBundleManagerZero();
    error ErrorInstanceServiceInstanceStoreZero();

    error ErrorInstanceServiceInstanceAuthorityMismatch();
    error ErrorInstanceServiceBundleManagerAuthorityMismatch();
    error ErrorInstanceServiceInstanceReaderInstanceMismatch2();
    error ErrorInstanceServiceBundleMangerInstanceMismatch();
    error ErrorInstanceServiceInstanceStoreAuthorityMismatch();

    error ErrorInstanceServiceRequestUnauhorized(address caller);
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

    function createComponentTarget(
        NftId instanceNftId,
        address targetAddress,
        string memory targetName,
        bytes4[][] memory selectors,
        RoleId[] memory roles
    ) external;

    function createGifTarget(
        NftId instanceNftId,
        address targetAddress,
        string memory targetName,
        bytes4[][] memory selectors,
        RoleId[] memory roles
    ) external;

    function setComponentLocked(bool locked) external;


    function getMasterInstanceAddress() external view returns (address);
    function getMasterInstanceAdminAddress() external view returns (address);
    function getMasterInstanceReaderAddress() external view returns (address);
    function getMasterBundleManagerAddress() external view returns (address);
    function getMasterInstanceStoreAddress() external view returns (address);
}