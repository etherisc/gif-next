// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IRegisterable} from "./IRegisterable.sol";
import {IVersionable} from "./IVersionable.sol";
import {ObjectType} from "../types/ObjectType.sol";

interface IService is 
    IRegisterable,
    IVersionable,
    IAccessManaged
{
    error ErrorServiceNotImplemented();

    function getDomain() external pure returns(ObjectType serviceDomain);
}
