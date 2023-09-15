// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../types/NftId.sol";

// based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableSet.sol
library LibNftIdSet {

    struct Set {
        NftId[] ids;
        mapping(NftId nftid => uint256 index) at;
    }

    function add(Set storage set, NftId nftId) external returns(bool added) {
        if (set.at[nftId] == 0) {
            set.ids.push(nftId);
            set.at[nftId] = set.ids.length;
            return true;
        } else {
            return false;
        }
    }

    function remove(Set storage set, NftId nftId) external returns(bool removed) {
        uint256 nftIdIndex = set.at[nftId];

        if (nftIdIndex > 0) {
            uint256 toDeleteIndex = nftIdIndex - 1;
            uint256 lastIndex = set.ids.length - 1;

            if (lastIndex != toDeleteIndex) {
                NftId lastId = set.ids[lastIndex];
                set.ids[toDeleteIndex] = lastId;
                set.at[lastId] = nftIdIndex; // Replace lastValue's index to valueIndex
            }

            set.ids.pop();
            delete set.at[nftId];
            return true;
        } else {
            return false;
        }
    }

    function isEmpty(Set storage set) external view returns(bool empty) {
        return set.ids.length == 0;
    }

    function contains(Set storage set, NftId nftId) external view returns(bool inSet) {
        return set.at[nftId] > 0;
    }

    function getLength(Set storage set) external view returns(uint256 length) {
        return set.ids.length;
    }

    function getElementAt(Set storage set, uint256 index) external view returns(NftId nftId) {
        return set.ids[index];
    }
}
