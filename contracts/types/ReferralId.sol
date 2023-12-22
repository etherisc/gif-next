// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {REFERRAL} from "./ObjectType.sol";

type ReferralId is bytes8;

// type bindings
using {
    eqReferralId as ==, 
    neReferralId as !=,
    ReferralIdLib.toKey32
} for ReferralId global;

// general pure free functions

// @dev Returns true iff risk ids a and b are identical
function eqReferralId(ReferralId a, ReferralId b) pure returns (bool isSame) {
    return ReferralId.unwrap(a) == ReferralId.unwrap(b);
}

// @dev Returns true iff risk ids a and b are different
function neReferralId(ReferralId a, ReferralId b) pure returns (bool isDifferent) {
    return ReferralId.unwrap(a) != ReferralId.unwrap(b);
}

library ReferralIdLib {

    function zeroReferralId() public pure returns (ReferralId) {
        return ReferralId.wrap(bytes8(0));
    }

    // @dev Converts a role string into a role id.
    function toReferralId(string memory referral) public pure returns (ReferralId) {
        return ReferralId.wrap(bytes8(keccak256(abi.encode(referral))));
    }

    /// @dev Returns the key32 value for the specified id
    function toKey32(ReferralId id) public pure returns (Key32 key) {
        return Key32Lib.toKey32(REFERRAL(), toKeyId(id));
    }

    /// @dev Returns the key id value for the specified id
    function toKeyId(ReferralId id) public pure returns (KeyId keyId) {
        return KeyId.wrap(bytes31(ReferralId.unwrap(id)));
    }
}
