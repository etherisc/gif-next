// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// uint24 allows for 65'535 claims with 255 payouts each per policy
type PayoutId is uint24;

// type bindings
using {
    eqPayoutId as ==, 
    nePayoutId as !=, 
    PayoutIdLib.eqz,
    PayoutIdLib.gtz,
    PayoutIdLib.toInt
} for PayoutId global;


// pure free functions for operators
function eqPayoutId(PayoutId a, PayoutId b) pure returns (bool isSame) {
    return PayoutId.unwrap(a) == PayoutId.unwrap(b);
}

function nePayoutId(PayoutId a, PayoutId b) pure returns (bool isDifferent) {
    return PayoutId.unwrap(a) != PayoutId.unwrap(b);
}

// TODO come up with a way to code claim id into payout id
// eg payoutId.getClaimId(), payoutId.getPayoutNo()
// library functions that operate on user defined type
library PayoutIdLib {
    /// @dev Converts the PayoutId to a uint.
    function zero() public pure returns (PayoutId) {
        return PayoutId.wrap(0);
    }

    /// @dev Converts an uint into a PayoutId.
    function toPayoutId(uint256 a) public pure returns (PayoutId) {
        return PayoutId.wrap(uint24(a));
    }

    /// @dev Converts the PayoutId to a uint.
    function toInt(PayoutId a) public pure returns (uint24) {
        return uint24(PayoutId.unwrap(a));
    }

    /// @dev Returns true if the value is non-zero (> 0).
    function gtz(PayoutId a) public pure returns (bool) {
        return PayoutId.unwrap(a) > 0;
    }

    /// @dev Returns true if the value is zero (== 0).
    function eqz(PayoutId a) public pure returns (bool) {
        return PayoutId.unwrap(a) == 0;
    }
}
