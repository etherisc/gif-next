// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

type ObjectType is uint8;

// type bindings
using {
    eqObjectType as ==,
    neObjectType as !=,
    ObjectTypeLib.toInt,
    ObjectTypeLib.eqz,
    ObjectTypeLib.gtz
} for ObjectType global;


//--- GIF object types/domains (rage: 1 - 99) -------------------------------//

function PROTOCOL() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(1);
}

function REGISTRY() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(2);
}

function STAKING() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(3);
}

function TOKEN() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(6);
}

function RELEASE() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(7);
}

function ROLE() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(8);
}

function SERVICE() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(9);
}

function INSTANCE() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(10);
}

function COMPONENT() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(11);
}

function PRODUCT() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(12);
}

function ORACLE() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(13);
}

function DISTRIBUTION() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(14);
}

function POOL() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(15);
}

function APPLICATION() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(20);
}

function POLICY() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(21);
}

function CLAIM() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(22);
}

function PAYOUT() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(23); 
}

function RISK() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(24);
}

function PRICE() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(25);
}

function REQUEST() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(26);
}

function DISTRIBUTOR_TYPE() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(27);
}

function DISTRIBUTOR() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(28);
}

function REFERRAL() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(29);
}

function BUNDLE() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(30);
}

function TARGET() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(31);
}

function STAKE() pure returns (ObjectType) {
    return ObjectTypeLib.toObjectType(32);
}

// other pure free functions for operators
function eqObjectType(ObjectType a, ObjectType b) pure returns (bool isSame) {
    return ObjectTypeLib.eq(a, b);
}

function neObjectType(ObjectType a, ObjectType b) pure returns (bool isSame) {
    return ObjectTypeLib.ne(a, b);
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
}