// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

contract AccessManagedMock is
    AccessManaged
{
    uint256 private _counter1;
    uint256 private _counter2;

    constructor(address initialAuthority) AccessManaged(initialAuthority) {}

    function increaseCounter1() external restricted() { _counter1++; }
    function increaseCounter2() external restricted() { _counter2++; }

    function counter1() external view returns (uint256) { return _counter1; }
    function counter2() external view returns (uint256) { return _counter2; }
}