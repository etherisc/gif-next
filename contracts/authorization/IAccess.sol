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
        // slot 0
        RoleId adminRoleId; 
        RoleType roleType; 
        uint32 maxMemberCount; 
        Timestamp createdAt; 
        Timestamp pausedAt; 
        // slot 1
        Str name;
    }

    struct TargetInfo {
        // slot 0
        Str name;
        // slot 1
        bool isCustom;
        Timestamp createdAt;
    }

    struct FunctionInfo {
        // slot 0
        Str name; // function name
        // slot 1
        Selector selector; // function selector
        Timestamp createdAt;
    }

    struct RoleNameInfo {
        // slot 0
        RoleId roleId;
        bool exists;
    }

    struct TargeNameInfo {
        // slot 0
        address target;
        bool exists;
    }

}