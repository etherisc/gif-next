// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {RoleId} from "../type/RoleId.sol";
import {Selector} from "../type/Selector.sol";
import {Str} from "../type/String.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IAccess {

    enum RoleType {
        Undefined, // no role must have this type
        Core, // GIF core roles
        Contract, // roles assigned to contracts, cannot be revoked
        Custom // use case specific rules for components
    }

    enum TargetType {
        Undefined, // no target must have this type
        Core, // GIF core contracts
        GenericService, // release independent service contracts
        Service, // service contracts
        Instance, // instance contracts
        Component, // instance contracts
        Custom // use case specific rules for components
    }

    struct RoleInfo {
        Str name;
        RoleId adminRoleId;
        RoleType roleType;
        uint32 maxMemberCount;
        Timestamp createdAt;
        Timestamp pausedAt;
    }

    struct TargetInfo {
        Str name;
        TargetType targetType;
        RoleId roleId;
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