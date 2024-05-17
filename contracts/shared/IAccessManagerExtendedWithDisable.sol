// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IAccessManagerExtended} from "./IAccessManagerExtended.sol";

import {Timestamp} from "../type/Timestamp.sol";
import {VersionPart} from "../type/Version.sol";
import {Seconds} from "../type/Seconds.sol";

interface IAccessManagerExtendedWithDisable is IAccessManagerExtended {

    error AccessManagerDisabled();

    function disable(Seconds delay) external;
    function enable() external;
    function getVersion() external view returns (VersionPart version);
}