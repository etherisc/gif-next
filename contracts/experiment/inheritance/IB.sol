// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IB {
    function getAfromB() external view returns (uint256);

    function getB() external view returns (uint256);

    function setB(uint256 newA) external;
}
