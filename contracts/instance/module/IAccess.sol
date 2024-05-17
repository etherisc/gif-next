// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {NftId} from "../../type/NftId.sol";
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

    error ErrorIAccessRoleIdTooBig(RoleId roleId);
    error ErrorIAccessRoleIdTooSmall(RoleId roleId);
    error ErrorIAccessRoleTypeInvalid(RoleId roleId, Type rtype);

    error ErrorIAccessTargetAddressZero();
    error ErrorIAccessTargetTypeInvalid(address target, Type ttype);
    error ErrorIAccessTargetLocked(address target);
    error ErrorIAccessTargetNotRegistered(address target);
    error ErrorIAccessTargetAuthorityInvalid(address target, address targetAuthority);
    error ErrorIAccessTargetInstanceMismatch(address target, NftId targetParentNftId, NftId instanceNftId);
}