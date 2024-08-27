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
    RoleIdLib.toInt,
    RoleIdLib.eqz,
    RoleIdLib.gtz,
    RoleIdLib.isComponentRole,
    RoleIdLib.isCustomRole
    // RoleIdLib.toKey32
} for RoleId global;

// general pure free functions

// @dev Returns true iff role ids a and b are identical
function eqRoleId(RoleId a, RoleId b) pure returns (bool isSame) {
    return RoleId.unwrap(a) == RoleId.unwrap(b);
}

// @dev Returns true iff role ids a and b are different
function neRoleId(RoleId a, RoleId b) pure returns (bool isDifferent) {
    return RoleId.unwrap(a) != RoleId.unwrap(b);
}

//--- OpenZeppelin provided roles -------------------------------------------//

/// @dev Role ID needs to match with oz AccessManager.ADMIN_ROLE
function ADMIN_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(type(uint64).min); }

/// @dev Role ID needs to match with oz AccessManager.PUBLIC_ROLE
function PUBLIC_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(type(uint64).max); }

//--- GIF roles (range: 1-99) ----------------------------------------------//

/// @dev cental role for gif release management.
/// this role is necessary to call ReleaseManager.createNextRelease/activateNextRelease
/// the actual deployment of a release requires the GIF_MANAGER_ROLE.
/// GIF_ADMIN_ROLE is the admin of the GIF_MANAGER_ROLE.
/// only a single holder may hold this role at any time
function GIF_ADMIN_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(1); } 

/// @dev role for token whith/blacklisting, deploying and registering the services for a new major release
/// registering services for a new major release is only possible after a new initial release has been created by the GIF_ADMIN_ROLE
/// token white/blacklisting is possible for any active release
function GIF_MANAGER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(2); } 

/// @dev role for registering remote staking targets and reporting remote total value locked amounts.
function GIF_REMOTE_MANAGER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(3); } 

/// @dev role assigned to release registry, release specfic to lock/unlock a release
function RELEASE_REGISTRY_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(4); }

/// @dev role assigned to every instance owner
function INSTANCE_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(5); }  

//--- GIF core contract roles (range: 200 - 9'900) --------------------------//
// created and assigned during initial deployment for registry and staking
// granting for instances and components in instance service
// object type * 100 + 0, examples:
// - registry contract role: 200 
// - staking contract role: 300 
// - instance contract role: 1000

//--- GIF service roles (range 201 - 9'9xx) ---------------------------------//
// created and assigned by release manager contract
// object type * 100 + 1/major version, examples:
// - registry service role (any version): 299
// - registry service role (version 3): 203
// - registry service role (any version): 399
// - staking service role: (version 3): 303
// - application service role (version 3): 2003

//--- GIF component contract roles (range 12'001 - 19'099) ------------------//
// the min value of 12'001 is based on the following calculation:
// object type * 1000 + 1 where the lowest object type is 12 (product) 
// assigned at component registration time
// object type * 1000 + instane specific component counter
// on any instance a maximum number of 999 components may be deployed
// examples:
// - 1st pool on instance: 15001
// - 1st distribution on instance: 14002
// - 1st product on instance: 12003
// - 2nd pool on instance: 15004
// - 2nd distribution on instance: 14005
// - 2nd product on instance: 12006


//--- Custom roles (range >= 1'000'000) -------------------------------------//

function CUSTOM_ROLE_MIN() pure returns (RoleId) { return RoleIdLib.toRoleId(1000000); }

library RoleIdLib {

    uint64 public constant ALL_VERSIONS = 99;
    uint64 public constant SERVICE_DOMAIN_ROLE_FACTOR = 100;
    uint64 public constant COMPONENT_ROLE_FACTOR = 1000;
    uint64 public constant COMPONENT_ROLE_MIN_INT = 12000;
    uint64 public constant COMPONENT_ROLE_MAX_INT = 19000;
    uint64 public constant CUSTOM_ROLE_MIN_INT = 1000000;

    /// @dev Converts the RoleId to a uint.
    function zero() public pure returns (RoleId) {
        return RoleId.wrap(0);
    }

    /// @dev Converts an uint into a role id.
    function toRoleId(uint64 a) public pure returns (RoleId) {
        return RoleId.wrap(a);
    }

    /// @dev Converts an uint into a component role id.
    function toComponentRoleId(ObjectType objectType, uint64 index) public pure returns (RoleId) {
        return toRoleId(COMPONENT_ROLE_FACTOR * uint64(objectType.toInt()) + index);
    }

    /// @dev Converts an uint into a custom role id.
    function toCustomRoleId(uint64 index) public pure returns (RoleId) {
        return toRoleId(CUSTOM_ROLE_MIN_INT + index);
    }

    /// @dev Converts the role id to a uint.
    function toInt(RoleId a) public pure returns (uint64) {
        return uint64(RoleId.unwrap(a));
    }

    /// @dev Converts an uint into a role id.
    /// Used for GIF core contracts.
    function roleForType(ObjectType objectType) public pure returns (RoleId) {
        return RoleId.wrap(SERVICE_DOMAIN_ROLE_FACTOR * uint64(objectType.toInt()));
    }

    /// @dev Converts an uint into a RoleId.
    /// Used for GIF core contracts.
    function roleForTypeAndVersion(ObjectType objectType, VersionPart majorVersion) public pure returns (RoleId) {
        return RoleId.wrap(
            uint64(SERVICE_DOMAIN_ROLE_FACTOR * objectType.toInt() + majorVersion.toInt()));
    }

    /// @dev Converts an uint into a RoleId.
    /// Used for GIF core contracts.
    function roleForTypeAndAllVersions(ObjectType objectType) public pure returns (RoleId) {
        return RoleId.wrap(
            uint64(SERVICE_DOMAIN_ROLE_FACTOR * objectType.toInt() + ALL_VERSIONS));
    }

    /// @dev Returns true if the value is non-zero (> 0).
    function gtz(RoleId a) public pure returns (bool) {
        return RoleId.unwrap(a) > 0;
    }

    /// @dev Returns true if the value is zero (== 0).
    function eqz(RoleId a) public pure returns (bool) {
        return RoleId.unwrap(a) == 0;
    }

    /// @dev Returns true iff the role id is a component role.
    function isComponentRole(RoleId roleId) public pure returns (bool) {
        uint64 roleIdInt = RoleId.unwrap(roleId);
        return roleIdInt >= COMPONENT_ROLE_MIN_INT && roleIdInt <= COMPONENT_ROLE_MAX_INT;
    }

    /// @dev Returns true iff the role id is a custom role.
    function isCustomRole(RoleId roleId) public pure returns (bool) {
        return RoleId.unwrap(roleId) >= CUSTOM_ROLE_MIN_INT;
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
