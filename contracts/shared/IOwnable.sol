// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IOwnable {
    function getOwner() external view returns (address owner);
}
