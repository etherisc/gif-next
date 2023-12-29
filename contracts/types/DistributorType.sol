// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {NftId} from "./NftId.sol";
import {DISTRIBUTION_TYPE} from "./ObjectType.sol";

type DistributorType is bytes8;

// type bindings
using {
    eqDistributorType as ==,
    neDistributorType as !=,
    DistributorTypeLib.toKey32
} for DistributorType global;

// general pure free functions

// pure free functions for operators
function eqDistributorType(
    DistributorType a, 
    DistributorType b
) pure returns (bool isSame) {
    return DistributorType.unwrap(a) == DistributorType.unwrap(b);
}

function neDistributorType(
    DistributorType a,
    DistributorType b
) pure returns (bool isDifferent) {
    return DistributorType.unwrap(a) != DistributorType.unwrap(b);
}

// library functions that operate on user defined type
library DistributorTypeLib {

    function zero() public pure returns (DistributorType) {
        return DistributorType.wrap(bytes8(0));
    }

    // @dev Converts a referral string into an id.
    function toDistributorType(NftId distributionNftId, string memory name) public pure returns (DistributorType) {
        return DistributorType.wrap(bytes8(keccak256(abi.encode(distributionNftId, name))));
    }

    /// @dev Returns the key32 value for the specified nft id and object type.
    function toKey32(DistributorType id) public pure returns (Key32 key) {
        return Key32Lib.toKey32(DISTRIBUTION_TYPE(), toKeyId(id));
    }

    /// @dev Returns the key id value for the specified nft id
    function toKeyId(DistributorType id) public pure returns (KeyId keyId) {
        return KeyId.wrap(bytes31(DistributorType.unwrap(id)));
    }
}
