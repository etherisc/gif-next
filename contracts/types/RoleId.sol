// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {ROLE} from "./ObjectType.sol";

type RoleId is uint64;

// type bindings
using {
    eqRoleId as ==, 
    neRoleId as !=,
    RoleIdLib.eqz,
    RoleIdLib.gtz,
    RoleIdLib.toInt,
    RoleIdLib.toKey32
} for RoleId global;

// general pure free functions
function DISTRIBUTION_OWNER_ROLE_NAME() pure returns (string memory) { return "DistributionOwnerRole"; }
function ORACLE_OWNER_ROLE_NAME() pure returns (string memory) { return "OracleOwnerRole"; }
function POOL_OWNER_ROLE_NAME() pure returns (string memory) { return "PoolOwnerRole"; }
function PRODUCT_OWNER_ROLE_NAME() pure returns (string memory) { return "ProductOwnerRole"; }

// function DISTRIBUTION_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId("DistributionOwnerRole"); }
// function ORACLE_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId("OracleOwnerRole"); }
// function POOL_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId("PoolOwnerRole"); }
// function PRODUCT_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId("ProductOwnerRole"); }

// @dev Returns true iff role ids a and b are identical
function eqRoleId(RoleId a, RoleId b) pure returns (bool isSame) {
    return RoleId.unwrap(a) == RoleId.unwrap(b);
}

// @dev Returns true iff role ids a and b are different
function neRoleId(RoleId a, RoleId b) pure returns (bool isDifferent) {
    return RoleId.unwrap(a) != RoleId.unwrap(b);
}

library RoleIdLib {
/// @dev Converts the RoleId to a uint.
    function zero() public pure returns (RoleId) {
        return RoleId.wrap(0);
    }

    /// @dev Converts an uint into a RoleId.
    function toRoleId(uint256 a) public pure returns (RoleId) {
        return RoleId.wrap(uint64(a));
    }

    /// @dev Converts the RoleId to a uint.
    function toInt(RoleId a) public pure returns (uint64) {
        return uint64(RoleId.unwrap(a));
    }

    /// @dev Returns true if the value is non-zero (> 0).
    function gtz(RoleId a) public pure returns (bool) {
        return RoleId.unwrap(a) > 0;
    }

    /// @dev Returns true if the value is zero (== 0).
    function eqz(RoleId a) public pure returns (bool) {
        return RoleId.unwrap(a) == 0;
    }

    /// @dev Returns the key32 value for the specified id and object type.
    function toKey32(RoleId a) public pure returns (Key32 key) {
        return Key32Lib.toKey32(ROLE(), toKeyId(a));
    }

    /// @dev Returns the key id value for the specified id
    function toKeyId(RoleId a) public pure returns (KeyId keyId) {
        return KeyId.wrap(bytes31(uint248(RoleId.unwrap(a))));
    }
}
