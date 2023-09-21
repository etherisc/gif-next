// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IOwnable {
    function getInitialOwner() external view returns (address initialOwner);
    function getOwner() external view returns (address owner);
    function requireSenderIsOwner() external view returns (bool senderIsOwner);
}
