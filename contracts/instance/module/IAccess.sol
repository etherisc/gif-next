// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {RoleId} from "../../type/RoleId.sol";
import {Timestamp} from "../../type/Timestamp.sol";

interface IAccess {

    enum Type {
        NotInitialized,
        Core,
        Gif,
        Custom        
    }

    struct RoleInfo {
        ShortString name;
        Type rtype;
        //bool isLocked;
        RoleId admin;
        Timestamp createdAt;
        Timestamp updatedAt;
    }

    struct TargetInfo {
        ShortString name;
        Type ttype;
        bool isLocked;
        Timestamp createdAt;
        Timestamp updatedAt;
    }

    error ErrorIAccessCallerIsNotRoleAdmin(address caller, RoleId roleId);

    error ErrorIAccessRoleIdDoesNotExist(RoleId roleId);
    error ErrorIAccessRoleIdTooBig(RoleId roleId);
    error ErrorIAccessRoleIdTooSmall(RoleId roleId);
    error ErrorIAccessRoleIdExists(RoleId roleId);
    error ErrorIAccessRoleNameEmpty(RoleId roleId);
    error ErrorIAccessRoleNameExists(RoleId roleId, RoleId existingRoleId, ShortString name);
    error ErrorIAccessRoleTypeInvalid(RoleId roleId, Type rtype);

    error ErrorIAccessTargetAddressZero();
    error ErrorIAccessTargetDoesNotExist(address target);
    error ErrorIAccessTargetExists(address target, ShortString name);
    error ErrorIAccessTargetTypeInvalid(address target, Type ttype);
    error ErrorIAccessTargetNameEmpty(address target);
    error ErrorIAccessTargetNameExists(address target, address existingTarget, ShortString name);
    error ErrorIAccessTargetLocked(address target);
    error ErrorIAccessTargetNotRegistered(address target);
    error ErrorIAccessTargetAuthorityInvalid(address target, address targetAuthority);
}