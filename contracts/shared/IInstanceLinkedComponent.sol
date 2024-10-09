// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {IAuthorizedComponent} from "../shared/IAuthorizedComponent.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IInstance} from "../instance/IInstance.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {VersionPart} from "../type/Version.sol";

/// @dev component base class
/// component examples are product, distribution, pool and oracle
interface IInstanceLinkedComponent is 
    IAuthorizedComponent
{
    error ErrorInstanceLinkedComponentInstanceInvalid();
    error ErrorInstanceLinkedComponentInstanceMismatch(VersionPart instanceRelease, VersionPart componentRelease);

    /// @dev defines the instance to which this component is linked to
    function getInstance() external view returns (IInstance instance);

}