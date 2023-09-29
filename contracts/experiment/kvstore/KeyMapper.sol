// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ObjectType, BUNDLE, RISK} from "../../types/ObjectType.sol";

type KeyId is bytes31;

contract KeyMapper {

    uint8 public constant TYPE_SHIFT = 31 * 8;
    uint8 public constant ID_SHIFT = uint8(32 * 8 - TYPE_SHIFT);
    bytes32 public constant TYPE_MASK = bytes32(bytes1(type(uint8).max)); // first byte in bytes32
    bytes32 public constant ID_MASK = bytes32(~TYPE_MASK); // remaining bytes in bytes32

    struct Key {
        ObjectType objectType;
        KeyId id;
    }

    function toKey(ObjectType objectType, KeyId id) public pure returns(Key memory) {
        return Key(objectType, id);
    }

    function toKey(bytes32 key) public pure returns (Key memory) {
        ObjectType objectType = ObjectType.wrap(uint8(uint256(key & TYPE_MASK) >> TYPE_SHIFT));
        KeyId id = KeyId.wrap(bytes31((key & ID_MASK) << ID_SHIFT));
        return Key(objectType, id);
    }

    function toKey32(Key memory key) public pure returns(bytes32) {
        return toKey32(key.objectType, key.id);
    }

    function toKey32(ObjectType objectType, KeyId id) public pure returns(bytes32) {
        uint256 uintObjectType = ObjectType.unwrap(objectType);
        uint256 uintId = uint248(KeyId.unwrap(id));
        uint256 uintKey = (uintObjectType << TYPE_SHIFT) + uintId;
        return bytes32(uintKey);
    }
}