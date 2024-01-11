// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// uint32 allows for 4'294'967'296 individual items
type NumberId is uint32;

// type bindings
using {
    eqNumberId as ==, 
    neNumberId as !=, 
    NumberIdLib.eqz,
    NumberIdLib.gtz,
    NumberIdLib.toInt
} for NumberId global;


// pure free functions for operators
function eqNumberId(NumberId a, NumberId b) pure returns (bool isSame) {
    return NumberId.unwrap(a) == NumberId.unwrap(b);
}

function neNumberId(NumberId a, NumberId b) pure returns (bool isDifferent) {
    return NumberId.unwrap(a) != NumberId.unwrap(b);
}

// library functions that operate on user defined type
library NumberIdLib {
    /// @dev Converts the NumberId to a uint.
    function zero() public pure returns (NumberId) {
        return NumberId.wrap(0);
    }

    /// @dev Converts an uint into a NumberId.
    function toNumberId(uint256 a) public pure returns (NumberId) {
        return NumberId.wrap(uint32(a));
    }

    /// @dev Converts the NumberId to a uint.
    function toInt(NumberId a) public pure returns (uint32) {
        return uint32(NumberId.unwrap(a));
    }

    /// @dev Returns true if the value is non-zero (> 0).
    function gtz(NumberId a) public pure returns (bool) {
        return NumberId.unwrap(a) > 0;
    }

    /// @dev Returns true if the value is zero (== 0).
    function eqz(NumberId a) public pure returns (bool) {
        return NumberId.unwrap(a) == 0;
    }
}
