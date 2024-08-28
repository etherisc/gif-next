// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IAccess} from "./IAccess.sol";
import {IAuthorization} from "./IAuthorization.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {IRelease} from "../registry/IRelease.sol";

import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {Selector} from "../type/Selector.sol";
import {Str} from "../type/String.sol";
import {VersionPart} from "../type/Version.sol";

interface IAccessAdmin is 
    IAccessManaged,
    IAccess,
    IRegistryLinked,
    IRelease
{

    // roles, targets and functions
    event LogAccessAdminRoleCreated(string admin, RoleId roleId, RoleType roleType, RoleId roleAdminId, string name);
    event LogAccessAdminTargetCreated(string admin, address target, string name);

    event LogAccessAdminRoleGranted(string admin, address account, string roleName);
    event LogAccessAdminRoleRevoked(string admin, address account, string roleName);
    event LogAccessAdminFunctionGranted(string admin, address target, string func);

    // only deployer modifier
    error ErrorAccessAdminNotDeployer();

    // only role admin modifier
    error ErrorAccessAdminNotAdminOfRole(RoleId adminRoleId, address account);

    // only role owner modifier
    error ErrorAccessAdminNotRoleOwner(RoleId roleId, address account);

    // only custom role modifier
    error ErrorAccessAdminRoleNotCustom(RoleId roleId);

    // initialization
    error ErrorAccessAdminNotRegistry(address registry);
    error ErrorAccessAdminAuthorityNotContract(address authority);
    error ErrorAccessAdminAccessManagerNotAccessManager(address authority);
    error ErrorAccessAdminAccessManagerEmptyName();

    // check target
    error ErrorAccessAdminTargetNotCreated(address target);
    error ErrorAccessAdminTargetNotRegistered(address target);
    error ErrorAccessAdminTargetTypeMismatch(address target, ObjectType expectedType, ObjectType actualType);

    // check authorization
    error ErrorAccessAdminAlreadyInitialized(address authorization);
    error ErrorAccessAdminNotAuthorization(address authorization);
    error ErrorAccessAdminDomainMismatch(address authorization, ObjectType expectedDomain, ObjectType actualDomain);
    error ErrorAccessAdminReleaseMismatch(address authorization, VersionPart expectedRelease, VersionPart actualRelease);

    // link to nft
    error ErrorAccessAdminNotRegistered(address registerable);

    // initialize authority
    error ErrorAccessAdminAdminRoleMissing();

    // create role
    error ErrorAccessAdminRoleAlreadyCreated(RoleId roleId, string name);
    error ErrorAccessAdminRoleAdminNotExisting(RoleId adminRoleId);
    error ErrorAccessAdminRoleNameEmpty(RoleId roleId);
    error ErrorAccessAdminRoleNameAlreadyExists(RoleId roleId, string name, RoleId existingRoleId);

    // grant/revoke/renounce role
    error ErrorAccessAdminRoleUnknown(RoleId roleId);
    error ErrorAccessAdminRoleIsLocked(RoleId roleId);
    error ErrorAccessAdminRoleIsPaused(RoleId roleId);
    error ErrorAccessAdminRoleMembersLimitReached(RoleId roleId, uint256 memberCountLimit);
    error ErrorAccessAdminRoleMemberNotContract(RoleId roleId, address notContract);
    error ErrorAccessAdminRoleMemberRemovalDisabled(RoleId roleId, address expectedMember);

    // create target
    error ErrorAccessAdminTargetAlreadyCreated(address target, string name);
    error ErrorAccessAdminTargetNameEmpty(address target);
    error ErrorAccessAdminTargetNameAlreadyExists(address target, string name, address existingTarget);
    error ErrorAccessAdminTargetNotAccessManaged(address target);
    error ErrorAccessAdminTargetAuthorityMismatch(address expectedAuthority, address actualAuthority);

    // lock target
    error ErrorAccessAdminTagetNotLockable();
    error ErrorAccessAdminTargetAlreadyLocked(address target, bool isLocked);

    // authorize target functions
    error ErrorAccessAdminAuthorizeForAdminRoleInvalid(address target);

    // check target
    error ErrorAccessAdminTargetUnknown(address target);

    /// @dev Set the disabled status of the speicified role.
    /// Role disabling only prevents the role from being granted to new accounts.
    /// Existing role members may still execute functions that are authorized for that role.
    /// Permissioned: the caller must have the manager role (getManagerRole).
    // TODO move to instance admin
    // function setRoleDisabled(RoleId roleId, bool disabled) external;

    /// @dev Grant the specified account the provided role.
    /// Permissioned: the caller must have the roles admin role.
    // TODO move to instance admin
    // function grantRole(address account, RoleId roleId) external;

    /// @dev Revoke the provided role from the specified account.
    /// Permissioned: the caller must have the roles admin role.
    // TODO move to instance admin
    // function revokeRole(address account, RoleId roleId) external;

    /// @dev Removes the provided role from the caller
    // TODO move to instance admin
    // function renounceRole(RoleId roleId) external;

    /// @dev Set the locked status of the speicified contract.
    /// IMPORTANT: using this function the AccessManager might itself be put into locked state from which it cannot be unlocked again.
    /// Overwrite this function if a different use case specific behaviour is required.
    /// Alternatively, add specific function to just unlock this contract without a restricted() modifier.
    /// Permissioned: the caller must have the manager role (getManagerRole).
    // TODO move to instance admin
    // function setTargetLocked(address target, bool locked) external;

    /// @dev Specifies which functions of the target can be accessed by the provided role.
    /// Previously existing authorizations will be overwritten.
    /// Authorizing the admin role is not allowed, use function unauthorizedFunctions for this.
    /// Permissioned: the caller must have the manager role (getManagerRole).
    // TODO move to instance admin
    // function authorizeFunctions(address target, RoleId roleId, FunctionInfo[] memory functions) external;

    /// @dev Specifies for which functionss to remove any previous authorization
    /// Permissioned: the caller must have the manager role (getManagerRole).
    // TODO move to instance admin
    // function unauthorizeFunctions(address target, FunctionInfo[] memory functions) external;

    //--- view functions ----------------------------------------------------//

    function getAuthorization() external view returns (IAuthorization authorization);
    function getLinkedNftId() external view returns (NftId linkedNftId);
    function getLinkedOwner() external view returns (address linkedOwner);

    function isLocked() external view returns (bool locked);

    function roles() external view returns (uint256 numberOfRoles);
    function getRoleId(uint256 idx) external view returns (RoleId roleId);
    function getAdminRole() external view returns (RoleId roleId);
    function getPublicRole() external view returns (RoleId roleId);

    function roleExists(RoleId roleId) external view returns (bool exists); 
    function getRoleForName(string memory name) external view returns (RoleId roleId);
    function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory roleInfo);
    function isRoleActive(RoleId roleId) external view returns (bool isActive);
    function isRoleCustom(RoleId roleId) external view returns (bool isCustom);

    function isRoleMember(address account, RoleId roleId) external view returns (bool);
    function isRoleAdmin(address account, RoleId roleId) external view returns (bool);
    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers);
    function getRoleMember(RoleId roleId, uint256 idx) external view returns (address account);

    function targetExists(address target) external view returns (bool exists);
    function getTargetForName(Str name) external view returns (address target);
    function targets() external view returns (uint256 numberOfTargets);
    function getTargetAddress(uint256 idx) external view returns (address target);
    function getTargetInfo(address target) external view returns (TargetInfo memory targetInfo);
    function isTargetLocked(address target) external view returns (bool locked);

    function authorizedFunctions(address target) external view returns (uint256 numberOfFunctions);
    function getAuthorizedFunction(address target, uint256 idx) external view returns (FunctionInfo memory func, RoleId roleId);

    function deployer() external view returns (address);
}