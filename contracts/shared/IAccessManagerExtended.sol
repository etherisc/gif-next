// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/manager/IAccessManager.sol)

pragma solidity ^0.8.20;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import {Timestamp} from "../type/Timestamp.sol";

interface IAccessManagerExtended is IAccessManager {
    // Structure that stores the details for a target contract.
    struct TargetInfo {
        address taddress;
        //IAccess.Type ttype;
        string name;
        Timestamp createdAt;
        //Timestamp updatedAt;
    }

    // Structure that stores the details of a role.
    struct RoleInfo {
        uint64 id;
        //IAccess.Type rtype;
        string name;
        Timestamp createdAt;
    }

    event LogRoleCreation(uint64 roleId, string name);// IAccess.Type rtype);
    event LogTargetCreation(address target, string name);// IAccess.Type ttype);

    error AccessManagerRoleIdNotExists(uint64 roleId);
    error AccessManagerRoleIdAlreadyExists(uint64 roleId);
    error AccessManagerRoleNameAlreadyExists(uint64 newRoleId, uint64 existingRoleId, string duplicateName);
    error AccessManagerRoleIdZero();
    error AccessManagerRoleNameEmpty(uint64 roleId);
    error AccessManagerRoleIdTooBig(uint64 roleId);

    error AccessManagerTargetAlreadyExists(address target);
    error AccessManagerTargetNotExists(address target);
    error AccessManagerTargetNameAlreadyExists(address newTarget, address existingTarget, string duplicateName);
    error AccessManagerTargetAddressZero();
    error AccessManagerTargetNameEmpty(address target);
    error AccessManagerTargetAuthorityInvalid(address target, address targetAuthority);

    function getRoleMembers(uint64 roleId) external view returns (uint256 numberOfMembers);

    function getRoleMember(uint64 roleId, uint256 idx) external view returns (address member);

    function getRoleId(uint256 idx) external view returns (uint64 roleId);

    // TODO returns ADMIN_ROLE id for non existent name
    function getRoleId(string memory name) external view returns (uint64 roleId);

    function getRoles() external view returns (uint256 numberOfRoles);

    function isRoleExists(uint64 roleId) external view returns (bool exists);

    function getRoleInfo(uint64 roleId) external view returns (RoleInfo memory);


    function isTargetExists(address target) external view returns (bool);

    function getTargetAddress(string memory name) external view returns(address targetAddress);

    function getTargetInfo(address target) external view returns (TargetInfo memory);


    function createRole(uint64 roleId, string memory roleName/*, IAccess.Type rtype*/) external;

    function createTarget(address target, string memory name/*, IAccess.Type.Custom*/) external;
}