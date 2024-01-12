// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {VersionPart} from "../types/Version.sol";

import {IRegisterable} from "./IRegisterable.sol";
import {IVersionable} from "./IVersionable.sol";

interface IService is 
    IRegisterable,
    IVersionable
{
    function getName() external pure returns(string memory name);
    function getMajorVersion() external view returns(VersionPart majorVersion);
}
