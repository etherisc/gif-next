// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IInstance} from "./IInstance.sol";
import {IService} from "../shared/IService.sol";

import {Amount} from "../type/Amount.sol";
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
    error ErrorInstanceServiceInstanceVersionMismatch(NftId instanceNftId, VersionPart expectedRelease, VersionPart instanceRelease);

    error ErrorInstanceServiceComponentNotInstanceLinked(address component);

    error ErrorInstanceServiceMasterInstanceAlreadySet();
    error ErrorInstanceServiceMasterInstanceAdminAlreadySet();
    error ErrorInstanceServiceMasterBundleSetAlreadySet();
    error ErrorInstanceServiceMasterRiskSetAlreadySet();
    error ErrorInstanceServiceInstanceAddressZero();

    error ErrorInstanceServiceMasterInstanceReaderNotSet();
    error ErrorInstanceServiceInstanceReaderAddressZero();
    error ErrorInstanceServiceInstanceReaderSameAsMasterInstanceReader();
    error ErrorInstanceServiceInstanceReaderInstanceMismatch();

    error ErrorInstanceServiceAccessManagerZero();
    error ErrorInstanceServiceInstanceAdminZero();
    error ErrorInstanceServiceInstanceReaderZero();
    error ErrorInstanceServiceBundleSetZero();
    error ErrorInstanceServiceRiskSetZero();
    error ErrorInstanceServiceInstanceStoreZero();

    error ErrorInstanceServiceInstanceAuthorityMismatch();
    error ErrorInstanceServiceBundleSetAuthorityMismatch();
    error ErrorInstanceServiceRiskSetAuthorityMismatch();
    error ErrorInstanceServiceInstanceReaderInstanceMismatch2();
    error ErrorInstanceServiceBundleSetInstanceMismatch();
    error ErrorInstanceServiceRiskSetInstanceMismatch();
    error ErrorInstanceServiceInstanceStoreAuthorityMismatch();

    error ErrorInstanceServiceRequestUnauhorized(address caller);
    error ErrorInstanceServiceNotInstanceNftId(NftId nftId);
    error ErrorInstanceServiceComponentNotRegistered(address componentAddress);
    error ErrorInstanceServiceInstanceComponentMismatch(NftId instanceNftId, NftId componentNftId);
    error ErrorInstanceServiceInvalidComponentType(address componentAddress, ObjectType expectedType, ObjectType componentType);
    
    event LogInstanceServiceInstanceLocked(NftId instanceNftId, bool locked);
    event LogInstanceServiceInstanceCreated(NftId instanceNftId, address instance);
    event LogInstanceServiceMasterInstanceReaderUpgraded(NftId instanceNfId, address newInstanceReader);
    event LogInstanceServiceInstanceReaderUpgraded(NftId instanceNfId, address newInstanceReader);

    /// @dev Creates a new custom role for the calling instance.
    function createRole(string memory roleName, RoleId adminRoleId, uint32 maxMemberCount) external returns (RoleId roleId);

    /// @dev Sets the specified custom role as active or inactive for the calling instance.
    function setRoleActive(RoleId roleId, bool active) external;

    /// @dev Grants the specified custom role to the specified account for the calling instance.
    function grantRole(RoleId roleId, address account) external; 

    /// @dev Revokes the specified custom role from the specified account for the calling instance.
    function revokeRole(RoleId roleId, address account) external; 

    /// @dev Creates a new custom target for the calling instance.
    /// All custom trargets are created with a corresponding contract role.
    function createTarget(address target, string memory name) external returns (RoleId contractRoleId);

    /// @dev Authorizes the specified functions for the specified target.
    function authorizeFunctions(address target, RoleId roleId, IAccess.FunctionInfo[] memory functions) external; 

    /// @dev Removes any role authorization for the specified functions.
    function unauthorizeFunctions(address target, IAccess.FunctionInfo[] memory functions) external;

    /// @dev Locks/unlocks the specified target constrolled by the corresponding instance admin.
    function setTargetLocked(address target, bool locked) external;

    /// @dev Locks the complete instance, including all its components.
    function setInstanceLocked(bool locked) external;

    /// @dev Creates a new instance.
    /// The caller becomes the owner of the new instance.
    /// Creation of a new instance is achieved by this service through the creation and registration 
    /// of a new clone of the master instance and then setting up the initial wiring and authorization 
    /// of the necessary components.
    /// @param allowAnyToken specifies whether the new instance is allowed to use any token or 
    /// only tokens that are registered in the `TokenRegistry`. Use of tokens **not** registered in the
    /// `TokenRegistry` may result in problems with token handline and is therefor not recommended. The 
    /// use of such instances **is not supported** by Etherisc. 
    function createInstance(bool allowAnyToken)
        external 
        returns (
            IInstance instance,
            NftId instanceNftId
        );

    function upgradeInstanceReader() external;
    function upgradeMasterInstanceReader(address instanceReaderAddress) external;

    function setStakingLockingPeriod(Seconds stakeLockingPeriod) external;
    function setStakingRewardRate(UFixed rewardRate) external;
    function setStakingMaxAmount(Amount maxStakedAmount) external;
    function refillStakingRewardReserves(address rewardProvider, Amount dipAmount) external;

    /// @dev Defunds the staking reward reserves for the specified target.
    function withdrawStakingRewardReserves(Amount dipAmount) external returns (Amount newBalance);
}