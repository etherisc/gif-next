// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Component} from "../../contracts/shared/Component.sol";
import {KeyValueStore} from "../../contracts/shared/KeyValueStore.sol";
import {Version, VersionLib} from "../../contracts/type/Version.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";

contract MockSizeUpgradeableKeyValueStore is 
    KeyValueStore,
    Component,
    Versionable
{


    // from Versionable
    function getVersion()
        public 
        pure 
        virtual override
        returns(Version)
    {
        return VersionLib.toVersion(3,0,0);
    }

    function _setupLifecycle() internal override {}

}
