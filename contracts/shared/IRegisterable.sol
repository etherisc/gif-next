// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {INftOwnable} from "./INftOwnable.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IVersionable} from "./IVersionable.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {NftId} from "../type/NftId.sol";
import {VersionPart} from "../type/Version.sol";

/// @title IRegisterable
/// @dev Marks contracts that are intended to be registered in the registry.
/// 
interface IRegisterable is
    IAccessManaged,
    INftOwnable,
    IVersionable
{
    // __Registerable_init
    error ErrorAuthorityInvalid(address authority);

    // onlyActive()
    error ErrorRegisterableNotActive();

    //_checkNftType()
    error ErrorRegisterableInvalidType(NftId nftId, ObjectType expectedType, VersionPart expectedRelease);

    /// @dev Returns true iff this contract managed by its authority is active.
    /// Queries the IAccessManaged.authority().
    function isActive() external view returns (bool active);

    /// @dev retuns the object info relevant for registering for this contract 
    /// IMPORTANT information returned by this function may only be used
    /// before the contract is registered in the registry.
    /// Once registered this information MUST only be accessed via the registry.
    function getInitialInfo() 
        external 
        view
        returns (IRegistry.ObjectInfo memory info);

    function getInitialData() 
        external 
        view
        returns (bytes memory data);
}