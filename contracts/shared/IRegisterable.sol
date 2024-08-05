// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {INftOwnable} from "./INftOwnable.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {VersionPart} from "../type/Version.sol";

/// @title IRegisterable
/// @dev Marks contracts that are intended to be registered in the registry.
/// 
interface IRegisterable is
    INftOwnable
{
    /// @dev retuns the GIF release version for this contract.
    /// This 
    function getRelease() external pure returns (VersionPart release);

    /// @dev retuns the object info relevant for registering for this contract 
    /// IMPORTANT information returned by this function may only be used
    /// before the contract is registered in the registry.
    /// Once registered this information MUST only be accessed via the registry.
    function getInitialInfo() 
        external 
        view
        returns (IRegistry.ObjectInfo memory);
}