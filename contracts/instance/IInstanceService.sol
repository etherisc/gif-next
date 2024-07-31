// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {BundleSet} from "./BundleSet.sol";
import {Instance} from "./Instance.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IService} from "../shared/IService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed} from "../type/UFixed.sol";
import {VersionPart} from "../type/Version.sol";

interface IInstanceService is IService {

    // onlyInstance
    error ErrorInstanceServiceNotRegistered(address instance);
    error ErrorInstanceServiceNotInstance(address instance, ObjectType objectType);
    error ErrorInstanceServiceInstanceVersionMismatch(address instance, VersionPart instanceVersion);

    error ErrorInstanceServiceComponentNotInstanceLinked(address component);

    error ErrorInstanceServiceMasterInstanceAlreadySet();
    error ErrorInstanceServiceMasterInstanceAdminAlreadySet();
    error ErrorInstanceServiceMasterBundleSetAlreadySet();
    error ErrorInstanceServiceInstanceAddressZero();

    error ErrorInstanceServiceMasterInstanceReaderNotSet();
    error ErrorInstanceServiceInstanceReaderAddressZero();
    error ErrorInstanceServiceInstanceReaderSameAsMasterInstanceReader();
    error ErrorInstanceServiceInstanceReaderInstanceMismatch();

    error ErrorInstanceServiceAccessManagerZero();
    error ErrorInstanceServiceInstanceAdminZero();
    error ErrorInstanceServiceInstanceReaderZero();
    error ErrorInstanceServiceBundleSetZero();
    error ErrorInstanceServiceInstanceStoreZero();

    error ErrorInstanceServiceInstanceAuthorityMismatch();
    error ErrorInstanceServiceBundleSetAuthorityMismatch();
    error ErrorInstanceServiceInstanceReaderInstanceMismatch2();
    error ErrorInstanceServiceBundleMangerInstanceMismatch();
    error ErrorInstanceServiceInstanceStoreAuthorityMismatch();

    error ErrorInstanceServiceRequestUnauhorized(address caller);
    error ErrorInstanceServiceNotInstanceNftId(NftId nftId);
    error ErrorInstanceServiceComponentNotRegistered(address componentAddress);
    error ErrorInstanceServiceInstanceComponentMismatch(NftId instanceNftId, NftId componentNftId);
    error ErrorInstanceServiceInvalidComponentType(address componentAddress, ObjectType expectedType, ObjectType componentType);
    
    event LogInstanceCloned(NftId instanceNftId, address instance);

    function createInstance()
        external 
        returns (
            // TODO check if Instance can be changed to IInstance
            Instance clonedInstance,
            NftId instanceNftId
        );


    function setStakingLockingPeriod(Seconds stakeLockingPeriod) external;
    function setStakingRewardRate(UFixed rewardRate) external;
    function refillStakingRewardReserves(address rewardProvider, Amount dipAmount) external;

    /// @dev Defunds the staking reward reserves for the specified target.
    function withdrawStakingRewardReserves(Amount dipAmount) external returns (Amount newBalance);

    function setComponentLocked(bool locked) external;
}