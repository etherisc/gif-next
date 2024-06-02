// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {ObjectType, ROLE} from "./ObjectType.sol";
import {VersionPart} from "./Version.sol";

type RoleId is uint64;

// type bindings
using {
    eqRoleId as ==, 
    neRoleId as !=,
    RoleIdLib.eqz,
    RoleIdLib.gtz,
    RoleIdLib.toInt
    // RoleIdLib.toKey32
} for RoleId global;

// general pure free functions

//--- OpenZeppelin provided roles -------------------------------------------//

/// @dev Role ID needs to match with oz AccessManager.ADMIN_ROLE
function ADMIN_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(type(uint64).min); }

/// @dev Role ID needs to match with oz AccessManager.PUBLIC_ROLE
function PUBLIC_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(type(uint64).max); }

/// @dev Default access admin (registry admin, instance admin) role with rights to manage roles
function MANAGER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(1); } 

//--- Core GIF roles (range: 1-99) ------------------------------------------//

/// @dev cental role for gif release management.
/// this role is necessary to call ReleaseManager.createNextRelease/activateNextRelease
/// the actual deployment of a release requires the GIF_MANAGER_ROLE.
/// GIF_ADMIN_ROLE is the admin of the GIF_MANAGER_ROLE.
/// only a single holder may hold this role at any time
function GIF_ADMIN_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2); } 

/// @dev role for token whith/blacklisting, deploying and registering the services for a new major release
/// registering services for a new major release is only possible after a new initial release has been created by the GIF_ADMIN_ROLE
/// token white/blacklisting is possible for any active release
function GIF_MANAGER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(3); } 

/// @dev role for registering remote staking targets and reporting remote total value locked amounts.
function GIF_REMOTE_MANAGER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(4); } 

/// @dev required role to own an instance.
/// Role is granted by instance service when cloning a new instance.
/// allows instance specific target, role and access management 
function INSTANCE_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(10); }

/// @dev instance specific  role to register/own a product component
function PRODUCT_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(11); }

/// @dev instance specific  role to register/own an oracle component
function ORACLE_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(12); }

/// @dev instance specific role to register/own a distribution component
function DISTRIBUTION_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(13); }

/// @dev instance specific  role to register/own a pool component
function POOL_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(14); }

//--- GIF contract roles (range: 200 - 9900) --------------------------------//
// created and assigned during initial deployment for registry and staking
// granting for instances and components in instance service
// object type * 100 + 0, examples:
// - registry contract role: 200 
// - staking contract role: 300 
// - instance contract role: 1000
// - product contract role: 1200

//--- GIF service roles (range 201 - 99xx) ----------------------------------//
// created and assigned by release manager contract
// object type * 100 + 1/major version, examples:
// - registry service role (any version): 201
// - registry service role (version 3): 203
// - registry service role (any version): 301
// - staking service role: (version 3): 303
// - application service role (version 3): 2003

//--- Custom roles (range > 10000) ------------------------------------------//

/// @dev role associated with the staking contract
/// this role is the admin role for the INSTANCE_OWNER_ROLE
function STAKING_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(1313); }

/// @dev role associated with an instance contract
/// this role is the admin role for the INSTANCE_OWNER_ROLE
function INSTANCE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2600); }

function REGISTRY_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(1800); }

/// @dev instance specific role for instance service
function INSTANCE_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2000); }

/// @dev role for creating gif target on instance service
function CAN_CREATE_GIF_TARGET__ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(1700); }

/// @dev role for registering gif components
function COMPONENT_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2001); }

/// @dev instance specific role for distribution service
function DISTRIBUTION_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2100); }

/// @dev instance specific role for oracle service
function ORACLE_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2150); }

/// @dev instance specific role for pool service
function POOL_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2200); }

/// @dev instance specific role for product service
function PRODUCT_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2300); }

/// @dev instance specific role for application service
function APPLICATION_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2400); }

/// @dev instance specific role for policy service
function POLICY_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2410); }

/// @dev instance specific role for claim service
function CLAIM_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2420); }

/// @dev instance specific role for bundle service
function BUNDLE_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2500); }

/// @dev instance specific role for pricing service
function PRICING_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2800); }

/// @dev instance specific role for staking service
function STAKING_SERVICE_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2900); }

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

    /// @dev Converts an uint into a RoleId.
    /// Used for GIF core contracts.
    function roleForType(ObjectType objectType) public pure returns (RoleId) {
        return RoleId.wrap(100 * uint64(objectType.toInt()));
    }

    /// @dev Converts an uint into a RoleId.
    /// Used for GIF core contracts.
    function roleForTypeAndVersion(ObjectType objectType, uint8 majorVersion) public pure returns (RoleId) {
        return RoleId.wrap(
            100 * uint64(objectType.toInt()) + majorVersion);
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
