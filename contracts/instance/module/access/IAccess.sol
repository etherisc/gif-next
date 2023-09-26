// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {RoleId} from "../../../types/RoleId.sol";

interface IAccess {
    struct RoleInfo {
        RoleId id;
        string name;
        bool isActive;
    }
}

interface IAccessModule is
    IAccess
{
    event LogAccessRoleCreated(RoleId role, string roleName);
    event LogAccessRoleStateSet(RoleId role, bool active);
    event LogAccessRoleGranted(RoleId role, address member, bool isMember);

    function createRole(string memory roleName) external returns (RoleId role);

    function setRoleState(RoleId role, bool active) external;

    function grantRole(RoleId role, address member) external;

    function revokeRole(RoleId role, address member) external;

    function roleExists(RoleId role) external view returns (bool);

    function hasRole(RoleId role, address member) external view returns (bool);

    function getRoleCount() external view returns (uint256 roles);

    function getRole(uint256 idx) external view returns (RoleId role);

    function getRoleInfo(
        RoleId role
    ) external view returns (RoleInfo memory info);

    function getRoleMemberCount(
        RoleId role
    ) external view returns (uint256 roleMembers);

    function getRoleMember(
        RoleId role,
        uint256 idx
    ) external view returns (address roleMember);

    function getOwner() external view returns (address owner);
}
