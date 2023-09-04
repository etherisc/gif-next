// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// uint96 allows for chain ids up to 13 digits
type StateId is uint8;

// type bindings
using {
    eqStateId as ==,
    neStateId as !=,
    StateIdLib.toInt
} for StateId global;

// general pure free functions
/// @dev Converts the uint8 to a StateId.
function toStateId(uint256 id) pure returns(StateId) { return StateId.wrap(uint8(id)); }

/// @dev Return the StateId zero (0)
function zeroStateId() pure returns(StateId) { return StateId.wrap(0); }

// pure free functions for operators
function eqStateId(StateId a, StateId b) pure returns(bool isSame) { return StateId.unwrap(a) == StateId.unwrap(b); }
function neStateId(StateId a, StateId b) pure returns(bool isDifferent) { return StateId.unwrap(a) != StateId.unwrap(b); }

// library functions that operate on user defined type
library StateIdLib {
    /// @dev Converts the NftId to a uint256.
    function toInt(StateId stateId) public pure returns(uint96) { return uint96(StateId.unwrap(stateId)); }
    /// @dev Returns true if the value is non-zero (> 0).
    function gtz(StateId a) public pure returns(bool) { return StateId.unwrap(a) > 0; }
    /// @dev Returns true if the value is zero (== 0).
    function eqz(StateId a) public pure returns(bool) { return StateId.unwrap(a) == 0; }
    /// @dev Returns true if the values are equal (==).
    function eq(StateId a, StateId b) public pure returns(bool isSame) { return eqStateId(a, b); }
}
