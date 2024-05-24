// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {RoleId} from "../type/RoleId.sol";
import {Str} from "../type/String.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IAccessAdmin is 
    IAccessManaged
{

    event LogRoleCreated(RoleId roleId, RoleId roleAdminId, string name);
    event LogRoleGranted(RoleId roleId, address account);
    event LogRoleRevoked(RoleId roleId, address account);
    event LogRoleRenounced(RoleId roleId, address account);

    event LogTargetCreated(address target, string name);

    // only deployer modifier
    error ErrorNotDeployer();

    // only role admin modifier
    error ErrorNotAdminOfRole(RoleId adminRoleId);

    // only role owner modifier
    error ErrorNotRoleOwner();

    // initialize authority
    error ErrorAuthorityAlreadySet();
    error ErrorAdminRoleMissing();

    // create role
    error ErrorRoleAlreadyCreated(RoleId roleId, string name);
    error ErrorRoleAdminNotExisting(RoleId adminRoleId);
    error ErrorRoleNameEmpty(RoleId roleId);
    error ErrorRoleNameAlreadyExists(RoleId roleId, string name, RoleId existingRoleId);

    // grant/revoke/renounce role
    error ErrorRoleIsLocked(RoleId roleId);

    // create target
    error ErrorTargetAlreadyCreated(address target, string name);
    error ErrorTargetNameEmpty(address target);
    error ErrorTargetNameAlreadyExists(address target, string name, address existingTarget);
    error ErrorTargetNotAccessManaged(address target);
    error ErrorTargetAuthorityMismatch(address expectedAuthority, address actualAuthority);

    struct RoleInfo {
        RoleId adminRoleId;
        Str name;
        Timestamp disabledAt;
        Timestamp createdAt;
    }

    struct RoleNameInfo {
        RoleId roleId;
        bool exists;
    }

    struct TargetInfo {
        Str name;
        Timestamp createdAt;
    }

    /// @dev Create a new named role using the specified parameters.
    /// The adminRoleId refers to the required role to grant/revoke the newly created role.
    /// permissioned: the caller must have the manager role (getManagerRole).
    function createRole(RoleId roleId, RoleId adminRoleId, string memory name) external;

    /// @dev Grant the specified account the provided role.
    /// permissioned: the caller must have the roles admin role.
    function grantRole(address account, RoleId roleId) external;

    /// @dev Revoke the provided role from the specified account.
    /// permissioned: the caller must have the roles admin role.
    function revokeRole(address account, RoleId roleId) external;

    /// @dev Removes the provided role from the caller
    function renounceRole(RoleId roleId) external;

    /// @dev Create a new named target.
    /// permissioned: the caller must have the manager role (getManagerRole).
    function createTarget(address target, string memory name) external;

    //--- view functions ----------------------------------------------------//

    function roles() external view returns (uint256 numberOfRoles);
    function getRoleId(uint256 idx) external view returns (RoleId roleId);
    function getAdminRole() external view returns (RoleId roleId);
    function getManagerRole() external view returns (RoleId roleId);
    function getPublicRole() external view returns (RoleId roleId);

    function roleExists(RoleId roleId) external view returns (bool exists); 
    function roleIsActive(RoleId roleId) external view returns (bool roleIsActive);
    function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory roleInfo);
    function getRoleForName(Str name) external view returns (RoleNameInfo memory);

    function hasRole(address account, RoleId roleId) external view returns (bool);
    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers);
    function getRoleMember(RoleId roleId, uint256 idx) external view returns (address account);

    function isAccessManaged(address target) external view returns (bool);
    function targetExists(address target) external view returns (bool exists);
    function targets() external view returns (uint256 numberOfTargets);
    function getTargetAddress(uint256 idx) external view returns (address target);
    function getTargetInfo(address target) external view returns (TargetInfo memory targetInfo);
    function getTargetForName(Str name) external view returns (address target);

    function deployer() external view returns (address);
}