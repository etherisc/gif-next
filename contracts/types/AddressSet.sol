// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableSet.sol
library LibAddressSet {

    struct Set {
        address[] elements;
        mapping(address element => uint256 index) at;
    }

    function add(Set storage set, address element) external returns(bool added) {
        if (set.at[element] == 0) {
            set.elements.push(element);
            set.at[element] = set.elements.length;
            return true;
        } else {
            return false;
        }
    }

    function remove(Set storage set, address element) external returns(bool removed) {
        uint256 elementIndex = set.at[element];

        if (elementIndex > 0) {
            uint256 toDeleteIndex = elementIndex - 1;
            uint256 lastIndex = set.elements.length - 1;

            if (lastIndex != toDeleteIndex) {
                address lastElement = set.elements[lastIndex];
                set.elements[toDeleteIndex] = lastElement;
                set.at[lastElement] = elementIndex; // Replace lastValue's index to valueIndex
            }

            set.elements.pop();
            delete set.at[element];
            return true;
        }
        
        return false;
    }

    function isEmpty(Set storage set) external view returns(bool empty) {
        return set.elements.length == 0;
    }

    function contains(Set storage set, address element) external view returns(bool inSet) {
        return set.at[element] > 0;
    }

    function getLength(Set storage set) external view returns(uint256 length) {
        return set.elements.length;
    }

    function getElementAt(Set storage set, uint256 index) external view returns(address element) {
        return set.elements[index];
    }
}
