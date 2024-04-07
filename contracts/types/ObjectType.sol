// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

type ObjectType is uint8;

// type bindings
using {
    eqObjectType as ==,
    neObjectType as !=,
    ObjectTypeLib.toInt,
    ObjectTypeLib.gtz
} for ObjectType global;

// general pure free functions

function PROTOCOL() pure returns (ObjectType) {
    return toObjectType(10);
}

function ROLE() pure returns (ObjectType) {
    return toObjectType(20);
}

function TARGET() pure returns (ObjectType) {
    return toObjectType(30);
}

function REGISTRY() pure returns (ObjectType) {
    return toObjectType(40);
}

function TOKEN() pure returns (ObjectType) {
    return toObjectType(50);
}

function SERVICE() pure returns (ObjectType) {
    return toObjectType(60);
}

function INSTANCE() pure returns (ObjectType) {
    return toObjectType(70);
}

function STAKE() pure returns (ObjectType) {
    return toObjectType(80);
}

function COMPONENT() pure returns (ObjectType) {
    return toObjectType(100);
}

// TODO replace by PRODUCT_SETUP
function TREASURY() pure returns (ObjectType) {
    return toObjectType(101);
}

function PRODUCT_SETUP() pure returns (ObjectType) {
    return toObjectType(101);
}

function PRODUCT() pure returns (ObjectType) {
    return toObjectType(110);
}

function DISTRIBUTION() pure returns (ObjectType) {
    return toObjectType(120);
}

function DISTRIBUTOR_TYPE() pure returns (ObjectType) {
    return toObjectType(121);
}

function DISTRIBUTOR() pure returns (ObjectType) {
    return toObjectType(122);
}

function REFERRAL() pure returns (ObjectType) {
    return toObjectType(123);
}

function ORACLE() pure returns (ObjectType) {
    return toObjectType(130);
}

function POOL() pure returns (ObjectType) {
    return toObjectType(140);
}

function BUNDLE() pure returns (ObjectType) {
    return toObjectType(220);
}

function RISK() pure returns (ObjectType) {
    return toObjectType(200);
}

function APPLICATION() pure returns (ObjectType) {
    return toObjectType(210);
}

function POLICY() pure returns (ObjectType) {
    return toObjectType(211);
}

function CLAIM() pure returns (ObjectType) {
    return toObjectType(212);
}

function PAYOUT() pure returns (ObjectType) {
    return toObjectType(213); 
}

function PRICE() pure returns (ObjectType) {
    return toObjectType(230);
}

/// @dev Converts the uint8 to a ObjectType.
function toObjectType(uint256 objectType) pure returns (ObjectType) {
    return ObjectType.wrap(uint8(objectType));
}

// TODO move to ObjecTypeLib and rename to zero()
/// @dev Return the ObjectType zero (0)
function zeroObjectType() pure returns (ObjectType) {
    return ObjectType.wrap(0);
}

// pure free functions for operators
function eqObjectType(ObjectType a, ObjectType b) pure returns (bool isSame) {
    return ObjectType.unwrap(a) == ObjectType.unwrap(b);
}

function neObjectType(
    ObjectType a,
    ObjectType b
) pure returns (bool isDifferent) {
    return ObjectType.unwrap(a) != ObjectType.unwrap(b);
}

// library functions that operate on user defined type
library ObjectTypeLib {
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
        return eqObjectType(a, b);
    }
}
