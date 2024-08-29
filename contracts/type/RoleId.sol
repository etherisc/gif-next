// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {ObjectType, ROLE} from "./ObjectType.sol";
import {VersionPart, VersionPartLib} from "./Version.sol";

type RoleId is uint64;

// type bindings
using {
    eqRoleId as ==, 
    neRoleId as !=,
    RoleIdLib.toInt,
    RoleIdLib.isServiceRole,
    RoleIdLib.eqz,
    RoleIdLib.gtz
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

// TODO check if/where this is really needed
/// @dev role assigned to release registry, release specfic to lock/unlock a release
function RELEASE_REGISTRY_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(4); }

/// @dev role assigned to every instance owner
function INSTANCE_OWNER_ROLE() pure returns (RoleId) { return RoleIdLib.toRoleId(5); }  

// TODO upate role id ranges
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

    error ErrorRoleIdTooBig(uint256 roleId);

    // constant values need to match with AccessAdminLib.SERVICE_ROLE_*
    uint64 public constant SERVICE_ROLE_MIN =  1000;
    uint64 public constant SERVICE_ROLE_MAX = 99099; // 99 (max object type) * 1000 + 99

    uint64 public constant SERVICE_ROLE_FACTOR = 1000;

    /// @dev Converts the RoleId to a uint.
    function zero() public pure returns (RoleId) {
        return RoleId.wrap(0);
    }


    /// @dev Converts an uint into a role id.
    function toRoleId(uint256 a) public pure returns (RoleId) {
        if (a > type(uint64).max) {
            revert ErrorRoleIdTooBig(a);
        }

        return RoleId.wrap(uint64(a));
    }


    function isServiceRole(RoleId roleId)
        public
        pure
        returns (bool)
    {
        uint256 roleIdInt = RoleId.unwrap(roleId);
        return roleIdInt >= SERVICE_ROLE_MIN && roleIdInt <= SERVICE_ROLE_MAX;
    }


    function toGenericServiceRoleId(
        ObjectType objectType
    )
        public 
        pure 
        returns (RoleId)
    {
        return toServiceRoleId(
            objectType, 
            VersionPartLib.releaseMax());
    }


    function toServiceRoleId(
        ObjectType serviceDomain, 
        VersionPart release
    )
        public 
        pure 
        returns (RoleId serviceRoleId)
    {
        uint256 serviceRoleIdInt = 
            SERVICE_ROLE_MIN 
            + SERVICE_ROLE_FACTOR * (serviceDomain.toInt() - 1)
            + release.toInt();

        return toRoleId(serviceRoleIdInt);
    }

    /// @dev Converts the role id to a uint.
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
}
