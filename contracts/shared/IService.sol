// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IRegisterable} from "./IRegisterable.sol";
import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";

interface IService is 
    IAccessManaged,
    IRegisterable,
    IVersionable
{
    /// @dev returns the domain for this service.
    /// In any GIF release only one service for any given domain may be deployed.
    function getDomain() external pure returns(ObjectType serviceDomain);

    /// @dev returns the GIF release specific role id.
    /// These role ids are used to authorize service to service communication.
    function getRoleId() external view returns(RoleId serviceRoleId);
}
