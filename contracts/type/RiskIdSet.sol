// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {RiskId} from "../type/RiskId.sol";

// based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableSet.sol
library LibRiskIdSet {

    struct Set {
        RiskId[] ids;
        mapping(RiskId nftid => uint256 index) at;
    }

    error ErrorRiskIdSetAlreadyAdded(RiskId riskId);
    error ErrorRiskIdSetNotInSet(RiskId riskId);


    function add(Set storage set, RiskId riskId) external {
        if (set.at[riskId] > 0) {
            revert ErrorRiskIdSetAlreadyAdded(riskId);
        }

        set.ids.push(riskId);
        set.at[riskId] = set.ids.length;
    }

    function remove(Set storage set, RiskId riskId) external {
        uint256 nftIdIndex = set.at[riskId];

        if (nftIdIndex == 0) {
            revert ErrorRiskIdSetNotInSet(riskId);
        }

        uint256 toDeleteIndex = nftIdIndex - 1;
        uint256 lastIndex = set.ids.length - 1;

        if (lastIndex != toDeleteIndex) {
            RiskId lastId = set.ids[lastIndex];
            set.ids[toDeleteIndex] = lastId;
            set.at[lastId] = nftIdIndex; // Replace lastValue's index to valueIndex
        }

        set.ids.pop();
        delete set.at[riskId];
    }

    function isEmpty(Set storage set) external view returns(bool empty) {
        return set.ids.length == 0;
    }

    function contains(Set storage set, RiskId riskId) external view returns(bool inSet) {
        return set.at[riskId] > 0;
    }

    function size(Set storage set) external view returns(uint256 length) {
        return set.ids.length;
    }

    function getElementAt(Set storage set, uint256 index) external view returns(RiskId riskId) {
        return set.ids[index];
    }
}
