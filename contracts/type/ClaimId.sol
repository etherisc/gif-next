// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// uint16 allows for 65'535 claims per policy
type ClaimId is uint16;

import {CLAIM} from "./ObjectType.sol";
import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {NftId} from "./NftId.sol";

// type bindings
using {
    eqClaimId as ==, 
    neClaimId as !=, 
    ClaimIdLib.eq,
    ClaimIdLib.eqz,
    ClaimIdLib.gtz,
    ClaimIdLib.toInt,
    ClaimIdLib.toKey32
} for ClaimId global;


// pure free functions for operators
function eqClaimId(ClaimId a, ClaimId b) pure returns (bool isSame) {
    return ClaimIdLib.eq(a, b);
}

function neClaimId(ClaimId a, ClaimId b) pure returns (bool isDifferent) {
    return ClaimId.unwrap(a) != ClaimId.unwrap(b);
}

// library functions that operate on user defined type
library ClaimIdLib {
    /// @dev claim id min value (0), use only for non-initialized values
    function zero() public pure returns (ClaimId) {
        return ClaimId.wrap(0);
    }
    /// @dev claim id max value (2**16-1), use only for non-initialized values
    function max() public pure returns (ClaimId) {
        return ClaimId.wrap(type(uint16).max);
    }

    /// @dev Converts an uint into a ClaimId.
    function toClaimId(uint256 a) public pure returns (ClaimId) {
        return ClaimId.wrap(uint16(a));
    }

    /// @dev Converts the ClaimId to a uint.
    function toInt(ClaimId a) public pure returns (uint16) {
        return uint16(ClaimId.unwrap(a));
    }

    /// @dev Converts the ClaimId and NftId to a Key32.
    function toKey32(ClaimId claimId, NftId policyNftId) public pure returns (Key32) {
        return Key32Lib.toKey32(CLAIM(), toKeyId(claimId, policyNftId));
    }

    /// @dev Converts the ClaimId and NftId to a Key32.
    function toKeyId(ClaimId claimId, NftId policyNftId) public pure returns (KeyId) {
        return KeyId.wrap(
            bytes31(
                bytes14(
                    uint112(
                        NftId.unwrap(policyNftId) << 16 + ClaimId.unwrap(claimId)))));
    }

    /// @dev Returns true if the value is non-zero (> 0).
    function gtz(ClaimId a) public pure returns (bool) {
        return ClaimId.unwrap(a) > 0;
    }

    function eq(ClaimId a, ClaimId b) public pure returns (bool) {
        return ClaimId.unwrap(a) == ClaimId.unwrap(b);
    }

    /// @dev Returns true if the value is zero (== 0).
    function eqz(ClaimId a) public pure returns (bool) {
        return ClaimId.unwrap(a) == 0;
    }
}
