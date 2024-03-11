// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// uint16 allows for 65'535 claims per policy
type ClaimId is uint16;

// type bindings
using {
    eqClaimId as ==, 
    neClaimId as !=, 
    ClaimIdLib.eqz,
    ClaimIdLib.gtz,
    ClaimIdLib.toInt
} for ClaimId global;


// pure free functions for operators
function eqClaimId(ClaimId a, ClaimId b) pure returns (bool isSame) {
    return ClaimId.unwrap(a) == ClaimId.unwrap(b);
}

function neClaimId(ClaimId a, ClaimId b) pure returns (bool isDifferent) {
    return ClaimId.unwrap(a) != ClaimId.unwrap(b);
}

// library functions that operate on user defined type
library ClaimIdLib {
    /// @dev Converts the ClaimId to a uint.
    function zero() public pure returns (ClaimId) {
        return ClaimId.wrap(0);
    }

    /// @dev Converts an uint into a ClaimId.
    function toClaimId(uint256 a) public pure returns (ClaimId) {
        return ClaimId.wrap(uint16(a));
    }

    /// @dev Converts the ClaimId to a uint.
    function toInt(ClaimId a) public pure returns (uint16) {
        return uint16(ClaimId.unwrap(a));
    }

    /// @dev Returns true if the value is non-zero (> 0).
    function gtz(ClaimId a) public pure returns (bool) {
        return ClaimId.unwrap(a) > 0;
    }

    /// @dev Returns true if the value is zero (== 0).
    function eqz(ClaimId a) public pure returns (bool) {
        return ClaimId.unwrap(a) == 0;
    }
}
