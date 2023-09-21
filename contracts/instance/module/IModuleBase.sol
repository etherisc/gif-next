// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";

interface IModuleBase {
    /// @dev repeat signatures to avoid linearization issues 
    // function getRegistry() external view returns (IRegistry registry);
    // function getOwner() external view returns (address owner);
    // function requireSenderIsOwner() external view returns (bool senderIsOwner);
}
