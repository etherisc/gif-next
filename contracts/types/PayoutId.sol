// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// uint24 allows for 65'535 claims with 255 payouts each per policy
type PayoutId is uint24;

import {ClaimId} from "./ClaimId.sol";
import {PAYOUT} from "./ObjectType.sol";
import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {NftId} from "./NftId.sol";

// type bindings
using {
    eqPayoutId as ==, 
    nePayoutId as !=, 
    PayoutIdLib.eqz,
    PayoutIdLib.gtz,
    PayoutIdLib.toInt,
    PayoutIdLib.toClaimId,
    PayoutIdLib.toPayoutNo,
    PayoutIdLib.toKey32
} for PayoutId global;


// pure free functions for operators
function eqPayoutId(PayoutId a, PayoutId b) pure returns (bool isSame) {
    return PayoutId.unwrap(a) == PayoutId.unwrap(b);
}

function nePayoutId(PayoutId a, PayoutId b) pure returns (bool isDifferent) {
    return PayoutId.unwrap(a) != PayoutId.unwrap(b);
}

// library functions that operate on user defined type
library PayoutIdLib {
    /// @dev Converts the PayoutId to a uint.
    function zero() public pure returns (PayoutId) {
        return PayoutId.wrap(0);
    }

    /// @dev Converts an uint into a PayoutId.
    function toPayoutId(ClaimId claimId, uint8 payoutNo) public pure returns (PayoutId) {
        return PayoutId.wrap((ClaimId.unwrap(claimId) << 8) + payoutNo);
    }

    function toClaimId(PayoutId payoutId) public pure returns (ClaimId) {
        return ClaimId.wrap(uint16(PayoutId.unwrap(payoutId) >> 8));
    }

    function toPayoutNo(PayoutId payoutId) public pure returns (uint8) {
        return uint8(PayoutId.unwrap(payoutId) & 255);
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

    /// @dev Converts the PayoutId and NftId to a Key32.
    function toKey32(PayoutId payoutId, NftId policyNftId) public pure returns (Key32) {
        return Key32Lib.toKey32(PAYOUT(), toKeyId(payoutId, policyNftId));
    }

    /// @dev Converts the PayoutId and NftId to a Key32.
    function toKeyId(PayoutId payoutId, NftId policyNftId) public pure returns (KeyId) {
        return KeyId.wrap(
            bytes31(
                bytes15(
                    uint120(
                        (NftId.unwrap(policyNftId) << 24) + PayoutId.unwrap(payoutId)))));
    }
}
