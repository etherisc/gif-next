// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

type Selector is bytes4;

// type bindings
using {
    eqSelector as ==, 
    neSelector as !=, 
    SelectorLib.toBytes4,
    SelectorLib.eqz
} for Selector global;

// pure free functions for operators
function eqSelector(Selector s1, Selector s2) pure returns (bool isSame) {
    return SelectorLib.eq(s1, s2);
}

function neSelector(Selector s1, Selector s2) pure returns (bool isDifferent) {
    return SelectorLib.ne(s1, s2);
}

// library functions that operate on user defined type
library SelectorLib {

    function zero() public pure returns (Selector) {
        return Selector.wrap("");
    }

    function eqz(Selector s) public pure returns (bool) {
        return Selector.unwrap(s) == "";
    }

    function eq(Selector s1, Selector s2) public pure returns (bool isSame) {
        return Selector.unwrap(s1) == Selector.unwrap(s2);
    }

    function ne(Selector s1, Selector s2) public pure returns (bool isDifferent) {
        return Selector.unwrap(s1) != Selector.unwrap(s2);
    }

    function toSelector(bytes4 selector) public pure returns (Selector) {
        return Selector.wrap(selector);
    }

    function toBytes4(Selector s) public pure returns (bytes4) {
        return Selector.unwrap(s);
    }
}

// selector specific set library
// based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableSet.sol
library SelectorSet {

    struct Set {
        Selector[] selectors;
        mapping(Selector selector => uint256 index) at;
    }

    function add(Set storage set, Selector selector) external {
        // selector already in set
        if (set.at[selector] > 0) { return; }

        set.selectors.push(selector);
        set.at[selector] = set.selectors.length;
    }

    function remove(Set storage set, Selector selector) external {
        uint256 selectorIndex = set.at[selector];

        // selector not in set
        if (selectorIndex == 0) {return; }

        uint256 toDeleteIndex = selectorIndex - 1;
        uint256 lastIndex = set.selectors.length - 1;

        if (lastIndex != toDeleteIndex) {
            Selector lastSelector = set.selectors[lastIndex];
            set.selectors[toDeleteIndex] = lastSelector;
            set.at[lastSelector] = selectorIndex; // Replace lastValue's index to valueIndex
        }

        set.selectors.pop();
        delete set.at[selector];
    }

    function isEmpty(Set storage set) external view returns(bool empty) {
        return set.selectors.length == 0;
    }

    function contains(Set storage set, Selector selector) external view returns(bool inSet) {
        return set.at[selector] > 0;
    }

    function size(Set storage set) external view returns(uint256 length) {
        return set.selectors.length;
    }

    function at(Set storage set, uint256 index) external view returns(Selector selector) {
        return set.selectors[index];
    }
}
