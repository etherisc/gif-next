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

    error ErrorTargetAddressZero();
    error ErrorTargetAlreadyExists(address target, ShortString name);
    error ErrorTargetDoesNotExist(string targetName);
    error ErrorTargetNameEmpty(address target);
    error ErrorTargetNameExists(address target, address existingTarget, ShortString name);

    error ErrorRoleIdInvalid(RoleId roleId);
    error ErrorRoleIdTooBig(RoleId roleId);
    error ErrorRoleIdTooSmall(RoleId roleId);
    error ErrorRoleIdAlreadyExists(RoleId roleId, ShortString name);
    error ErrorRoleIdNotActive(RoleId roleId);
    error ErrorRoleNameEmpty(RoleId roleId);
    error ErrorRoleNameNotUnique(RoleId roleId, ShortString name);
    error ErrorRoleInvalidUpdate(RoleId roleId, bool isCustom);
    error ErrorGrantNonexstentRole(RoleId roleId);
    error ErrorRevokeNonexstentRole(RoleId roleId);
    error ErrorRenounceNonexstentRole(RoleId roleId);

}