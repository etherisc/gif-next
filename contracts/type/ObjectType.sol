// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {StrLib} from "./String.sol";
import {VersionPart} from "./Version.sol";

type ObjectType is uint8;

// type bindings
using {
    eqObjectType as ==,
    neObjectType as !=,
    ObjectTypeLib.toInt,
    ObjectTypeLib.toName,
    ObjectTypeLib.eqz,
    ObjectTypeLib.eq,
    ObjectTypeLib.gtz
} for ObjectType global;


//--- GIF object types/domains (rage: 1 - 99) -------------------------------//

function PROTOCOL() pure returns (ObjectType) {
    return ObjectType.wrap(1);
}

function REGISTRY() pure returns (ObjectType) {
    return ObjectType.wrap(2);
}

function STAKING() pure returns (ObjectType) {
    return ObjectType.wrap(3);
}

function RELEASE() pure returns (ObjectType) {
    return ObjectType.wrap(6);
}

function ROLE() pure returns (ObjectType) {
    return ObjectType.wrap(7);
}

function SERVICE() pure returns (ObjectType) {
    return ObjectType.wrap(8);
}

function INSTANCE() pure returns (ObjectType) {
    return ObjectType.wrap(10);
}

/// @dev Generic component object type.
/// Component role id range is 11-19.
/// Stick to this range for new component object types.
function COMPONENT() pure returns (ObjectType) {
    return ObjectType.wrap(11);
}

/// @dev Product object type.
/// IMPORTANT the actual value has an influence on the corresponding role id (RoleIdLib.sol). 
/// Do not change this value without updating the corresponding role id calculation.
function PRODUCT() pure returns (ObjectType) {
    return ObjectType.wrap(12);
}

function ORACLE() pure returns (ObjectType) {
    return ObjectType.wrap(13);
}

function DISTRIBUTION() pure returns (ObjectType) {
    return ObjectType.wrap(14);
}

function POOL() pure returns (ObjectType) {
    return ObjectType.wrap(15);
}

/// @dev Application object type.
/// Range for NFT objects created thorugh components is 20-29.
function APPLICATION() pure returns (ObjectType) {
    return ObjectType.wrap(20);
}

function POLICY() pure returns (ObjectType) {
    return ObjectType.wrap(21);
}

function BUNDLE() pure returns (ObjectType) {
    return ObjectType.wrap(22);
}

function DISTRIBUTOR() pure returns (ObjectType) {
    return ObjectType.wrap(23);
}

/// @dev Stake object type.
/// NFT object type is 30
function STAKE() pure returns (ObjectType) {
    return ObjectType.wrap(30);
}

/// @dev Staking target object type.
function TARGET() pure returns (ObjectType) {
    return ObjectType.wrap(31);
}

/// @dev Accounting object type.
/// Range for non-NFT types created through components is 40+
function ACCOUNTING() pure returns (ObjectType) {
    return ObjectType.wrap(40);
}

function FEE() pure returns (ObjectType) {
    return ObjectType.wrap(41);
}

function PRICE() pure returns (ObjectType) {
    return ObjectType.wrap(42);
}

function PREMIUM() pure returns (ObjectType) {
    return ObjectType.wrap(43);
}

function RISK() pure returns (ObjectType) {
    return ObjectType.wrap(44);
}

function CLAIM() pure returns (ObjectType) {
    return ObjectType.wrap(45);
}

function PAYOUT() pure returns (ObjectType) {
    return ObjectType.wrap(46); 
}

function REQUEST() pure returns (ObjectType) {
    return ObjectType.wrap(47);
}

function DISTRIBUTOR_TYPE() pure returns (ObjectType) {
    return ObjectType.wrap(48);
}

function REFERRAL() pure returns (ObjectType) {
    return ObjectType.wrap(49);
}

/// @dev Object type for GIF core target roles.
function CORE() pure returns (ObjectType) {
    return ObjectType.wrap(97);
}

/// @dev Object type for target roles of contracts outside the GIF framework.
/// Example: Custom supporting contracts for a product component.
function CUSTOM() pure returns (ObjectType) {
    return ObjectType.wrap(98);
}

/// @dev Object type that includes any other object type.
/// Note that eq()/'==' does not take this property into account.
function ALL() pure returns (ObjectType) {
    return ObjectType.wrap(99);
}

// other pure free functions for operators
function eqObjectType(ObjectType a, ObjectType b) pure returns (bool isSame) {
    return ObjectType.unwrap(a) == ObjectType.unwrap(b);
}

function neObjectType(ObjectType a, ObjectType b) pure returns (bool isSame) {
    return ObjectType.unwrap(a) != ObjectType.unwrap(b);
}

// library functions that operate on user defined type
library ObjectTypeLib {

    function zero() public pure returns (ObjectType) {
        return ObjectType.wrap(0);
    }

    /// @dev Converts the uint256 into ObjectType.
    function toObjectType(uint256 objectType) public pure returns (ObjectType) {
        return ObjectType.wrap(uint8(objectType));
    }

    /// @dev Converts the NftId to a uint256.
    function toInt(ObjectType objectType) public pure returns (uint96) {
        return uint96(ObjectType.unwrap(objectType));
    }

    /// @dev Returns true if the value is non-zero (> 0).
    function gtz(ObjectType a) public pure returns (bool) {
        return ObjectType.unwrap(a) > 0;
    }

    /// @dev Returns true if the value is zero (== 0).
    function eqz(ObjectType a) public pure returns (bool) {
        return ObjectType.unwrap(a) == 0;
    }

    /// @dev Returns true if the values are equal (==).
    function eq(ObjectType a, ObjectType b) public pure returns (bool isSame) {
        return ObjectType.unwrap(a) == ObjectType.unwrap(b);
    }

    /// @dev Returns true if the values are not equal (!=).
    function ne(ObjectType a, ObjectType b) public pure returns (bool isSame) {
        return ObjectType.unwrap(a) != ObjectType.unwrap(b);
    }

    /// @dev Returns the type/domain name for the provided object type
    function toName(ObjectType objectType) public pure returns (string memory name) {
        if (objectType == REGISTRY()) {
            return "Registry";
        } else if (objectType == STAKING()) {
            return "Staking";
        } else if (objectType == RELEASE()) {
            return "Release";
        } else if (objectType == INSTANCE()) {
            return "Instance";
        } else if (objectType == COMPONENT()) {
            return "Component";
        } else if (objectType == PRODUCT()) {
            return "Product";
        } else if (objectType == ORACLE()) {
            return "Oracle";
        } else if (objectType == DISTRIBUTION()) {
            return "Distribution";
        } else if (objectType == POOL()) {
            return "Pool";
        } else if (objectType == APPLICATION()) {
            return "Application";
        } else if (objectType == POLICY()) {
            return "Policy";
        } else if (objectType == CLAIM()) {
            return "Claim";
        } else if (objectType == PRICE()) {
            return "Price";
        } else if (objectType == BUNDLE()) {
            return "Bundle";
        } else if (objectType == RISK()) {
            return "Risk";
        } else if (objectType == ACCOUNTING()) {
            return "Accounting";
        }

        // fallback: ObjectType<obect-type-int>
        return string(
            abi.encodePacked(
                "ObjectType",
                StrLib.uintToString(
                    toInt(objectType))));
    }

    // TODO move to IService
    function toVersionedName(
        string memory name, 
        string memory suffix, 
        VersionPart release
    )
        external
        pure
        returns (string memory versionedName)
    {
        string memory versionName = "V0";

        if (release.toInt() >= 10) {
            versionName = "V";
        }

        versionedName = string(
            abi.encodePacked(
                name,
                suffix,
                versionName,
                release.toString()));
    }
}