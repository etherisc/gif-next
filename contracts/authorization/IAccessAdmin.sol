// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IAccess} from "./IAccess.sol";
import {IAuthorization} from "./IAuthorization.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {IRelease} from "../registry/IRelease.sol";

import {Blocknumber} from "../type/Blocknumber.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {Str} from "../type/String.sol";
import {VersionPart} from "../type/Version.sol";

/// @dev Base interface for registry admin, release admin, and instance admin 
interface IAccessAdmin is 
    IAccessManaged,
    IAccess,
    IRegistryLinked,
    IRelease
{

    // roles, targets and functions
    event LogAccessAdminRoleCreated(string admin, RoleId roleId, RoleType roleType, RoleId roleAdminId, string name);
    event LogAccessAdminTargetCreated(string admin, string name, bool managed, address target, RoleId roleId);

    event LogAccessAdminRoleActivatedSet(string admin, RoleId roleId, bool active, Blocknumber lastUpdateIn);
    event LogAccessAdminRoleGranted(string admin, address account, string roleName);
    event LogAccessAdminRoleRevoked(string admin, address account, string roleName);
    event LogAccessAdminTargetLockedSet(string admin, address target, bool locked, Blocknumber lastUpdateIn);
    event LogAccessAdminFunctionGranted(string admin, address target, string func, Blocknumber lastUpdateIn);

    // only deployer modifier
    error ErrorAccessAdminNotDeployer();

    // only role admin modifier
    error ErrorAccessAdminNotAdminOfRole(RoleId adminRoleId, address account);

    // only role owner modifier
    error ErrorAccessAdminNotRoleOwner(RoleId roleId, address account);

    // role management
    error ErrorAccessAdminInvalidUserOfAdminRole();
    error ErrorAccessAdminInvalidUserOfPublicRole();
    error ErrorAccessAdminRoleNotCustom(RoleId roleId);

    // initialization
    error ErrorAccessAdminNotRegistry(address registry);
    error ErrorAccessAdminAuthorityNotContract(address authority);
    error ErrorAccessAdminAccessManagerNotAccessManager(address authority);
    error ErrorAccessAdminAccessManagerEmptyName();

    // check target
    error ErrorAccessAdminInvalidTargetType(address target, TargetType targetType);
    error ErrorAccessAdminInvalidServiceType(address target, TargetType serviceTargetType);
    error ErrorAccessAdminTargetNotCreated(address target);
    error ErrorAccessAdminTargetNotRegistered(address target);
    error ErrorAccessAdminTargetTypeMismatch(address target, ObjectType expectedType, ObjectType actualType);

    // check authorization
    error ErrorAccessAdminAlreadyInitialized(address authorization);
    error ErrorAccessAdminNotAuthorization(address authorization);
    error ErrorAccessAdminNotServiceAuthorization(address serviceAuthorization);
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

    // toFunction
    error ErrorAccessAdminSelectorZero();
    error ErrorAccessAdminFunctionNameEmpty();

    // check target
    error ErrorAccessAdminTargetUnknown(address target);

    //--- view functions ----------------------------------------------------//

    function getAuthorization() external view returns (IAuthorization authorization);
    function getLinkedNftId() external view returns (NftId linkedNftId);
    function getLinkedOwner() external view returns (address linkedOwner);

    function isLocked() external view returns (bool locked);

    function roles() external view returns (uint256 numberOfRoles);
    function getRoleId(uint256 idx) external view returns (RoleId roleId);

    function roleExists(RoleId roleId) external view returns (bool exists); 
    function roleForNameExists(string memory roleName) external view returns (bool exists); 
    function getRoleForName(string memory name) external view returns (RoleId roleId, bool exists);
    function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory roleInfo);
    function isRoleActive(RoleId roleId) external view returns (bool isActive);
    function isRoleCustom(RoleId roleId) external view returns (bool isCustom);

    function isRoleMember(RoleId roleId, address account) external view returns (bool);
    function isRoleAdmin(RoleId roleId, address account) external view returns (bool);
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