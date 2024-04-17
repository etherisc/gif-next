// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {ObjectType} from "../type/ObjectType.sol";

interface IStaking is 
    IRegisterable,
    IVersionable,
    IAccessManaged
{
}
