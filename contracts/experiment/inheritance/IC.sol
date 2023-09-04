// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IC {
    function getAfromC() external view returns (uint256);

    function getBfromC() external view returns (uint256);

    function getC() external view returns (uint256);

    function setC(uint256 newA) external;
}
