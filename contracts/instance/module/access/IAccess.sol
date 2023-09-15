// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistryLinked} from "../../../registry/IRegistry.sol";

interface IAccess {
    struct RoleInfo {
        bytes32 id;
        string name;
        bool isActive;
    }
}

interface IAccessCheckRole {
    function hasRole(bytes32 role, address member) external view returns (bool);
}

interface IAccessComponentTypeRoles {
    function PRODUCT_OWNER_ROLE() external view returns (bytes32 role);

    function ORACLE_OWNER_ROLE() external view returns (bytes32 role);

    function POOL_OWNER_ROLE() external view returns (bytes32 role);
}

interface IAccessModule is
    IOwnable,
    IRegistryLinked,
    IAccess,
    IAccessComponentTypeRoles,
    IAccessCheckRole
{
    function createRole(string memory roleName) external returns (bytes32 role);

    function enableRole(bytes32 role) external;

    function disableRole(bytes32 role) external;

    function grantRole(bytes32 role, address member) external;

    function revokeRole(bytes32 role, address member) external;

    function getRole(uint256 idx) external view returns (bytes32 role);

    function getRoleInfo(
        bytes32 role
    ) external view returns (RoleInfo memory info);

    function getRoleForName(
        string memory roleName
    ) external pure returns (bytes32 role);

    function getRoleCount() external view returns (uint256 roles);

    function getRoleMemberCount(
        bytes32 role
    ) external view returns (uint256 roleMembers);

    function getRoleMember(
        bytes32 role,
        uint256 idx
    ) external view returns (address roleMembers);
}
