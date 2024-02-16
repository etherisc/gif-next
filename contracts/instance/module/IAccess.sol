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
        bool isLocked;
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

    error ErrorIAccessRoleIdInvalid(RoleId roleId);
    error ErrorIAccessRoleIdTooBig(RoleId roleId);
    error ErrorIAccessRoleIdTooSmall(RoleId roleId);
    error ErrorIAccessRoleIdAlreadyExists(RoleId roleId, ShortString name);
    error ErrorIAccessRoleIdNotActive(RoleId roleId);
    error ErrorIAccessRoleNameEmpty(RoleId roleId);
    error ErrorIAccessRoleNameNotUnique(RoleId roleId, ShortString name);
    error ErrorIAccessRoleInvalidUpdate(RoleId roleId, bool isCustom);
    error ErrorIAccessRoleIsCustomIsImmutable(RoleId roleId, bool isCustom, bool isCustomExisting);
    error ErrorIAccessSetLockedForNonexstentRole(RoleId roleId);
    error ErrorIAccessGrantNonexstentRole(RoleId roleId);
    error ErrorIAccessRevokeNonexstentRole(RoleId roleId); 
    error ErrorIAccessRenounceNonexstentRole(RoleId roleId);

    error ErrorIAccessTargetAddressZero();
    error ErrorIAccessTargetAlreadyExists(address target, ShortString name);
    error ErrorIAccessTargetNameEmpty(address target);
    error ErrorIAccessTargetNameExists(address target, address existingTarget, ShortString name);
    error ErrorIAccessSetLockedForNonexstentTarget(address target);
    error ErrorIAccessTargetLocked(address target);
}