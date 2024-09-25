// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Blocknumber} from "../type/Blocknumber.sol";
import {RoleId} from "../type/RoleId.sol";
import {Selector} from "../type/Selector.sol";
import {Str} from "../type/String.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IAccess {

    enum TargetType {
        Undefined, // no target must have this type
        Core, // GIF core contracts
        GenericService, // release independent service contracts
        Service, // service contracts
        Instance, // instance contracts
        Component, // instance contracts
        Contract, // normal contracts
        Custom // use case specific rules for contracts or normal accounts
    }

    struct RoleInfo {
        // slot 0
        RoleId adminRoleId;  // 64
        TargetType targetType; // ?
        uint32 maxMemberCount; // 32
        Timestamp createdAt; // 40
        Timestamp pausedAt; // 40
        Blocknumber lastUpdateIn; // 40
        // slot 1
        Str name; // 256
    }


    // TODO recalc slot allocation
    struct TargetInfo {
        Str name;
        TargetType targetType;
        RoleId roleId;
        Timestamp createdAt;
        Blocknumber lastUpdateIn;
    }

    struct FunctionInfo {
        // slot 0
        Str name; // function name
        // slot 1
        Selector selector; // function selector
        Timestamp createdAt;
        Blocknumber lastUpdateIn;
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