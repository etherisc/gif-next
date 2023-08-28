// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// bytes5 allows for chain ids up to 13 digits
type TypeB is uint248;

// type bindings
using {
    eqTypeB as ==,
    addTypeB as +,
    TypeBLib.toInt
} for TypeB global;

// general pure free functions
function toTypeB(uint256 x) pure returns(TypeB) { return TypeB.wrap(uint248(x)); }

// pure free functions for operators
function eqTypeB(TypeB a, TypeB b) pure returns(bool isSame) { return TypeB.unwrap(a) == TypeB.unwrap(b); }
function addTypeB(TypeB a, TypeB b) pure returns(TypeB sum) { return TypeB.wrap(TypeB.unwrap(a) + TypeB.unwrap(b)); }

// library functions that operate on user defined type
library TypeBLib {
    function toInt(TypeB b) internal pure returns(uint256) { return uint256(TypeB.unwrap(b)); }
}
