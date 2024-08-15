// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Key32} from "../type/Key32.sol";

// based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableSet.sol
library LibKey32Set {

    struct Set {
        Key32[] keys;
        mapping(Key32 key => uint256 index) at;
    }

    error ErrorKey32SetAlreadyAdded(Key32 key);
    error ErrorKey32SetNotInSet(Key32 key);


    function add(Set storage set, Key32 key) external {
        if (set.at[key] > 0) {
            revert ErrorKey32SetAlreadyAdded(key);
        }

        set.keys.push(key);
        set.at[key] = set.keys.length;
    }

    function remove(Set storage set, Key32 key) external {
        uint256 nftIdIndex = set.at[key];

        if (nftIdIndex == 0) {
            revert ErrorKey32SetNotInSet(key);
        }

        uint256 toDeleteIndex = nftIdIndex - 1;
        uint256 lastIndex = set.keys.length - 1;

        if (lastIndex != toDeleteIndex) {
            Key32 lastId = set.keys[lastIndex];
            set.keys[toDeleteIndex] = lastId;
            set.at[lastId] = nftIdIndex; // Replace lastValue's index to valueIndex
        }

        set.keys.pop();
        delete set.at[key];
    }

    function isEmpty(Set storage set) external view returns(bool empty) {
        return set.keys.length == 0;
    }

    function contains(Set storage set, Key32 key) external view returns(bool inSet) {
        return set.at[key] > 0;
    }

    function size(Set storage set) external view returns(uint256 length) {
        return set.keys.length;
    }

    function getElementAt(Set storage set, uint256 index) external view returns(Key32 key) {
        return set.keys[index];
    }
}
