// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";


contract Cloner {

    Mock1 public mock1;
    Mock2 public mock2;

    constructor() {
        mock1 = new Mock1();
        mock2 = new Mock2();
    }

    function createClone(address master)
        external 
        returns (address cloned)
    {
        cloned = Clones.clone(master);
    }
}


contract Mock1 {
    function getValue() external virtual view returns (uint256) {
        return 42;
    }
}

contract Mock2 is Mock1 {
    uint256 internal _value;

    constructor() {
        _value = 42;
    }

    function setValue(uint256 value) external virtual {
        _value = value;
    }

    function getValue() external virtual override view returns (uint256) {
        return _value;
    }
}

