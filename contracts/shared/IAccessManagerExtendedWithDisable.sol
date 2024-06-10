// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IAccessManagerExtended} from "./IAccessManagerExtended.sol";

import {Timestamp} from "../type/Timestamp.sol";
import {Seconds} from "../type/Seconds.sol";

interface IAccessManagerExtendedWithDisable is IAccessManagerExtended {

    error AccessManagerDisabled();
    error AccessManagerEnabled();

    function disable() external;
    function enable() external;
}