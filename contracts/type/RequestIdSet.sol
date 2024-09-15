// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {RequestId} from "../type/RequestId.sol";

// based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableSet.sol
library RequestIdSet {

    struct Set {
        RequestId[] ids;
        mapping(RequestId requestId => uint256 index) at;
    }

    error ErrorRequestIdSetAlreadyAdded(RequestId requestId);
    error ErrorRequestIdSetNotInSet(RequestId requestId);


    function add(Set storage set, RequestId requestId) external {
        if (set.at[requestId] > 0) {
            revert ErrorRequestIdSetAlreadyAdded(requestId);
        }

        set.ids.push(requestId);
        set.at[requestId] = set.ids.length;
    }

    function remove(Set storage set, RequestId requestId) external {
        uint256 requestIdIndex = set.at[requestId];

        if (requestIdIndex == 0) {
            revert ErrorRequestIdSetNotInSet(requestId);
        }

        uint256 toDeleteIndex = requestIdIndex - 1;
        uint256 lastIndex = set.ids.length - 1;

        if (lastIndex != toDeleteIndex) {
            RequestId lastId = set.ids[lastIndex];
            set.ids[toDeleteIndex] = lastId;
            set.at[lastId] = requestIdIndex; // Replace lastValue's index to valueIndex
        }

        set.ids.pop();
        delete set.at[requestId];
    }

    function isEmpty(Set storage set) external view returns(bool empty) {
        return set.ids.length == 0;
    }

    function contains(Set storage set, RequestId requestId) external view returns(bool inSet) {
        return set.at[requestId] > 0;
    }

    function size(Set storage set) external view returns(uint256 length) {
        return set.ids.length;
    }

    function getElementAt(Set storage set, uint256 index) external view returns(RequestId requestId) {
        return set.ids[index];
    }
}
