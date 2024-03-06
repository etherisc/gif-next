// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {RoleId} from "../../types/RoleId.sol";
import {Timestamp} from "../../types/Timestamp.sol";

interface IAccess {

    struct RoleInfo {
        ShortString name;
        bool isCustom;
        //bool isLocked;
        RoleId admin;
        Timestamp createdAt;
        Timestamp updatedAt;
    }

    struct TargetInfo {
        ShortString name;
        bool isCustom;
        bool isLocked;
        Timestamp createdAt;
        Timestamp updatedAt;
    }

    error ErrorIAccessCallerIsNotRoleAdmin(address caller, RoleId roleId);

    error ErrorIAccessRoleIdInvalid(RoleId roleId);
    error ErrorIAccessRoleIdTooBig(RoleId roleId);
    error ErrorIAccessRoleIdTooSmall(RoleId roleId);
    error ErrorIAccessRoleIdAlreadyExists(RoleId roleId);
    error ErrorIAccessRoleNameEmpty(RoleId roleId);
    error ErrorIAccessRoleNameNotUnique(RoleId roleId, ShortString name);
    error ErrorIAccessSetAdminForNonexistentRole(RoleId roleId);
    error ErrorIAccessSetNonexistentRole(RoleId roleId);
    error ErrorIAccessSetNoncustomRole(RoleId roleId);
    error ErrorIAccessSetLockedForNonexistentRole(RoleId roleId);
    error ErrorIAccessSetLockedForNoncustomRole(RoleId roleId);
    error ErrorIAccessGrantNonexistentRole(RoleId roleId);
    error ErrorIAccessRevokeNonexistentRole(RoleId roleId); 
    error ErrorIAccessRenounceNonexistentRole(RoleId roleId);

    error ErrorIAccessTargetAddressZero();
    error ErrorIAccessTargetAlreadyExists(address target, ShortString name);
    error ErrorIAccessTargetNameEmpty(address target);
    error ErrorIAccessTargetNameExists(address target, address existingTarget, ShortString name);
    error ErrorIAccessTargetLocked(address target);
    error ErrorIAccessCreateCustomTargetTargetIsRegistered(address target);
    error ErrorIAccessSetLockedForNonexistentTarget(address target);
    error ErrorIAccessSetLockedForNoncustomTarget(address target);
    error ErrorIAccessSetForNonexistentTarget(address target);
    error ErrorIAccessSetForNoncustomTarget(address target);
}