// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {RoleId} from "../type/RoleId.sol";
import {Selector} from "../type/Selector.sol";
import {Str} from "../type/String.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IAccess {

    struct RoleInfo {
        RoleId adminRoleId;
        Str name;
        bool isCustom;
        uint256 maxMemberCount;
        bool memberRemovalDisabled;
        Timestamp createdAt;
        Timestamp disabledAt;
    }

    struct RoleNameInfo {
        RoleId roleId;
        bool exists;
    }

    struct TargetInfo {
        Str name;
        bool isCustom;
        Timestamp createdAt;
    }

    struct TargeNameInfo {
        address target;
        Timestamp createdAt;
    }

    struct FunctionInfo {
        Selector selector; // function selector
        Str name; // function name
        Timestamp createdAt;
    }

}