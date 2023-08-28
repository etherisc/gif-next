// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/*
# chisel session for user defined types

import {TypeA, toTypeA} from "./contracts/experiment/types/TypeA.sol";
TypeA a = toTypeA(1);
TypeA b = toTypeA(2);
uint(a.toInt())
uint(b.toInt())
a == b
a != b

import {TypeB, toTypeB} from "./contracts/experiment/types/TypeB.sol";
TypeB x = toTypeB(33);
uint(x.toInt())
a == x; // -> error
a.toInt() == x.toInt() // -> no error
 */

// bytes5 allows for chain ids up to 13 digits
type TypeA is uint248;

// type bindings
using {
    eqTypeA as ==,
    neTypeA as !=,
    TypeALib.toInt
} for TypeA global;

// general pure free functions
function toTypeA(uint256 typeA) pure returns(TypeA) { return TypeA.wrap(uint248(typeA)); }

// pure free functions for operators
function eqTypeA(TypeA a, TypeA b) pure returns(bool isSame) { return TypeA.unwrap(a) == TypeA.unwrap(b); }
function neTypeA(TypeA a, TypeA b) pure returns(bool isDifferent) { return TypeA.unwrap(a) != TypeA.unwrap(b); }

// library functions that operate on user defined type
library TypeALib {
    function toInt(TypeA typeA) internal pure returns(uint256) { return uint256(TypeA.unwrap(typeA)); }
}
