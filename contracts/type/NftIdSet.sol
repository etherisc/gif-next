// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../type/NftId.sol";

// based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableSet.sol
library LibNftIdSet {

    struct Set {
        NftId[] ids;
        mapping(NftId nftid => uint256 index) at;
    }

    error ErrorNftIdSetAlreadyAdded(NftId nftId);
    error ErrorNftIdSetNotInSet(NftId nftId);


    function add(Set storage set, NftId nftId) external {
        if (set.at[nftId] > 0) {
            revert ErrorNftIdSetAlreadyAdded(nftId);
        }

        set.ids.push(nftId);
        set.at[nftId] = set.ids.length;
    }

    function remove(Set storage set, NftId nftId) external {
        uint256 nftIdIndex = set.at[nftId];

        if (nftIdIndex == 0) {
            revert ErrorNftIdSetNotInSet(nftId);
        }

        uint256 toDeleteIndex = nftIdIndex - 1;
        uint256 lastIndex = set.ids.length - 1;

        if (lastIndex != toDeleteIndex) {
            NftId lastId = set.ids[lastIndex];
            set.ids[toDeleteIndex] = lastId;
            set.at[lastId] = nftIdIndex; // Replace lastValue's index to valueIndex
        }

        set.ids.pop();
        delete set.at[nftId];
    }

    function isEmpty(Set storage set) external view returns(bool empty) {
        return set.ids.length == 0;
    }

    function contains(Set storage set, NftId nftId) external view returns(bool inSet) {
        return set.at[nftId] > 0;
    }

    function size(Set storage set) external view returns(uint256 length) {
        return set.ids.length;
    }

    function getElementAt(Set storage set, uint256 index) external view returns(NftId nftId) {
        return set.ids[index];
    }
}
