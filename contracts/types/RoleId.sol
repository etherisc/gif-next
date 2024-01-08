// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

type RoleId is bytes8;

// type bindings
using {
    eqRoleId as ==, 
    neRoleId as !=
} for RoleId global;

// general pure free functions
function DISTRIBUTION_OWNER_ROLE_NAME() pure returns (string memory) { return "DistributionOwnerRole"; }
function ORACLE_OWNER_ROLE_NAME() pure returns (string memory) { return "OracleOwnerRole"; }
function POOL_OWNER_ROLE_NAME() pure returns (string memory) { return "PoolOwnerRole"; }
function PRODUCT_OWNER_ROLE_NAME() pure returns (string memory) { return "ProductOwnerRole"; }

function DISTRIBUTION_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId("DistributionOwnerRole"); }
function ORACLE_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId("OracleOwnerRole"); }
function POOL_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId("PoolOwnerRole"); }
function PRODUCT_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId("ProductOwnerRole"); }

function PRODUCT_REGISTRAR_ROLE() pure returns(uint64 roleId) { return 1; }
function POOL_REGISTRAR_ROLE() pure returns(uint64 roleId) { return 2; }
function DISTRIBUTION_REGISTRAR_ROLE() pure returns(uint64 roleId) { return 3; }
function ORACLE_REGISTRAR_ROLE() pure returns(uint64 roleId) { return 4; }
function POLICY_REGISTRAR_ROLE() pure returns(uint64 roleId) { return 5; }
function BUNDLE_REGISTRAR_ROLE() pure returns(uint64 roleId) { return 6; }

// @dev Returns true iff role ids a and b are identical
function eqRoleId(RoleId a, RoleId b) pure returns (bool isSame) {
    return RoleId.unwrap(a) == RoleId.unwrap(b);
}

// @dev Returns true iff role ids a and b are different
function neRoleId(RoleId a, RoleId b) pure returns (bool isDifferent) {
    return RoleId.unwrap(a) != RoleId.unwrap(b);
}

library RoleIdLib {
    // @dev Converts a role string into a role id.
    function toRoleId(string memory role) public pure returns (RoleId) {
        return RoleId.wrap(bytes8(keccak256(abi.encode(role))));
    }
}
