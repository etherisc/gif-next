// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

type RoleId is bytes8;

// type bindings
using {
    eqRoleId as ==, 
    neRoleId as !=
} for RoleId global;

// general pure free functions
function DISTRIBUTOR_OWNER_ROLE_NAME() pure returns (string memory) { return "DistributorOwnerRole"; }
function ORACLE_OWNER_ROLE_NAME() pure returns (string memory) { return "OracleOwnerRole"; }
function POOL_OWNER_ROLE_NAME() pure returns (string memory) { return "PoolOwnerRole"; }
function PRODUCT_OWNER_ROLE_NAME() pure returns (string memory) { return "ProductOwnerRole"; }

function DISTRIBUTOR_OWNER_ROLE() pure returns (RoleId) { return toRoleId("DistributorOwnerRole"); }
function ORACLE_OWNER_ROLE() pure returns (RoleId) { return toRoleId("OracleOwnerRole"); }
function POOL_OWNER_ROLE() pure returns (RoleId) { return toRoleId("PoolOwnerRole"); }
function PRODUCT_OWNER_ROLE() pure returns (RoleId) { return toRoleId("ProductOwnerRole"); }

// @dev Converts a role string into a role id.
function toRoleId(string memory role) pure returns (RoleId) {
    return RoleId.wrap(bytes8(keccak256(abi.encode(role))));
}

// @dev Returns true iff role ids a and b are identical
function eqRoleId(RoleId a, RoleId b) pure returns (bool isSame) {
    return RoleId.unwrap(a) == RoleId.unwrap(b);
}

// @dev Returns true iff role ids a and b are different
function neRoleId(RoleId a, RoleId b) pure returns (bool isDifferent) {
    return RoleId.unwrap(a) != RoleId.unwrap(b);
}
