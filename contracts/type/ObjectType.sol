// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

type ObjectType is uint8;

// type bindings
using {
    eqObjectType as ==,
    neObjectType as !=,
    ObjectTypeLib.toInt,
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

function COMPONENT() pure returns (ObjectType) {
    return ObjectType.wrap(11);
}

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

function APPLICATION() pure returns (ObjectType) {
    return ObjectType.wrap(20);
}

function POLICY() pure returns (ObjectType) {
    return ObjectType.wrap(21);
}

function PREMIUM() pure returns (ObjectType) {
    return ObjectType.wrap(22);
}

function CLAIM() pure returns (ObjectType) {
    return ObjectType.wrap(23);
}

function PAYOUT() pure returns (ObjectType) {
    return ObjectType.wrap(24); 
}

function RISK() pure returns (ObjectType) {
    return ObjectType.wrap(25);
}

function PRICE() pure returns (ObjectType) {
    return ObjectType.wrap(26);
}

function REQUEST() pure returns (ObjectType) {
    return ObjectType.wrap(27);
}

function DISTRIBUTOR_TYPE() pure returns (ObjectType) {
    return ObjectType.wrap(28);
}

function DISTRIBUTOR() pure returns (ObjectType) {
    return ObjectType.wrap(29);
}

function REFERRAL() pure returns (ObjectType) {
    return ObjectType.wrap(30);
}

function BUNDLE() pure returns (ObjectType) {
    return ObjectType.wrap(31);
}

function TARGET() pure returns (ObjectType) {
    return ObjectType.wrap(32);
}

function STAKE() pure returns (ObjectType) {
    return ObjectType.wrap(33);
}

// TODO: change id for accounting
function ACCOUNTING() pure returns (ObjectType) {
    return ObjectType.wrap(34);
}

function FEE() pure returns (ObjectType) {
    return ObjectType.wrap(35);
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

    error ErrorVersionTooBig(uint256 version);

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
                toString(
                    toInt(objectType))));
    }

    function toVersionedName(
        string memory name, 
        string memory suffix, 
        uint256 version
    )
        external
        pure
        returns (string memory versionedName)
    {
        if (version > maxNumReleases()) {
            revert ErrorVersionTooBig(version);
        }

        string memory versionName = "_v0";

        if (version >= 10) {
            versionName = "_v";
        }

        versionedName = string(
            abi.encodePacked(
                name,
                suffix,
                versionName,
                toString(version)));
    }

    /// @dev returns the max number of releases (major versions) this gif setup can handle.
    function maxNumReleases() public pure returns (uint8) {
        return 99;
    }

    /// @dev returns the provied int as a string
    function toString(uint256 value) public pure returns (string memory name) {

        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits = 0;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        uint index = digits - 1;

        temp = value;
        while (temp != 0) {
            buffer[index] = bytes1(uint8(48 + temp % 10));
            temp /= 10;

            if (index > 0) {
                index--;
            }
        }

        return string(buffer);
    }
}