// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

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
    error ErrorIAccessSetNoncustomRole(RoleId roleId);
    error ErrorIAccessSetLockedForNoncustomRole(RoleId roleId);

    error ErrorIAccessTargetAddressZero();
    error ErrorIAccessTargetDoesNotExist(ShortString name);
    error ErrorIAccessTargetAlreadyExists(address target, ShortString name);
    error ErrorIAccessTargetNameEmpty(address target);
    error ErrorIAccessTargetNameExists(address target, address existingTarget, ShortString name);
    error ErrorIAccessTargetLocked(address target);
    error ErrorIAccessTargetIsRegistered(address target);
    error ErrorIAccessSetLockedForNoncustomTarget(address target);
    error ErrorIAccessSetForNoncustomTarget(address target);
}