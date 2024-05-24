// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract ArrayTest {

    uint[] public e1;

    constructor() {
        Adder adder = new Adder();
        e1 = [1,2,type(uint).max];
        uint s1 = adder.addCalldata(e1);

        e1 = [7,131313];
        uint s2 = adder.addCalldata(e1);
    }

    function addCalldata(uint[] memory elements) public view returns (uint256 sum) {
        for(uint i = 0; i < elements.length; i++) {
            sum += elements[i];
        }
    }
}

contract Adder {
    function addCalldata(uint[] calldata elements) public pure returns (uint256 sum) {
        for(uint i = 0; i < elements.length; i++) {
            sum += elements[i];
        }
    }
}