// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {VersionPart} from "../types/Version.sol";
import {ObjectType} from "../types/ObjectType.sol";

import {IRegisterable} from "./IRegisterable.sol";
import {IVersionable} from "./IVersionable.sol";

interface IService is 
    IRegisterable,
    IVersionable,
    IAccessManaged
{
    error ErrorIServiceCallerUnknown(address caller);
    
    function getDomain() external pure returns(ObjectType serviceDomain);
    function getMajorVersion() external view returns(VersionPart majorVersion);
}
