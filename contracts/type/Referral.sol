// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {NftId} from "./NftId.sol";
import {REFERRAL} from "./ObjectType.sol";

type ReferralId is bytes8;
type ReferralStatus is uint8;

// type bindings
using {
    eqReferralId as ==, 
    neReferralId as !=,
    ReferralLib.toKey32
} for ReferralId global;

using {
    eqReferralStatus as ==, 
    neReferralStatus as !=
} for ReferralStatus global;

// general pure free functions

// @dev Returns true iff a and b are identical
function eqReferralId(ReferralId a, ReferralId b) pure returns (bool isSame) {
    return ReferralId.unwrap(a) == ReferralId.unwrap(b);
}

// @dev Returns true iff a and b are different
function neReferralId(ReferralId a, ReferralId b) pure returns (bool isDifferent) {
    return ReferralId.unwrap(a) != ReferralId.unwrap(b);
}

// @dev Returns true iff a and b are identical
function eqReferralStatus(ReferralStatus a, ReferralStatus b) pure returns (bool isSame) {
    return ReferralStatus.unwrap(a) == ReferralStatus.unwrap(b);
}

// @dev Returns true iff a and b are different
function neReferralStatus(ReferralStatus a, ReferralStatus b) pure returns (bool isDifferent) {
    return ReferralStatus.unwrap(a) != ReferralStatus.unwrap(b);
}

function REFERRAL_OK() pure returns (ReferralStatus) {
    return ReferralStatus.wrap(10);
}

function REFERRAL_ERROR_UNKNOWN() pure returns (ReferralStatus) {
    return ReferralStatus.wrap(100);
}

function REFERRAL_ERROR_EXPIRED() pure returns (ReferralStatus) {
    return ReferralStatus.wrap(110);
}

function REFERRAL_ERROR_EXHAUSTED() pure returns (ReferralStatus) {
    return ReferralStatus.wrap(120);
}

library ReferralLib {

    function zero() public pure returns (ReferralId) {
        return ReferralId.wrap(bytes8(0));
    }

    // @dev Converts a referral string into an id.
    function toReferralId(NftId distributionNftId, string memory referral) public pure returns (ReferralId) {
        return ReferralId.wrap(bytes8(keccak256(abi.encode(distributionNftId, referral))));
    }

    function toReferralStatus(uint8 status) public pure returns (ReferralStatus) {
        return ReferralStatus.wrap(status);
    }

    /// @dev Returns the key32 value for the specified nft id and object type.
    function toKey32(ReferralId id) public pure returns (Key32 key) {
        return Key32Lib.toKey32(REFERRAL(), toKeyId(id));
    }

    /// @dev Returns the key id value for the specified nft id
    function toKeyId(ReferralId id) public pure returns (KeyId keyId) {
        return KeyId.wrap(bytes31(ReferralId.unwrap(id)));
    }

    function eqz(ReferralId id) public pure returns (bool) {
        return eqReferralId(id, zero());
    }
}
