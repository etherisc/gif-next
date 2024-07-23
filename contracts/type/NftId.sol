// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {ObjectType} from "./ObjectType.sol";

// uint96 allows for chain ids up to 13 digits
type NftId is uint96;

// type bindings
using {
    eqNftId as ==, 
    neNftId as !=, 
    NftIdLib.toInt,
    NftIdLib.gtz,
    NftIdLib.eqz,
    NftIdLib.eq,
    NftIdLib.toKeyId,
    NftIdLib.toKey32
} for NftId global;

// pure free functions for operators
function eqNftId(NftId a, NftId b) pure returns (bool isSame) {
    return NftIdLib.eq(a, b);
}

function neNftId(NftId a, NftId b) pure returns (bool isDifferent) {
    return NftIdLib.ne(a, b);
}

// library functions that operate on user defined type
library NftIdLib {

    /// @dev the zero nft id
    /// is never a valid nft id and implies a non-initialized value
    function zero() public pure returns (NftId) {
        return NftId.wrap(0);
    }

    /// @dev Converts the uint256 to a NftId.
    function toNftId(uint256 id) public pure returns (NftId) {
        return NftId.wrap(uint96(id));
    }

    /// @dev Converts the NftId to a uint256.
    function toInt(NftId nftId) public pure returns (uint96) {
        return uint96(NftId.unwrap(nftId));
    }

    /// @dev Returns true if the value is non-zero (> 0).
    function gtz(NftId a) public pure returns (bool) {
        return NftId.unwrap(a) > 0;
    }

    /// @dev Returns true if the value is zero (== 0).
    function eqz(NftId a) public pure returns (bool) {
        return NftId.unwrap(a) == 0;
    }

    /// @dev Returns true if the values are equal (==).
    function eq(NftId a, NftId b) public pure returns (bool isSame) {
        return NftId.unwrap(a) == NftId.unwrap(b);
    }

    /// @dev Returns true if the values are not equal (!=).
    function ne(NftId a, NftId b) public pure returns (bool isSame) {
        return NftId.unwrap(a) != NftId.unwrap(b);
    }

    /// @dev Returns the key32 value for the specified nft id and object type.
    function toKey32(NftId id, ObjectType objectType) public pure returns (Key32 key) {
        return Key32Lib.toKey32(objectType, toKeyId(id));
    }

    /// @dev Returns the key id value for the specified nft id
    function toKeyId(NftId id) public pure returns (KeyId keyId) {
        return KeyId.wrap(bytes31(uint248(NftId.unwrap(id))));
    }
}
