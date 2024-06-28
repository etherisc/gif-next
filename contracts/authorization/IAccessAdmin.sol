// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IAccess} from "./IAccess.sol";
import {RoleId} from "../type/RoleId.sol";
import {Selector} from "../type/Selector.sol";
import {Str} from "../type/String.sol";

interface IAccessAdmin is 
    IAccessManaged,
    IAccess
{

    // roles
    event LogRoleCreated(RoleId roleId, RoleType roleType, RoleId roleAdminId, string name);
    event LogTargetCreated(address target, string name);
    event LogFunctionCreated(address target, Selector selector, string name);

    // only deployer modifier
    error ErrorNotDeployer();

    // only role admin modifier
    error ErrorNotAdminOfRole(RoleId adminRoleId);

    // only role owner modifier
    error ErrorNotRoleOwner(RoleId roleId);

    // initialize authority
    error ErrorAuthorityAlreadySet();
    error ErrorAdminRoleMissing();

    // create role
    error ErrorRoleAlreadyCreated(RoleId roleId, string name);
    error ErrorRoleAdminNotExisting(RoleId adminRoleId);
    error ErrorRoleNameEmpty(RoleId roleId);
    error ErrorRoleNameAlreadyExists(RoleId roleId, string name, RoleId existingRoleId);

    // grant/revoke/renounce role
    error ErrorRoleUnknown(RoleId roleId);
    error ErrorRoleIsLocked(RoleId roleId);
    error ErrorRoleIsDisabled(RoleId roleId);
    error ErrorRoleMembersLimitReached(RoleId roleId, uint256 memberCountLimit);
    error ErrorRoleRemovalDisabled(RoleId roleId);

    // create target
    error ErrorTargetAlreadyCreated(address target, string name);
    error ErrorTargetNameEmpty(address target);
    error ErrorTargetNameAlreadyExists(address target, string name, address existingTarget);
    error ErrorTargetNotAccessManaged(address target);
    error ErrorTargetAuthorityMismatch(address expectedAuthority, address actualAuthority);

    // lock target
    error ErrorTagetNotLockable();

    // authorize target functions
    error ErrorAuthorizeForAdminRoleInvalid(address target);

    // check target
    error ErrorTargetUnknown(address target);

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

    function roles() external view returns (uint256 numberOfRoles);
    function getRoleId(uint256 idx) external view returns (RoleId roleId);
    function getAdminRole() external view returns (RoleId roleId);
    function getPublicRole() external view returns (RoleId roleId);

    function roleExists(RoleId roleId) external view returns (bool exists); 
    function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory roleInfo);
    function getRoleForName(Str name) external view returns (RoleNameInfo memory);

    function hasRole(address account, RoleId roleId) external view returns (bool);
    function hasAdminRole(address account, RoleId roleId) external view returns (bool);
    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers);
    function getRoleMember(RoleId roleId, uint256 idx) external view returns (address account);

    function targetExists(address target) external view returns (bool exists);
    function isTargetLocked(address target) external view returns (bool locked);
    function targets() external view returns (uint256 numberOfTargets);
    function getTargetAddress(uint256 idx) external view returns (address target);
    function getTargetInfo(address target) external view returns (TargetInfo memory targetInfo);
    function getTargetForName(Str name) external view returns (address target);

    function authorizedFunctions(address target) external view returns (uint256 numberOfFunctions);
    function getAuthorizedFunction(address target, uint256 idx) external view returns (FunctionInfo memory func, RoleId roleId);
    function canCall(address caller, address target, Selector selector) external view returns (bool can);

    function toRole(RoleId adminRoleId, RoleType roleType, uint32 maxMemberCount, string memory name) external view returns (RoleInfo memory);
    function toFunction(bytes4 selector, string memory name) external view returns (FunctionInfo memory);
    function isAccessManaged(address target) external view returns (bool);
    function deployer() external view returns (address);
}