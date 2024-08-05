// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {RoleId} from "../type/RoleId.sol";
import {Selector} from "../type/Selector.sol";
import {Str} from "../type/String.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IAccess {

    enum RoleType {
        Undefined, // no role must have this type
        Contract, // roles assigned to contracts, cannot be revoked
        Gif, // framework roles that may be freely assigned and revoked
        Custom // use case specific rules for components
    }

    struct RoleInfo {
        RoleId adminRoleId;
        RoleType roleType;
        uint32 maxMemberCount;
        Str name;
        Timestamp createdAt;
        Timestamp pausedAt;
    }

    struct TargetInfo {
        Str name;
        bool isCustom;
        Timestamp createdAt;
    }

    struct FunctionInfo {
        Str name; // function name
        Selector selector; // function selector
        Timestamp createdAt;
    }

    struct RoleNameInfo {
        RoleId roleId;
        bool exists;
    }

    struct TargeNameInfo {
        address target;
        bool exists;
    }

}