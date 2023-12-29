// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ObjectType} from "./ObjectType.sol";

type Key32 is bytes32;
type KeyId is bytes31;

// type bindings
using {
    eqKey32 as ==, 
    neKey32 as !=,
    Key32Lib.toKeyId,
    Key32Lib.toObjectType
} for Key32 global;

// @dev Returns true iff keys are identical
function eqKey32(Key32 a, Key32 b) pure returns (bool isSame) {
    return Key32.unwrap(a) == Key32.unwrap(b);
}

// @dev Returns true iff keys are different
function neKey32(Key32 a, Key32 b) pure returns (bool isDifferent) {
    return Key32.unwrap(a) != Key32.unwrap(b);
}

library Key32Lib {

    uint8 public constant TYPE_SHIFT = 31 * 8;
    uint8 public constant ID_SHIFT = uint8(32 * 8 - TYPE_SHIFT);
    bytes32 public constant TYPE_MASK = bytes32(bytes1(type(uint8).max)); // first byte in bytes32
    bytes32 public constant ID_MASK = bytes32(~TYPE_MASK); // remaining bytes in bytes32

    function toKey32(ObjectType objectType, KeyId id) public pure returns (Key32) {
        uint256 uintObjectType = ObjectType.unwrap(objectType);
        uint256 uintId = uint248(KeyId.unwrap(id));
        uint256 uintKey = (uintObjectType << TYPE_SHIFT) + uintId;
        return Key32.wrap(bytes32(uintKey));
    }

    function toObjectType(Key32 key) public pure returns (ObjectType objectType) {
        bytes32 key32 = Key32.unwrap(key);
        objectType = ObjectType.wrap(uint8(uint256(key32 & TYPE_MASK) >> TYPE_SHIFT));
    }

    function toKeyId(Key32 key) public pure returns (KeyId id) {
        bytes32 key32 = Key32.unwrap(key);
        id = KeyId.wrap(bytes31((key32 & ID_MASK) << ID_SHIFT));
    }
}
